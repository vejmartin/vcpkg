#!/usr/bin/python
# Copyright 2016 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# file should be in src/ios/build/tools/ios-bootstrap.py

import argparse
import errno
import os
import re
import shutil
import subprocess
import sys
import tempfile
import ConfigParser

try:
  import cStringIO as StringIO
except ImportError:
  import StringIO


SUPPORTED_TARGETS = ('arm', 'arm64', 'x86', 'x64')
# SUPPORTED_CONFIGS = ('Debug', 'Release', 'Profile', 'Official', 'Coverage')
SUPPORTED_CONFIGS = ('Debug', 'Release')
BASE_LIBNAME = 'libbase.a'


class ConfigParserWithStringInterpolation(ConfigParser.SafeConfigParser):

  '''A .ini file parser that supports strings and environment variables.'''

  ENV_VAR_PATTERN = re.compile('\$([A-Za-z0-9_]+)')

  def values(self, section):
    return map(
        lambda (k, v): self._UnquoteString(self._ExpandEnvVar(v)),
        ConfigParser.SafeConfigParser.items(self, section))

  def getstring(self, section, option):
    return self._UnquoteString(self._ExpandEnvVar(self.get(section, option)))

  def _UnquoteString(self, string):
    if not string or string[0] != '"' or string[-1] != '"':
      return string
    return string[1:-1]

  def _ExpandEnvVar(self, value):
    match = self.ENV_VAR_PATTERN.search(value)
    if not match:
      return value
    name, (begin, end) = match.group(1), match.span(0)
    prefix, suffix = value[:begin], self._ExpandEnvVar(value[end:])
    return prefix + os.environ.get(name, '') + suffix

class GnGenerator(object):

  '''Holds configuration for a build and method to generate gn default files.'''

  def __init__(self, settings, config, target):
    assert target in SUPPORTED_TARGETS
    assert config in SUPPORTED_CONFIGS
    self._settings = settings
    self._config = config
    self._target = target

  def _GetGnArgs(self):
    """Build the list of arguments to pass to gn.

    Returns:
      A list of tuple containing gn variable names and variable values (it
      is not a dictionary as the order needs to be preserved).
    """
    args = []

    args.append(('is_debug', self._config in ('Debug', 'Coverage')))
    args.append(('enable_dsyms', self._config in ('Profile', 'Official')))
    args.append(('enable_stripping', 'enable_dsyms'))
    args.append(('is_official_build', self._config == 'Official'))
    args.append(('is_chrome_branded', 'is_official_build'))
    args.append(('use_xcode_clang', 'true'))
    args.append(('use_clang_coverage', self._config == 'Coverage'))
    args.append(('is_component_build', False))
    args.append(('symbol_level', 0))

    if os.environ.get('FORCE_MAC_TOOLCHAIN', '0') == '1':
      args.append(('use_system_xcode', False))

    args.append(('target_cpu', '"' + self._target + '"'))
    args.append(('target_os', '"ios"'))
    return args


  def Generate(self, gn_path, root_path, out_path):
    buf = StringIO.StringIO()
    self.WriteArgsGn(buf)
    WriteToFileIfChanged(
        os.path.join(out_path, 'args.gn'),
        buf.getvalue(),
        overwrite=True)

    subprocess.check_call(
        self.GetGnCommand(gn_path, root_path, out_path, True))

  def CreateGnRules(self, gn_path, root_path, out_path):
    buf = StringIO.StringIO()
    self.WriteArgsGn(buf)
    WriteToFileIfChanged(
        os.path.join(out_path, 'args.gn'),
        buf.getvalue(),
        overwrite=True)

    buf = StringIO.StringIO()
    gn_command = self.GetGnCommand(gn_path, root_path, out_path, False)
    self.WriteBuildNinja(buf, gn_command)
    WriteToFileIfChanged(
        os.path.join(out_path, 'build.ninja'),
        buf.getvalue(),
        overwrite=False)

    buf = StringIO.StringIO()
    self.WriteBuildNinjaDeps(buf)
    WriteToFileIfChanged(
        os.path.join(out_path, 'build.ninja.d'),
        buf.getvalue(),
        overwrite=False)

  def WriteArgsGn(self, stream):
    stream.write('# This file was generated by setup-gn.py. Do not edit\n')
    stream.write('# but instead use ~/.setup-gn or $repo/.setup-gn files\n')
    stream.write('# to configure settings.\n')
    stream.write('\n')

    if self._settings.has_section('$imports$'):
      for import_rule in self._settings.values('$imports$'):
        stream.write('import("%s")\n' % import_rule)
      stream.write('\n')

    gn_args = self._GetGnArgs()
    for name, value in gn_args:
      if isinstance(value, bool):
        stream.write('%s = %s\n' % (name, str(value).lower()))
      elif isinstance(value, list):
        stream.write('%s = [%s' % (name, '\n' if len(value) > 1 else ''))
        if len(value) == 1:
          prefix = ' '
          suffix = ' '
        else:
          prefix = '  '
          suffix = ',\n'
        for item in value:
          if isinstance(item, bool):
            stream.write('%s%s%s' % (prefix, str(item).lower(), suffix))
          else:
            stream.write('%s%s%s' % (prefix, item, suffix))
        stream.write(']\n')
      else:
        stream.write('%s = %s\n' % (name, value))

  def WriteBuildNinja(self, stream, gn_command):
    stream.write('rule gn\n')
    stream.write('  command = %s\n' % NinjaEscapeCommand(gn_command))
    stream.write('  description = Regenerating ninja files\n')
    stream.write('\n')
    stream.write('build build.ninja: gn\n')
    stream.write('  generator = 1\n')
    stream.write('  depfile = build.ninja.d\n')

  def WriteBuildNinjaDeps(self, stream):
    stream.write('build.ninja: nonexistant_file.gn\n')

  def GetGnCommand(self, gn_path, src_path, out_path, generate_xcode_project):
    gn_command = [ gn_path, '--root=%s' % os.path.realpath(src_path), '-q' ]
    if generate_xcode_project:
      gn_command.append('--ide=xcode')
      gn_command.append('--root-target=gn_all')
      if self._settings.getboolean('goma', 'enabled'):
        ninja_jobs = self._settings.getint('xcode', 'jobs') or 200
        gn_command.append('--ninja-extra-args=-j%s' % ninja_jobs)
      if self._settings.has_section('filters'):
        target_filters = self._settings.values('filters')
        if target_filters:
          gn_command.append('--filters=%s' % ';'.join(target_filters))
    else:
      gn_command.append('--check')
    gn_command.append('gen')
    gn_command.append('//%s' %
        os.path.relpath(os.path.abspath(out_path), os.path.abspath(src_path)))
    return gn_command

  def BuildGnRules(self, root_path, out_path):
    BASE_SUBLIBS = [
      'obj/base/libbase.a',
      'obj/base/libbase_static.a',
      'obj/base/third_party/dynamic_annotations/libdynamic_annotations.a',
      'obj/base/third_party/double_conversion/libdouble_conversion.a',
      'obj/base/third_party/libevent/libevent.a',
      'obj/third_party/modp_b64/libmodp_b64.a',
    ]

    ninja_path = FindCommand('ninja')
    libtool_path = FindCommand('libtool')

    assert ninja_path != None and libtool_path != None
    command = [ ninja_path ]
    command.append('-C')
    command.append('%s' % os.path.relpath(os.path.abspath(out_path), os.path.abspath(root_path)))
    command.append('base')
    proc = subprocess.Popen(command, cwd=root_path)
    proc.wait()

    command = [ libtool_path ]
    command.append('-no_warning_for_no_symbols')
    command.append('-static')
    command.append('-o')
    command.append(BASE_LIBNAME)
    command.extend(BASE_SUBLIBS)
    proc = subprocess.Popen(command, cwd=out_path)
    proc.wait()

    return proc


def WriteToFileIfChanged(filename, content, overwrite):
  '''Write |content| to |filename| if different. If |overwrite| is False
  and the file already exists it is left untouched.'''
  if os.path.exists(filename):
    if not overwrite:
      return
    with open(filename) as file:
      if file.read() == content:
        return
  if not os.path.isdir(os.path.dirname(filename)):
    os.makedirs(os.path.dirname(filename))
  with open(filename, 'w') as file:
    file.write(content)


def NinjaNeedEscape(arg):
  '''Returns True if |arg| needs to be escaped when written to .ninja file.'''
  return ':' in arg or '*' in arg or ';' in arg


def NinjaEscapeCommand(command):
  '''Escapes |command| in order to write it to .ninja file.'''
  result = []
  for arg in command:
    if NinjaNeedEscape(arg):
      arg = arg.replace(':', '$:')
      arg = arg.replace(';', '\\;')
      arg = arg.replace('*', '\\*')
    else:
      result.append(arg)
  return ' '.join(result)


def FindGn():
  '''Returns absolute path to gn binary looking at the PATH env variable.'''
  for path in os.environ['PATH'].split(os.path.pathsep):
    gn_path = os.path.join(path, 'gn')
    if os.path.isfile(gn_path) and os.access(gn_path, os.X_OK):
      return gn_path
  return None

def FindCommand(cmd):
  '''Returns absolute path to gn binary looking at the PATH env variable.'''
  for path in os.environ['PATH'].split(os.path.pathsep):
    cmd_path = os.path.join(path, cmd)
    if os.path.isfile(cmd_path) and os.access(cmd_path, os.X_OK):
      return cmd_path
  return None

def CopyFiles(srcdir, dstdir,
              filter=['.h', '.a', '.so', '.dylib', '.TOC', '.dll', '.lib'],
              exclude=['obj']):
    paths = os.listdir(srcdir)
    for path in paths:
        if exclude and path in exclude:
            continue
        if os.path.isdir(os.path.join(srcdir, path)):
            CopyFiles(os.path.join(srcdir, path),
                      os.path.join(dstdir, path),
                      filter,
                      exclude)
        elif os.path.isfile(os.path.join(srcdir, path)):
            ext = os.path.splitext(os.path.join(srcdir, path))[1]
            if (filter != None) and (ext not in filter):
                continue
            if not os.path.exists(dstdir):
                os.makedirs(dstdir)
            shutil.copy(os.path.join(srcdir, path), dstdir)


def LipoMultiArch(out_dir, lipo_paths, config):
  lipo_config_dir = os.path.join(out_dir, 'iOS-%s' % (config))
  if not os.path.isdir(lipo_config_dir):
      os.makedirs(lipo_config_dir)
  lipo_path = FindCommand('lipo')
  command = [ lipo_path ]
  command.append('-create')
  command.append('-output')
  command.append(os.path.join(lipo_config_dir, BASE_LIBNAME))
  command.extend(os.path.join(x, BASE_LIBNAME) for x in lipo_paths)
  proc = subprocess.Popen(command, cwd=out_dir)
  proc.wait()

  CopyFiles(os.path.join(lipo_paths[0], 'gen'),
    os.path.join(lipo_config_dir, 'gen'),
    filter=['.h'],
    exclude=['android'])

def GenerateGnBuildRules(gn_path, root_dir, out_dir, settings):
  '''Generates all template configurations for gn.'''
  for config in SUPPORTED_CONFIGS:
    lipo_paths = []
    for target in SUPPORTED_TARGETS:
      build_dir = os.path.join(out_dir, 'iOS-%s-%s' % (target, config))
      lipo_paths.append(os.path.abspath(build_dir))
      generator = GnGenerator(settings, config, target)
      generator.CreateGnRules(gn_path, root_dir, build_dir)
      generator.BuildGnRules(root_dir, build_dir)
    LipoMultiArch(os.path.abspath(out_dir), lipo_paths, config)


def Main(args):
  default_root = os.path.normpath(os.path.join(
      os.path.dirname(__file__), os.pardir, os.pardir, os.pardir))

  parser = argparse.ArgumentParser(
      description='Generate build directories for use with gn.')
  parser.add_argument(
      'root', default=default_root, nargs='?',
      help='root directory where to generate multiple out configurations')
  parser.add_argument(
      '--import', action='append', dest='import_rules', default=[],
      help='path to file defining default gn variables')
  args = parser.parse_args(args)

  # Load configuration (first global and then any user overrides).
  settings = ConfigParserWithStringInterpolation()

  # Add private sections corresponding to --import argument.
  if args.import_rules:
    settings.add_section('$imports$')
    for i, import_rule in enumerate(args.import_rules):
      if not import_rule.startswith('//'):
        import_rule = '//%s' % os.path.relpath(
            os.path.abspath(import_rule), os.path.abspath(args.root))
      settings.set('$imports$', '$rule%d$' % i, import_rule)

  # Find gn binary in PATH.
  gn_path = FindGn()
  if gn_path is None:
    sys.stderr.write('ERROR: cannot find gn in PATH\n')
    sys.exit(1)

  out_dir = os.path.join(args.root, 'out')
  if not os.path.isdir(out_dir):
    os.makedirs(out_dir)

  GenerateGnBuildRules(gn_path, args.root, out_dir, settings)


if __name__ == '__main__':
  sys.exit(Main(sys.argv[1:]))

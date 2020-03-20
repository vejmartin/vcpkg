## # vcpkg_acquire_depot_tools
##
## Download or find depot_tools
##
## ## Usage
## ```cmake
## vcpkg_acquire_depot_tools(
##   OUT_ROOT_PATH <ROOT_PATH>
##   [TOOLS <tool>...]
##   [ADD_TO_PATH]
## )
## ```
##
## ## Parameters
## ### OUT_ROOT_PATH
## An out-variable that will be set to the path to depot_tools.
##
## ### TOOLS
## A list of tools to acquire in depot_tools.
## Available tools: GCLIENT, GN
##
## ### ADD_TO_PATH
## Add the depot_tools root to the PATH environment variable.
##
## ## Notes:
## `OUT_ROOT_PATH` must be specified.

function(vcpkg_acquire_depot_tools)
  cmake_parse_arguments(_adt "ADD_TO_PATH" "OUT_ROOT_PATH" "TOOLS" ${ARGN})

  set(REF "464e9ff4f3682426b0cb3b68ee38e7be6fa4a2be")
  set(URL "https://chromium.googlesource.com/chromium/tools/depot_tools.git")

  vcpkg_from_git(
    OUT_SOURCE_PATH DEPOT_TOOLS_ROOT
    URL ${URL}
    REF ${REF}
    NAME "depot_tools"
    TARGET_DIRECTORY "${DOWNLOADS}/tools/depot_tools"
  )

  vcpkg_find_acquire_program(PYTHON2)

  foreach(TOOL ${_adt_TOOLS})
    if(TOOL STREQUAL "GCLIENT")
      set(TOOL_OUT "${PYTHON2}" "${DEPOT_TOOLS_ROOT}/gclient.py")
    elseif(TOOL STREQUAL "GN")
      set(TOOL_OUT "${PYTHON2}" "${DEPOT_TOOLS_ROOT}/gn.py")
    else()
      message(FATAL_ERROR "Could not find tool '${TOOL}'.")
    endif()

    set(${TOOL} "${TOOL_OUT}" PARENT_SCOPE)
  endforeach()
  
  # Disable depot_tools' auto update
  set($ENV{DEPOT_TOOLS_UPDATE} 0)

  if(CMAKE_HOST_WIN32)
    # Workaround for skipping depot_tools' bootstrap on Windows
    if(NOT EXISTS "${DEPOT_TOOLS_ROOT}/python.bat")
      file(WRITE "${DEPOT_TOOLS_ROOT}/python.bat" "@echo off\npython %*")
    endif()
    if(NOT EXISTS "${DEPOT_TOOLS_ROOT}/git.bat")
      file(WRITE "${DEPOT_TOOLS_ROOT}/git.bat" "@echo off\ngit %*")
    endif()
  endif()

  if(DEFINED _adt_ADD_TO_PATH)
    vcpkg_add_to_path(PREPEND "${DEPOT_TOOLS_ROOT}")

    # Python and git are required by depot_tools
    get_filename_component(PYTHON2_DIR "${PYTHON2}" DIRECTORY)
    vcpkg_add_to_path(PREPEND "${PYTHON2_DIR}")

    vcpkg_find_acquire_program(GIT)
    get_filename_component(GIT_DIR "${GIT}" DIRECTORY)
    vcpkg_add_to_path(PREPEND "${GIT_DIR}")

    if(CMAKE_HOST_WIN32)
      # Workaround for long paths on Windows
      # https://github.com/msysgit/msysgit/wiki/Git-cannot-create-a-file-or-directory-with-a-long-path
      _execute_process(COMMAND "${GIT}" config --system core.longpaths true)
    endif()
  endif()

  set(${_adt_OUT_ROOT_PATH} "${DEPOT_TOOLS_ROOT}" PARENT_SCOPE)

endfunction()

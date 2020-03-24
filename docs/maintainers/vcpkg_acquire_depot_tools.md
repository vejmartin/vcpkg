# vcpkg_acquire_depot_tools

Download or find `depot_tools`

## Usage
```cmake
vcpkg_acquire_depot_tools(
  [OUT_ROOT_PATH <ROOT_PATH>]
  [TOOLS <tool>...]
  [ADD_TO_PATH]
)
```

## Parameters
### OUT_ROOT_PATH
An out-variable that will be set to the path to `depot_tools`.

### TOOLS
A list of tools to acquire in `depot_tools`.
Available tools: `GCLIENT`, `GN`

## Notes:
The path to `depot_tools` will be prepended to the PATH environment variable.
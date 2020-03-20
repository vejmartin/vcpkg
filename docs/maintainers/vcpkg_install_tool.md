# vcpkg_install_tool

Install a tool from the build to the packages directory

## Usage:
```cmake
vcpkg_install_tool(
    NAMES <NAMES>...
    [RELATIVE_PATHS <RELATIVE_PATHS>...]
)
```

## Parameters:
### NAMES (required)
A list of possible names for the tool.

### RELATIVE_PATHS
A list of paths relative to the build directory where the tool may be found.

## Source
[scripts/cmake/vcpkg_install_tool.cmake](https://github.com/Microsoft/vcpkg/blob/master/scripts/cmake/vcpkg_install_tool.cmake)

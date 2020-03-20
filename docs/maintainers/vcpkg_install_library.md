# vcpkg_install_library

Install a library from the build to the packages directory

## Usage:
```cmake
vcpkg_install_library(
    NAMES <NAMES>...
    [RELATIVE_PATHS <RELATIVE_PATHS>...]
)
```

## Parameters:
### NAMES (required)
A list of possible names for the library.

### RELATIVE_PATHS
A list of paths relative to the build directory where the library may be found.

## Source
[scripts/cmake/vcpkg_install_library.cmake](https://github.com/Microsoft/vcpkg/blob/master/scripts/cmake/vcpkg_install_library.cmake)

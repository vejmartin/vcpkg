# vcpkg_from_gclient

Download and extract a project with gclient

## Usage:
```cmake
vcpkg_from_gclient(
    OUT_SOURCE_PATH <SOURCE_PATH>
    URL <https://android.googlesource.com/platform/external/fdlibm>
    REF <59f7335e4d...>
    NAME <name>
)
```

## Parameters:
### OUT_SOURCE_PATH (required)
Specifies the out-variable that will contain the gclient root location.

### URL (required)
The url of the git repository.

### REF (required)
The git sha of the commit to download.

### NAME (required)
The name of the project

## Source
[scripts/cmake/vcpkg_from_gclient.cmake](https://github.com/Microsoft/vcpkg/blob/master/scripts/cmake/vcpkg_from_gclient.cmake)

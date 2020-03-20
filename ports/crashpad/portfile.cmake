vcpkg_fail_port_install(
    ON_ARCH "x86" "arm" "arm64"
    ON_TARGET "UWP" "LINUX")

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_gclient(
    OUT_SOURCE_PATH SOURCE_PATH
    URL "https://chromium.googlesource.com/crashpad/crashpad"
    REF "9a31d3f8e9815774026a753a1ff6155347cd549f"
    NAME "crashpad"
)

set(SOURCE_PATH "${SOURCE_PATH}/crashpad")

set(OPTIONS_DBG "is_debug=true")
set(OPTIONS_REL "")

if(CMAKE_HOST_WIN32)
    # Load toolchains
    if(NOT VCPKG_CHAINLOAD_TOOLCHAIN_FILE)
        set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${SCRIPTS}/toolchains/windows.cmake")
    endif()
    include("${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}")

    foreach(_VAR CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS
        CMAKE_C_FLAGS_RELEASE CMAKE_CXX_FLAGS_RELEASE)
        string(STRIP "${${_VAR}}" ${_VAR})
    endforeach()

    set(OPTIONS_DBG "${OPTIONS_DBG} \
        extra_cflags_c=\"${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_DEBUG}\" \
        extra_cflags_cc=\"${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_DEBUG}\"")

    set(OPTIONS_REL "${OPTIONS_REL} \
        extra_cflags_c=\"${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_RELEASE}\" \
        extra_cflags_cc=\"${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_RELEASE}\"")

    set(DISABLE_WHOLE_PROGRAM_OPTIMIZATION "\
        extra_cflags=\"/GL-\" \
        extra_ldflags=\"/LTCG:OFF\" \
        extra_arflags=\"/LTCG:OFF\"")

    set(OPTIONS_DBG "${OPTIONS_DBG} ${DISABLE_WHOLE_PROGRAM_OPTIMIZATION}")
    set(OPTIONS_REL "${OPTIONS_REL} ${DISABLE_WHOLE_PROGRAM_OPTIMIZATION}")
endif()

vcpkg_configure_gn(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS_DEBUG "${OPTIONS_DBG}"
    OPTIONS_RELEASE "${OPTIONS_REL}"
)
vcpkg_build_ninja(client crashpad_handler)
vcpkg_install_library(NAMES client RELATIVE_PATHS obj/client)
vcpkg_install_library(NAMES util RELATIVE_PATHS obj/util)
vcpkg_install_library(NAMES base RELATIVE_PATHS obj/third_party/mini_chromium/mini_chromium/base)

# Prefer .exe instead of .com on Windows
vcpkg_install_tool(NAMES crashpad_handler.exe crashpad_handler)

message(STATUS "Installing headers...")
set(PACKAGES_INCLUDE_DIR "${CURRENT_PACKAGES_DIR}/include/${PORT}")
function(install_headers DIR)
    file(COPY "${DIR}" DESTINATION "${PACKAGES_INCLUDE_DIR}" FILES_MATCHING PATTERN "*.h")
endfunction()
install_headers("${SOURCE_PATH}/client")
install_headers("${SOURCE_PATH}/util")
install_headers("${SOURCE_PATH}/third_party/mini_chromium/mini_chromium/base")
install_headers("${SOURCE_PATH}/third_party/mini_chromium/mini_chromium/build")

# remove empty directories
file(REMOVE_RECURSE 
    "${PACKAGES_INCLUDE_DIR}/util/net/testdata" 
    "${PACKAGES_INCLUDE_DIR}/build/ios")

configure_file("${CMAKE_CURRENT_LIST_DIR}/crashpadConfig.cmake.in"
        "${CURRENT_PACKAGES_DIR}/share/${PORT}/crashpadConfig.cmake" @ONLY)

vcpkg_copy_pdbs()
file(INSTALL "${SOURCE_PATH}/LICENSE"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
    RENAME copyright)

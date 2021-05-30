vcpkg_fail_port_install(
    ON_ARCH "x86" "arm" "arm64"
    ON_TARGET "UWP")

# Patches may be provided at the end
function(checkout_in_path PATH URL REF)
    if(EXISTS "${PATH}")
        file(GLOB FILES "${PATH}")
        list(LENGTH FILES COUNT)
        if(COUNT GREATER 0)
            return()
        endif()
        file(REMOVE_RECURSE "${PATH}")
    endif()
    
    vcpkg_from_git(
        OUT_SOURCE_PATH DEP_SOURCE_PATH
        URL "${URL}"
        REF "${REF}"
        PATCHES "${ARGN}"
    )
    file(RENAME "${DEP_SOURCE_PATH}" "${PATH}")
    file(REMOVE_RECURSE "${DEP_SOURCE_PATH}")
endfunction()

# Commits are based on https://chromium.googlesource.com/chromium/src/+/refs/tags/93.0.4527.1
set(SOURCE_PATH "${CURRENT_BUILDTREES_DIR}/src/65424b3")
file(MAKE_DIRECTORY "${SOURCE_PATH}/third_party")

set(CHROMIUM_GIT "https://chromium.googlesource.com/chromium/src")
checkout_in_path(
    "${SOURCE_PATH}/base" 
    "${CHROMIUM_GIT}/base" 
    "65424b398e1cedb38cc61af7c958c4e314d47333"
    res/0001-base.patch)
checkout_in_path(
    "${SOURCE_PATH}/build" 
    "${CHROMIUM_GIT}/build" 
    "3fc38c3bd66b81e05536f2f89879db8bbedd9cb4"
    res/0002-build.patch)
checkout_in_path(
    "${SOURCE_PATH}/third_party/apple_apsl" 
    "${CHROMIUM_GIT}/third_party/apple_apsl" 
    "6c392aa25ba660e9f66b66f75bc678d8b15cbbf7")
checkout_in_path(
    "${SOURCE_PATH}/third_party/ced" 
    "${CHROMIUM_GIT}/third_party/ced" 
    "e8cd19c43f9d52c4065f0b258d607acfe892281f")
checkout_in_path(
    "${SOURCE_PATH}/third_party/modp_b64" 
    "${CHROMIUM_GIT}/third_party/modp_b64" 
    "7b38a1f56b3bf3d06b337af75a2251f0489cd004")
checkout_in_path(
    "${SOURCE_PATH}/third_party/abseil-cpp" 
    "${CHROMIUM_GIT}/third_party/abseil-cpp" 
    "7949d870935409c5c195447bc23ad1bf3ff80c91")

set(RES "${CMAKE_CURRENT_LIST_DIR}/res")
file(COPY "${RES}/.gn" DESTINATION "${SOURCE_PATH}")
file(COPY "${RES}/BUILD.gn" DESTINATION "${SOURCE_PATH}")
file(COPY "${RES}/build_overrides" DESTINATION "${SOURCE_PATH}")
file(COPY "${RES}/testing" DESTINATION "${SOURCE_PATH}")
file(COPY "${RES}/tools" DESTINATION "${SOURCE_PATH}")
file(COPY "${RES}/gclient_args.gni" DESTINATION "${SOURCE_PATH}/build/config")
file(COPY "${RES}/LASTCHANGE.committime" DESTINATION "${SOURCE_PATH}/build/util")
file(COPY "${RES}/icu" DESTINATION "${SOURCE_PATH}/third_party")
file(COPY "${RES}/libxml" DESTINATION "${SOURCE_PATH}/third_party")
file(COPY "${RES}/protobuf" DESTINATION "${SOURCE_PATH}/third_party")
file(COPY "${RES}/fontconfig" DESTINATION "${SOURCE_PATH}/third_party")
file(COPY "${RES}/test_fonts" DESTINATION "${SOURCE_PATH}/third_party")
file(COPY "${RES}/googletest" DESTINATION "${SOURCE_PATH}/third_party")

set(OPTIONS "\
    use_custom_libcxx=false \
    clang_use_chrome_plugins=false \
    forbid_non_component_debug_builds=false \
    treat_warnings_as_errors=false")
set(DEFINITIONS "")

if(WIN32)
    # Windows 10 SDK >= (10.0.19041.0) is required
    # https://developer.microsoft.com/en-us/windows/downloads/windows-10-sdk
    SET(VCPKG_POLICY_SKIP_ARCHITECTURE_CHECK enabled)
    set(ENV{DEPOT_TOOLS_WIN_TOOLCHAIN} 0)
    set(OPTIONS "${OPTIONS} use_lld=false")
endif()

if(VCPKG_CMAKE_SYSTEM_NAME STREQUAL Linux)
    set(OPTIONS "${OPTIONS} use_allocator=\"none\" use_sysroot=false use_glib=false")
endif()

# Find the directory that contains "bin/clang"
# Note: Only clang-cl is supported on Windows, see https://crbug.com/988071
vcpkg_find_acquire_program(CLANG)
if(CLANG MATCHES "-NOTFOUND")
    message(FATAL_ERROR "Clang is required.")
endif()
get_filename_component(CLANG "${CLANG}" DIRECTORY)
get_filename_component(CLANG "${CLANG}" DIRECTORY)
if((WIN32 AND NOT EXISTS "${CLANG}/bin/clang-cl.exe") OR 
   (APPLE AND NOT EXISTS "${CLANG}/bin/clang"))
    message(FATAL_ERROR "Clang needs to be inside a bin directory.")
endif()
set(OPTIONS "${OPTIONS} clang_base_path=\"${CLANG}\"")

if(VCPKG_LIBRARY_LINKAGE STREQUAL dynamic)
    set(OPTIONS "${OPTIONS} is_component_build=true")
    list(APPEND DEFINITIONS COMPONENT_BUILD)
else()
    set(OPTIONS "${OPTIONS} is_component_build=false")
endif()

if(APPLE)
    set(OPTIONS "${OPTIONS} enable_dsyms=true")
endif()

set(OPTIONS_DBG "${OPTIONS} is_debug=true symbol_level=2")
set(OPTIONS_REL "${OPTIONS} is_debug=false symbol_level=0")
set(DEFINITIONS_DBG ${DEFINITIONS})
set(DEFINITIONS_REL ${DEFINITIONS})

vcpkg_configure_gn(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS_DEBUG "${OPTIONS_DBG}"
    OPTIONS_RELEASE "${OPTIONS_REL}"
)

# Prevent a ninja re-config loop
set(NINJA_REBUILD "build build.ninja: gn\n  generator = 1\n  depfile = build.ninja.d")
vcpkg_replace_string("${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/build.ninja" "${NINJA_REBUILD}" "")
vcpkg_replace_string("${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/build.ninja" "${NINJA_REBUILD}" "")

set(TARGETS 
    base base:base_static
    base/third_party/dynamic_annotations 
    base/third_party/double_conversion)

if(WIN32)
    list(APPEND TARGETS base/win:pe_image)
endif()

vcpkg_install_gn(
    SOURCE_PATH "${SOURCE_PATH}"
    TARGETS ${TARGETS}
)

# Install includes
set(PACKAGES_INCLUDE_DIR "${CURRENT_PACKAGES_DIR}/include/${PORT}")
file(GLOB_RECURSE INCLUDE_FILES LIST_DIRECTORIES false RELATIVE "${SOURCE_PATH}" "${SOURCE_PATH}/*.h")
foreach(file_ ${INCLUDE_FILES})
    configure_file("${SOURCE_PATH}/${file_}" "${PACKAGES_INCLUDE_DIR}/${file_}" COPYONLY)
endforeach()

configure_file("${CMAKE_CURRENT_LIST_DIR}/chromium-baseConfig.cmake.in"
        "${CURRENT_PACKAGES_DIR}/share/${PORT}/chromium-baseConfig.cmake" @ONLY)

vcpkg_copy_pdbs()

file(INSTALL "${SOURCE_PATH}/third_party/ced/LICENSE"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
    RENAME copyright)

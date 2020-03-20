vcpkg_fail_port_install(
    ON_ARCH "x86" "arm" "arm64"
    ON_TARGET "UWP" "LINUX" "ANDROID" "FREEBSD")

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

set(URL "https://chromium.googlesource.com/crashpad/crashpad")
set(REF "9a31d3f8e9815774026a753a1ff6155347cd549f")
set(GCLIENT_ROOT "${CURRENT_BUILDTREES_DIR}/src/${REF}")
set(SOURCE_PATH "${GCLIENT_ROOT}/crashpad")

file(MAKE_DIRECTORY "${GCLIENT_ROOT}")

set(GCLIENT_CONFIG [==[
solutions = [
  {
    "url": "@URL@@@REF@",
    "managed": False,
    "name": "crashpad",
    "deps_file": "DEPS"
  },
]
]==])
string(CONFIGURE "${GCLIENT_CONFIG}" GCLIENT_CONFIG @ONLY)
file(WRITE "${GCLIENT_ROOT}/.gclient" "${GCLIENT_CONFIG}")

vcpkg_acquire_depot_tools(
    OUT_ROOT_PATH DEPOT_TOOLS
    TOOLS GCLIENT GN
    ADD_TO_PATH)

message(STATUS "Syncing sources and dependencies...")
vcpkg_execute_required_process(
    COMMAND "${GCLIENT}" sync --no-history --shallow
    WORKING_DIRECTORY "${GCLIENT_ROOT}"
    LOGNAME gclient-sync-${TARGET_TRIPLET}
)

vcpkg_find_acquire_program(NINJA)

function(gn_gen CONFIG ARGS)
    set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${CONFIG}")

    message(STATUS "Generating build (${CONFIG})...")
    vcpkg_execute_required_process(
        COMMAND "${GN}" gen "${BUILD_DIR}" "${ARGS}"
        WORKING_DIRECTORY "${SOURCE_PATH}"
        LOGNAME generate-${CONFIG}
    )
endfunction()

function(gn_build CONFIG)
    set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${CONFIG}")

    message(STATUS "Building (${CONFIG})...")
    vcpkg_execute_build_process(
        COMMAND "${NINJA}" -C "${BUILD_DIR}" client crashpad_handler
        WORKING_DIRECTORY "${SOURCE_PATH}"
        LOGNAME build-${CONFIG}
    )
endfunction()

function(install_binaries CONFIG OUT_DIR_PREFIX)
    set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${CONFIG}")

    function(install_library NAME RELATIVE_PATH)
        find_library(_LIB ${NAME} PATHS "${BUILD_DIR}/${RELATIVE_PATH}" NO_DEFAULT_PATH)
        file(INSTALL "${_LIB}" DESTINATION "${CURRENT_PACKAGES_DIR}/${OUT_DIR_PREFIX}lib")
        unset(_LIB CACHE)
    endfunction()

    function(install_tool NAME RELATIVE_PATH)
        find_program(_TOOL ${NAME} PATHS "${BUILD_DIR}/${RELATIVE_PATH}" NO_DEFAULT_PATH)
        file(INSTALL "${_TOOL}" DESTINATION "${CURRENT_PACKAGES_DIR}/${OUT_DIR_PREFIX}tools")
        unset(_TOOL CACHE)
    endfunction()

    install_library(client obj/client)
    install_library(util obj/util)
    install_library(base obj/third_party/mini_chromium/mini_chromium/base)
    install_tool(crashpad_handler "")
endfunction()

set(DEBUG_CONFIG ${TARGET_TRIPLET}-dbg)
set(RELEASE_CONFIG ${TARGET_TRIPLET}-rel)

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

    set(OPTIONS_DBG "${OPTIONS_DBG} extra_cflags_c=\"${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_DEBUG}\" \
        extra_cflags_cc=\"${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_DEBUG}\"")

    set(OPTIONS_REL "${OPTIONS_REL} extra_cflags_c=\"${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_RELEASE}\" \
        extra_cflags_cc=\"${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_RELEASE}\"")

    set(DISABLE_WHOLE_PROGRAM_OPTIMIZATION "extra_cflags=\"/GL-\" extra_ldflags=\"/LTCG:OFF\" \
        extra_arflags=\"/LTCG:OFF\"")
    set(OPTIONS_DBG "${OPTIONS_DBG} ${DISABLE_WHOLE_PROGRAM_OPTIMIZATION}")
    set(OPTIONS_REL "${OPTIONS_REL} ${DISABLE_WHOLE_PROGRAM_OPTIMIZATION}")
endif()

gn_gen(${DEBUG_CONFIG} "--args=${OPTIONS_DBG}")
gn_gen(${RELEASE_CONFIG} "--args=${OPTIONS_REL}")

gn_build(${DEBUG_CONFIG})
gn_build(${RELEASE_CONFIG})

install_binaries(${DEBUG_CONFIG} "debug/")
install_binaries(${RELEASE_CONFIG} "")

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

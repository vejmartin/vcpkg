## # vcpkg_configure_gn
##
## Generate Ninja (GN) targets
##
## ## Usage:
## ```cmake
## vcpkg_configure_gn(
##     SOURCE_PATH <SOURCE_PATH>
##     [OPTIONS <OPTIONS>]
##     [OPTIONS_DEBUG <OPTIONS_DEBUG>]
##     [OPTIONS_RELEASE <OPTIONS_RELEASE>]
## )
## ```
##
## ## Parameters:
## ### SOURCE_PATH (required)
## The path to the GN project.
##
## ### OPTIONS
## Options to be passed to both the debug and release targets.
##
## ### OPTIONS_DEBUG
## Options to be passed to the debug target.
##
## ### OPTIONS_RELEASE
## Options to be passed to the release target.

function(vcpkg_configure_gn)
    cmake_parse_arguments(_vcg "" "SOURCE_PATH;OPTIONS;OPTIONS_DEBUG;OPTIONS_RELEASE" "" ${ARGN})

    if(NOT DEFINED _vcg_SOURCE_PATH)
        message(FATAL_ERROR "SOURCE_PATH must be specified.")
    endif()

    vcpkg_acquire_depot_tools(TOOLS GN)

    function(generate CONFIG ARGS)
        message(STATUS "Generating build (${CONFIG})...")
        vcpkg_execute_required_process(
            COMMAND "${GN}" gen "${CURRENT_BUILDTREES_DIR}/${CONFIG}" "${ARGS}"
            WORKING_DIRECTORY "${SOURCE_PATH}"
            LOGNAME generate-${CONFIG}
        )
    endfunction()

    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        generate(${TARGET_TRIPLET}-dbg "--args=${_vcg_OPTIONS} ${_vcg_OPTIONS_DEBUG}")
    endif()

    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
        generate(${TARGET_TRIPLET}-rel "--args=${_vcg_OPTIONS} ${_vcg_OPTIONS_RELEASE}")
    endif()
endfunction()
## # vcpkg_install_meson
##
## Builds a meson project previously configured with `vcpkg_configure_meson()`.
##
## ## Usage
## ```cmake
## vcpkg_install_meson()
## ```
##
## ## Examples
##
## * [fribidi](https://github.com/Microsoft/vcpkg/blob/master/ports/fribidi/portfile.cmake)
## * [libepoxy](https://github.com/Microsoft/vcpkg/blob/master/ports/libepoxy/portfile.cmake)
function(vcpkg_install_meson)
    vcpkg_find_acquire_program(NINJA)
    unset(ENV{DESTDIR}) # installation directory was already specified with '--prefix' option

    message(STATUS "Package ${TARGET_TRIPLET}-rel")
    add_to_env(LIB "${CURRENT_INSTALLED_DIR}/lib/")
    add_to_env(LIBPATH "${CURRENT_INSTALLED_DIR}/lib/")
    add_to_env(LIBRARY_PATH "{CURRENT_INSTALLED_DIR}/lib/")
    vcpkg_execute_required_process(
        COMMAND ${NINJA} install -v
        WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel
        LOGNAME package-${TARGET_TRIPLET}-rel
    )
    restore_env(LIB)
    restore_env(LIBPATH)
    restore_env(LIBRARY_PATH)
    add_to_env(LIB "${CURRENT_INSTALLED_DIR}/debug/lib/")
    add_to_env(LIBPATH "${CURRENT_INSTALLED_DIR}/debug/lib/")
    add_to_env(LIBRARY_PATH "{CURRENT_INSTALLED_DIR}/debug/lib/")
    message(STATUS "Package ${TARGET_TRIPLET}-dbg")
    vcpkg_execute_required_process(
        COMMAND ${NINJA} install -v
        WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg
        LOGNAME package-${TARGET_TRIPLET}-dbg
    )
    restore_env(LIB)
    restore_env(LIBPATH)
    restore_env(LIBRARY_PATH)

    set(RENAMED_LIBS)
    if(VCPKG_TARGET_IS_WINDOWS AND VCPKG_LIBRARY_LINKAGE STREQUAL static)
        # Meson names all static libraries lib<name>.a which basically breaks the world
        file(GLOB_RECURSE LIBRARIES "${CURRENT_PACKAGES_DIR}*/**/lib*.a")
        foreach(_library IN LISTS LIBRARIES)
            get_filename_component(LIBDIR "${_library}" DIRECTORY )
            get_filename_component(LIBNAME "${_library}" NAME)
            string(REGEX REPLACE ".a$" ".lib" LIBNAMENEW "${LIBNAME}")
            string(REGEX REPLACE "^lib" "" LIBNAMENEW "${LIBNAMENEW}")
            file(RENAME "${_library}" "${LIBDIR}/${LIBNAMENEW}")
            # For cmake fixes. 
            string(REGEX REPLACE ".a$" "" LIBRAWNAMEOLD "${LIBNAME}")
            string(REGEX REPLACE ".lib$" "" LIBRAWNAMENEW "${LIBNAMENEW}")
            list(APPEND RENAMED_LIBS ${LIBRAWNAMENEW})
            set(${LIBRAWNAME}_OLD ${LIBRAWNAMEOLD})
            set(${LIBRAWNAME}_NEW ${LIBRAWNAMENEW})
        endforeach()
        
        file(GLOB_RECURSE CMAKE_FILES "${CURRENT_PACKAGES_DIR}*/*.cmake")
        foreach(_cmake IN LISTS CMAKE_FILES)
            foreach(_lib IN LISTS RENAMED_LIBS)
                vcpkg_replace_string("${_cmake}" "${${_lib}_OLD}" "${${_lib}_NEW}")
            endforeach()
        endforeach()
    endif()
endfunction()

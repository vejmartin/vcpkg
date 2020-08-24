vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO harfbuzz/harfbuzz
    REF 05ef75c55340400d4b318bd24d742653bbf825d9
    SHA512 f238ad07600f0763103374e26fb5f9237658cc47b0ef81decd605fd82cd1892d100c2e8936a82740ca857163a3344247114701c1ee21c9dd9c6daae1e03bf6c2
    HEAD_REF master
    PATCHES
        #0001-fix-cmake-export.patch
        #0002-fix-uwp-build.patch
        #0003-remove-broken-test.patch
        # This patch is required for propagating the full list of static dependencies from freetype
        #find-package-freetype-2.patch
        # This patch is required for propagating the full list of dependencies from glib
        #glib-cmake.patch
        #fix_include.patch
)

set(OPTIONS)
if("glib" IN_LIST FEATURES)
    list(APPEND OPTIONS "-Dglib=enabled")
    list(APPEND OPTIONS "-Dgobject=disabled")
else()
    list(APPEND OPTIONS "-Dglib=enabled")
    list(APPEND OPTIONS "-Dgobject=disabled")
endif()
if("cairo" IN_LIST FEATURES)
    list(APPEND OPTIONS "-Dcairo=enabled")
else()
    list(APPEND OPTIONS "-Dcairo=disabled")
endif()
if("icu" IN_LIST FEATURES)
    list(APPEND OPTIONS "-Dicu=enabled")
else()
    list(APPEND OPTIONS "-Dicu=disabled")
endif()
if("graphite" IN_LIST FEATURES)
    list(APPEND OPTIONS "-Dgraphite=enabled")
else()
    list(APPEND OPTIONS "-Dgraphite=disabled")
endif()
if("fontconfig" IN_LIST FEATURES)
    list(APPEND OPTIONS "-Dfontconfig=enabled")
else()
    list(APPEND OPTIONS "-Dfontconfig=disabled")
endif()
if("freetype" IN_LIST FEATURES)
    list(APPEND OPTIONS "-Dfreetype=enabled")
else()
    list(APPEND OPTIONS "-Dfreetype=disabled")
endif()
if("gdi" IN_LIST FEATURES)
    if(NOT VCPKG_TARGET_IS_WINDOWS)
        message(FATAL_ERROR "Featue GDI is only supported on Windows!")
    endif()
    list(APPEND OPTIONS "-Dgdi=enabled")
else()
    list(APPEND OPTIONS "-Dgdi=disabled")
endif()
if("directwrite" IN_LIST FEATURES)
    if(NOT VCPKG_TARGET_IS_WINDOWS)
        message(FATAL_ERROR "Featue directwrite is only supported on Windows!")
    endif()
    list(APPEND OPTIONS "-Ddirectwrite=enabled")
else()
    list(APPEND OPTIONS "-Ddirectwrite=disabled")
endif()
if("coretext" IN_LIST FEATURES)
    if(NOT VCPKG_TARGET_IS_OSX)
        message(FATAL_ERROR "Featue coretext is only supported on Windows!")
    endif()
    list(APPEND OPTIONS "-Dcoretext=enabled")
else()
    list(APPEND OPTIONS "-Dcoretext=disabled")
endif()
vcpkg_configure_meson(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS ${OPTIONS}
        "-Dtests=disabled"
)

vcpkg_install_meson()
#vcpkg_fixup_cmake_targets()
vcpkg_fixup_pkgconfig()
vcpkg_copy_pdbs()


# Handle copyright
file(INSTALL ${SOURCE_PATH}/COPYING DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)

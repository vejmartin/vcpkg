# Glib uses winapi functions not available in WindowsStore
vcpkg_fail_port_install(ON_TARGET "UWP")

# Glib relies on DllMain on Windows
#if (VCPKG_TARGET_IS_WINDOWS)
#    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
#endif()

set(GLIB_VERSION 2.65.2)
vcpkg_download_distfile(ARCHIVE
    URLS "https://ftp.gnome.org/pub/gnome/sources/glib/2.65/glib-${GLIB_VERSION}.tar.xz"
    FILENAME "glib-${GLIB_VERSION}.tar.xz"
    SHA512 9a2ebd226b2d0bcd7fbfeeff7a0dd48f7a604636a19672dae5c0547dd8abe5f2bf3bd505e48797095f740775bac5e8eeb1230e754b9d03171d7d04c2363432fc)

vcpkg_extract_source_archive_ex(
    OUT_SOURCE_PATH SOURCE_PATH
    ARCHIVE ${ARCHIVE}
    REF ${GLIB_VERSION}
    PATCHES
        remove_tests.patch
        #use-libiconv-on-windows.patch
        #arm64-defines.patch
        #fix-arm-builds.patch
)


if (selinux IN_LIST FEATURES AND NOT VCPKG_TARGET_IS_WINDOWS AND NOT EXISTS "/usr/include/selinux")
    message("Selinux was not found in its typical system location. Your build may fail. You can install Selinux with \"apt-get install selinux\".")
    list(APPEND OPTIONS -Dselinux=true)
endif()

vcpkg_configure_meson(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        -Diconv=external
        -Dbuild_tests=false
        ${OPTIONS}
        
)

vcpkg_install_meson()

vcpkg_copy_pdbs()

set(GLIB_TOOLS  gdbus
                gio
                gio-querymodules
                glib-compile-resources
                glib-compile-schemas
                gobject-query
                gresource
                gsettings
                )
set(GLIB_SCRIPTS gdbus-codegen glib-genmarshal glib-mkenums gtester-report)


if(VCPKG_TARGET_IS_WINDOWS AND VCPKG_TARGET_ARCHITECTURE MATCHES "x64|arm64")
    list(APPEND GLIB_TOOLS  gspawn-win64-helper${VCPKG_EXECUTABLE_SUFFIX}
                            gspawn-win64-helper-console${VCPKG_EXECUTABLE_SUFFIX})
elseif(VCPKG_TARGET_IS_WINDOWS AND VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    list(APPEND GLIB_TOOLS  gspawn-win32-helper${VCPKG_EXECUTABLE_SUFFIX}
                            gspawn-win32-helper-console${VCPKG_EXECUTABLE_SUFFIX})
endif()
vcpkg_copy_tools(TOOL_NAMES ${GLIB_TOOLS} AUTO_CLEAN)
foreach(script IN LISTS GLIB_SCRIPTS)
    file(RENAME "${CURRENT_PACKAGES_DIR}/bin/${script}" "${CURRENT_PACKAGES_DIR}/tools/${PORT}/${script}")
    file(REMOVE "${CURRENT_PACKAGES_DIR}/debug/bin/${script}")
endforeach()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

IF(VCPKG_TARGET_IS_WINDOWS)
    set(SYSTEM_LIBRARIES dnsapi iphlpapi winmm lshlwapi)
else()
endif()
if(EXISTS "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/gio-2.0.pc")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/lib/pkgconfig/gio-2.0.pc" "\${bindir}" "\${bindir}/../tools/${port}")
endif()
if(EXISTS "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/gio-2.0.pc")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/gio-2.0.pc" "\${bindir}" "\${bindir}/../../tools/${port}")
endif()
vcpkg_fixup_pkgconfig(SYSTEM_LIBRARIES ${SYSTEM_LIBRARIES})

file(INSTALL ${SOURCE_PATH}/COPYING DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)

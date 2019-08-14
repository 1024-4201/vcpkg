function(configure_qt)
    cmake_parse_arguments(_csc "" "SOURCE_PATH;TARGET_PLATFORM;HOST_PLATFORM" "OPTIONS;OPTIONS_DEBUG;OPTIONS_RELEASE" ${ARGN})

    if(NOT _csc_TARGET_PLATFORM)
        message(FATAL_ERROR "configure_qt requires a TARGET_PLATFORM argument.")
    endif()
    
    if(DEFINED _csc_HOST_PLATFORM)
        list(APPEND _csc_OPTIONS "-platform ${HOST_PLATFORM}")
    endif()
    
    if(DEFINED VCPKG_QT_HOST_TOOLS_ROOT_DIR)
        ## vcpkg internal file struture assumed here!
        vcpkg_add_to_path("${VCPKG_QT_HOST_TOOLS_ROOT_DIR}/bin")        
        list(APPEND _csc_OPTIONS "-external-hostbindir ${VCPKG_QT_HOST_TOOLS_ROOT_DIR}/tools/qt5/bin") # we only use release binaries for building
    endif()
    
    vcpkg_find_acquire_program(PERL)
    get_filename_component(PERL_EXE_PATH ${PERL} DIRECTORY)

    file(REMOVE_RECURSE ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg)
    vcpkg_add_to_path("${PERL_EXE_PATH}")

    if(VCPKG_LIBRARY_LINKAGE STREQUAL static)
        list(APPEND _csc_OPTIONS "-static")
    else()
        list(APPEND _csc_OPTIONS "-separate-debug-info")
    endif()
   
    if(VCPKG_TARGET_IS_WINDOWS AND VCPKG_CRT_LINKAGE STREQUAL "static")
        list(APPEND _csc_OPTIONS "-static-runtime")
    endif()

    list(APPEND _csc_OPTIONS "-verbose")
    
    #list(APPEND _csc_OPTIONS -optimized-tools)

    list(APPEND _csc_OPTIONS_RELEASE -release)
    list(APPEND _csc_OPTIONS_RELEASE -force-debug-info)
    list(APPEND _csc_OPTIONS_RELEASE -ltcg)
    
    list(APPEND _csc_OPTIONS_DEBUG -debug)
    
    if(CMAKE_HOST_WIN32)
        set(CONFIGURE_BAT "configure.bat")
    else()
        set(CONFIGURE_BAT "configure")
    endif()
    
    unset(BUILDTYPES)
    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        set(_buildname "DEBUG")
        list(APPEND BUILDTYPES ${_buildname})
        set(_short_name_${_buildname} "dbg")
        set(_path_suffix_${_buildname} "/debug")        
    endif()
    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
        set(_buildname "RELEASE")
        list(APPEND BUILDTYPES ${_buildname})
        set(_short_name_${_buildname} "rel")
        set(_path_suffix_${_buildname} "")   
    endif()
    unset(_buildname)
    
    foreach(_buildname ${BUILDTYPES})
        set(_build_triplet ${TARGET_TRIPLET}-${_short_name_${_buildname}})
        message(STATUS "Configuring ${_build_triplet}")
        set(_build_dir ${CURRENT_BUILDTREES_DIR}/${_build_triplet})
        file(MAKE_DIRECTORY ${_build_dir})
        vcpkg_execute_required_process(
            COMMAND "${_csc_SOURCE_PATH}/${CONFIGURE_BAT}" ${_csc_OPTIONS} ${_csc_OPTIONS_${_buildname}}
                -prefix ${CURRENT_PACKAGES_DIR}
                -extprefix ${CURRENT_PACKAGES_DIR}
                -hostprefix ${CURRENT_PACKAGES_DIR}/tools/qt5${_path_suffix_${_buildname}}
                -hostlibdir ${CURRENT_PACKAGES_DIR}/tools/qt5${_path_suffix_${_buildname}}/lib
                -hostbindir ${CURRENT_PACKAGES_DIR}/tools/qt5${_path_suffix_${_buildname}}/bin
                -archdatadir ${CURRENT_PACKAGES_DIR}/tools/qt5${_path_suffix_${_buildname}}
                -datadir ${CURRENT_PACKAGES_DIR}/tools/qt5${_path_suffix_${_buildname}}
                -plugindir ${CURRENT_PACKAGES_DIR}/${_path_suffix_${_buildname}}/plugins
                -qmldir ${CURRENT_PACKAGES_DIR}/${_path_suffix_${_buildname}}/qml
                -headerdir ${CURRENT_PACKAGES_DIR}/include
                -libexecdir ${CURRENT_PACKAGES_DIR}${_path_suffix_${_buildname}}/tools/qt5
                -bindir ${CURRENT_PACKAGES_DIR}${_path_suffix_${_buildname}}/bin
                -libdir ${CURRENT_PACKAGES_DIR}${_path_suffix_${_buildname}}/lib
                -I ${CURRENT_INSTALLED_DIR}/include
                -L ${CURRENT_INSTALLED_DIR}${_path_suffix_${_buildname}}/lib 
                -L ${CURRENT_INSTALLED_DIR}${_path_suffix_${_buildname}}/lib/manual-link
                -xplatform ${_csc_TARGET_PLATFORM}
            WORKING_DIRECTORY ${_build_dir}
            LOGNAME config-${_build_triplet}
        )
        # Note archdatadir and datadir are required to be prefixed with the hostprefix? 
        message(STATUS "Configuring ${_build_triplet} done")
        
        # Copy configuration dependent qt.conf
        file(TO_CMAKE_PATH "${CURRENT_PACKAGES_DIR}" CMAKE_CURRENT_PACKAGES_DIR_PATH)
        file(TO_CMAKE_PATH "${VCPKG_QT_HOST_TOOLS_ROOT_DIR}" CMAKE_VCPKG_QT_HOST_ROOT_PATH)
        file(READ "${CURRENT_BUILDTREES_DIR}/${_build_triplet}/bin/qt.conf" _contents)
        string(REPLACE "${CMAKE_CURRENT_PACKAGES_DIR_PATH}" "\${CURRENT_INSTALLED_DIR}" _contents ${_contents})
        string(REPLACE "[EffectiveSourcePaths]" "" _contents ${_contents})
        string(REGEX REPLACE "[EffectivePaths][ \t\r\n]+Prefix=\.\." "" _contents ${_contents})
        string(REGEX REPLACE "[EffectiveSourcePaths][ \t\r\n]+Prefix=.+$" "" _contents ${_contents})
        file(WRITE "${CURRENT_PACKAGES_DIR}/tools/qt5/qt_${_build_type_${_buildname}}.conf" "${_contents}")     
    endforeach()  

endfunction()

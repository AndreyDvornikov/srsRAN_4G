#----------------------------------------------------------------
# Generated CMake target import file for configuration "RelWithDebInfo".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "czmq" for configuration "RelWithDebInfo"
set_property(TARGET czmq APPEND PROPERTY IMPORTED_CONFIGURATIONS RELWITHDEBINFO)
set_target_properties(czmq PROPERTIES
  IMPORTED_LOCATION_RELWITHDEBINFO "${_IMPORT_PREFIX}/lib/libczmq.so.4.2.1"
  IMPORTED_SONAME_RELWITHDEBINFO "libczmq.so.4"
  )

list(APPEND _cmake_import_check_targets czmq )
list(APPEND _cmake_import_check_files_for_czmq "${_IMPORT_PREFIX}/lib/libczmq.so.4.2.1" )

# Import target "czmq-static" for configuration "RelWithDebInfo"
set_property(TARGET czmq-static APPEND PROPERTY IMPORTED_CONFIGURATIONS RELWITHDEBINFO)
set_target_properties(czmq-static PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELWITHDEBINFO "C"
  IMPORTED_LOCATION_RELWITHDEBINFO "${_IMPORT_PREFIX}/lib/libczmq.a"
  )

list(APPEND _cmake_import_check_targets czmq-static )
list(APPEND _cmake_import_check_files_for_czmq-static "${_IMPORT_PREFIX}/lib/libczmq.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)

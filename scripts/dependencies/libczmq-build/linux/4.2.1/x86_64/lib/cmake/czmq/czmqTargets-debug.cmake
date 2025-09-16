#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "czmq" for configuration "Debug"
set_property(TARGET czmq APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(czmq PROPERTIES
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/lib/libczmq.so.4.2.2"
  IMPORTED_SONAME_DEBUG "libczmq.so.4"
  )

list(APPEND _cmake_import_check_targets czmq )
list(APPEND _cmake_import_check_files_for_czmq "${_IMPORT_PREFIX}/lib/libczmq.so.4.2.2" )

# Import target "czmq-static" for configuration "Debug"
set_property(TARGET czmq-static APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(czmq-static PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "C"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/lib/libczmq.a"
  )

list(APPEND _cmake_import_check_targets czmq-static )
list(APPEND _cmake_import_check_files_for_czmq-static "${_IMPORT_PREFIX}/lib/libczmq.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)

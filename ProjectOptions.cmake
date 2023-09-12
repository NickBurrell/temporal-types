include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(temporal_types_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(temporal_types_setup_options)
  option(temporal_types_ENABLE_HARDENING "Enable hardening" ON)
  option(temporal_types_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    temporal_types_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    temporal_types_ENABLE_HARDENING
    OFF)

  temporal_types_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR temporal_types_PACKAGING_MAINTAINER_MODE)
    option(temporal_types_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(temporal_types_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(temporal_types_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(temporal_types_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(temporal_types_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(temporal_types_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(temporal_types_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(temporal_types_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(temporal_types_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(temporal_types_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(temporal_types_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(temporal_types_ENABLE_PCH "Enable precompiled headers" OFF)
    option(temporal_types_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(temporal_types_ENABLE_IPO "Enable IPO/LTO" ON)
    option(temporal_types_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(temporal_types_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(temporal_types_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(temporal_types_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(temporal_types_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(temporal_types_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(temporal_types_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(temporal_types_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(temporal_types_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(temporal_types_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(temporal_types_ENABLE_PCH "Enable precompiled headers" OFF)
    option(temporal_types_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      temporal_types_ENABLE_IPO
      temporal_types_WARNINGS_AS_ERRORS
      temporal_types_ENABLE_USER_LINKER
      temporal_types_ENABLE_SANITIZER_ADDRESS
      temporal_types_ENABLE_SANITIZER_LEAK
      temporal_types_ENABLE_SANITIZER_UNDEFINED
      temporal_types_ENABLE_SANITIZER_THREAD
      temporal_types_ENABLE_SANITIZER_MEMORY
      temporal_types_ENABLE_UNITY_BUILD
      temporal_types_ENABLE_CLANG_TIDY
      temporal_types_ENABLE_CPPCHECK
      temporal_types_ENABLE_COVERAGE
      temporal_types_ENABLE_PCH
      temporal_types_ENABLE_CACHE)
  endif()

  temporal_types_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (temporal_types_ENABLE_SANITIZER_ADDRESS OR temporal_types_ENABLE_SANITIZER_THREAD OR temporal_types_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(temporal_types_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(temporal_types_global_options)
  if(temporal_types_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    temporal_types_enable_ipo()
  endif()

  temporal_types_supports_sanitizers()

  if(temporal_types_ENABLE_HARDENING AND temporal_types_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR temporal_types_ENABLE_SANITIZER_UNDEFINED
       OR temporal_types_ENABLE_SANITIZER_ADDRESS
       OR temporal_types_ENABLE_SANITIZER_THREAD
       OR temporal_types_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${temporal_types_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${temporal_types_ENABLE_SANITIZER_UNDEFINED}")
    temporal_types_enable_hardening(temporal_types_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(temporal_types_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(temporal_types_warnings INTERFACE)
  add_library(temporal_types_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  temporal_types_set_project_warnings(
    temporal_types_warnings
    ${temporal_types_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(temporal_types_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(temporal_types_options)
  endif()

  include(cmake/Sanitizers.cmake)
  temporal_types_enable_sanitizers(
    temporal_types_options
    ${temporal_types_ENABLE_SANITIZER_ADDRESS}
    ${temporal_types_ENABLE_SANITIZER_LEAK}
    ${temporal_types_ENABLE_SANITIZER_UNDEFINED}
    ${temporal_types_ENABLE_SANITIZER_THREAD}
    ${temporal_types_ENABLE_SANITIZER_MEMORY})

  set_target_properties(temporal_types_options PROPERTIES UNITY_BUILD ${temporal_types_ENABLE_UNITY_BUILD})

  if(temporal_types_ENABLE_PCH)
    target_precompile_headers(
      temporal_types_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(temporal_types_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    temporal_types_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(temporal_types_ENABLE_CLANG_TIDY)
    temporal_types_enable_clang_tidy(temporal_types_options ${temporal_types_WARNINGS_AS_ERRORS})
  endif()

  if(temporal_types_ENABLE_CPPCHECK)
    temporal_types_enable_cppcheck(${temporal_types_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(temporal_types_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    temporal_types_enable_coverage(temporal_types_options)
  endif()

  if(temporal_types_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(temporal_types_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(temporal_types_ENABLE_HARDENING AND NOT temporal_types_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR temporal_types_ENABLE_SANITIZER_UNDEFINED
       OR temporal_types_ENABLE_SANITIZER_ADDRESS
       OR temporal_types_ENABLE_SANITIZER_THREAD
       OR temporal_types_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    temporal_types_enable_hardening(temporal_types_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()

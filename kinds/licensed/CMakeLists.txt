cmake_minimum_required(VERSION 3.5)

# Set extension name here
set(TARGET_NAME waddle)

# DuckDB's extension distribution supports vcpkg. As such, dependencies can be added in ./vcpkg.json and then
# used in cmake with find_package. Feel free to remove or replace with other dependencies.
# Note that it should also be removed from vcpkg.json to prevent needlessly installing it..
find_package(OpenSSL REQUIRED)

set(EXTENSION_NAME ${TARGET_NAME}_extension)
set(LOADABLE_EXTENSION_NAME ${TARGET_NAME}_loadable_extension)

project(${TARGET_NAME})

set(CMAKE_CXX_STANDARD "17" CACHE STRING "C++ standard to enforce")
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(src/include)

set(EXTENSION_SOURCES src/waddle_extension.cpp)

build_static_extension(${TARGET_NAME} ${EXTENSION_SOURCES})
build_loadable_extension(${TARGET_NAME} " " ${EXTENSION_SOURCES})

# Link OpenSSL in both the static library as the loadable extension
target_link_libraries(${EXTENSION_NAME} OpenSSL::SSL OpenSSL::Crypto)
target_link_libraries(${LOADABLE_EXTENSION_NAME} OpenSSL::SSL OpenSSL::Crypto)

# The kista SDK (hugr-lab/extension-ci-tools, kista/sdk/cpp): licences and usage reports.
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/extension-ci-tools/kista/sdk/cpp kista_sdk)
target_link_libraries(${EXTENSION_NAME} kista_sdk)
target_link_libraries(${LOADABLE_EXTENSION_NAME} kista_sdk)

# The keys this build trusts licences from: KISTA_LICENSE_KEYS (one to four PEM files, ';'-separated,
# passed by extension-ci-tools/makefiles/kista.Makefile; Enterest's builders set it), or
# license-key.pem. As the template made it, license-key.pem is the SDK's test key, whose private half
# is public: put the public key of the issuer that signs your licences there. A tag build fails on
# the test key (scripts/check-license-key.sh).
if(NOT KISTA_LICENSE_KEYS)
  set(KISTA_LICENSE_KEYS ${CMAKE_CURRENT_SOURCE_DIR}/license-key.pem)
endif()
# A warning when a trusted key is one of the SDK's test keys (whitespace aside; the tag check and the
# SDK compare the keys themselves)
set(test_keys ${CMAKE_CURRENT_SOURCE_DIR}/extension-ci-tools/kista/sdk/cpp/test/keys)
foreach(key ${KISTA_LICENSE_KEYS})
  if(EXISTS ${key})
    file(READ ${key} trusted)
    string(REGEX REPLACE "[ \t\r\n]" "" trusted "${trusted}")
    foreach(test test-only-2048 test-only-untrusted-2048)
      file(READ ${test_keys}/${test}.pub.pem test_key)
      string(REGEX REPLACE "[ \t\r\n]" "" test_key "${test_key}")
      if(trusted STREQUAL test_key)
        message(WARNING "${TARGET_NAME}: ${key} is the kista SDK's test key ${test}; anyone can sign "
                        "licences for it. Trust the public key of your licence issuer before a release.")
      endif()
    endforeach()
  endif()
endforeach()
kista_sdk_license_keys(${EXTENSION_NAME} ${KISTA_LICENSE_KEYS})
kista_sdk_license_keys(${LOADABLE_EXTENSION_NAME} ${KISTA_LICENSE_KEYS})

# kista_sdk goes with the extension's static library into DuckDB's export set, which needs it
install(
  TARGETS ${EXTENSION_NAME} kista_sdk
  EXPORT "${DUCKDB_EXPORT_SET}"
  LIBRARY DESTINATION "${INSTALL_LIB_DIR}"
  ARCHIVE DESTINATION "${INSTALL_LIB_DIR}")

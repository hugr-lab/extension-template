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
  file(READ ${CMAKE_CURRENT_SOURCE_DIR}/license-key.pem own_key)
  file(READ ${CMAKE_CURRENT_SOURCE_DIR}/extension-ci-tools/kista/sdk/cpp/test/keys/test-only-2048.pub.pem test_key)
  string(REPLACE "\r" "" own_key "${own_key}")
  if(own_key STREQUAL test_key)
    message(WARNING "${TARGET_NAME}: license-key.pem is the kista SDK's test key; anyone can sign licences for it. "
                    "Put the public key of your licence issuer there before a release.")
  endif()
endif()
kista_sdk_license_keys(${EXTENSION_NAME} ${KISTA_LICENSE_KEYS})
kista_sdk_license_keys(${LOADABLE_EXTENSION_NAME} ${KISTA_LICENSE_KEYS})

# kista_sdk goes with the extension's static library into DuckDB's export set, which needs it
install(
  TARGETS ${EXTENSION_NAME} kista_sdk
  EXPORT "${DUCKDB_EXPORT_SET}"
  LIBRARY DESTINATION "${INSTALL_LIB_DIR}"
  ARCHIVE DESTINATION "${INSTALL_LIB_DIR}")

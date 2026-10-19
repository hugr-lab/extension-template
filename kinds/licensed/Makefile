PROJ_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Configuration of extension
EXT_NAME=waddle
EXT_CONFIG=${PROJ_DIR}extension_config.cmake

# Include the Makefile from extension-ci-tools
include extension-ci-tools/makefiles/duckdb_extension.Makefile
# KISTA_LICENSE_KEYS to CMake (make release KISTA_LICENSE_KEYS='/keys/a.pem;/keys/b.pem')
include extension-ci-tools/makefiles/kista.Makefile

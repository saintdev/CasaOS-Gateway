#!/bin/sh

set -e

## base variables
readonly APP_NAME="casaos-gateway"
readonly APP_NAME_SHORT="gateway"

# copy config files
readonly CONF_PATH=/etc/casaos
readonly CONF_FILE=${CONF_PATH}/${APP_NAME_SHORT}.ini
readonly CONF_FILE_SAMPLE=${CONF_PATH}/${APP_NAME_SHORT}.ini.sample

if [ ! -f "${CONF_FILE}" ]; then \
    echo "Initializing config file..."
    cp -v "${CONF_FILE_SAMPLE}" "${CONF_FILE}"; \
fi

echo "Enabling service..."
rc-update add "${APP_NAME}" default

#echo "Starting service..."
#rc-service --ifexists "${APP_NAME}"

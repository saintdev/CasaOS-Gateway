#!/bin/bash

set -e

# functions
__info() {
    echo -e "🟩 ${1}"
}

__info_done() {
    echo -e "✅ ${1}"
}

__warning() {
    echo -e "🟨 ${1}"
}

__error() {
    echo "🟥 ${1}"
    exit 1
}

__normalize_version() {
    local version
    if [ "${1::1}" = "v" ]; then
        version="${1:1}"
    else
        version="${1}"
    fi

    echo "$version"
}

__is_version_gt() {
    test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"
}

__is_migration_needed() {
    local version1
    local version2

    version1=$(__normalize_version "${1}")
    version2=$(__normalize_version "${2}")

    if [ "${version1}" = "${version2}" ]; then
        return 1
    fi

    if [ "CURRENT_VERSION_NOT_FOUND" = "${version1}" ]; then
        return 1
    fi

    if [ "LEGACY_WITHOUT_VERSION" = "${version1}" ]; then
        return 0
    fi

    __is_version_gt "${version2}" "${version1}"
}
__get_download_domain(){
    local region
    # Use ipconfig.io/country and https://ifconfig.io/country_code to get the country code
    region=$(curl --connect-timeout 2 -s ipconfig.io/country || echo "")
    if [ "${region}" = "" ]; then
       region=$(curl --connect-timeout 2 -s https://ifconfig.io/country_code || echo "")
    fi
    if [[ "${region}" = "China" ]] || [[ "${region}" = "CN" ]]; then
        echo "https://casaos.oss-cn-shanghai.aliyuncs.com/"
    else
        echo "https://github.com/"
    fi
}

DOWNLOAD_DOMAIN=$(__get_download_domain)
BUILD_PATH=$(dirname "${BASH_SOURCE[0]}")/../../..

readonly BUILD_PATH
readonly SOURCE_ROOT=${BUILD_PATH}/sysroot

readonly APP_NAME="casaos-gateway"
readonly APP_NAME_FORMAL="CasaOS-Gateway"
readonly APP_NAME_SHORT="gateway"
readonly APP_NAME_LEGACY="casaos"

# check if migration is needed
readonly SOURCE_BIN_PATH=${SOURCE_ROOT}/usr/bin
readonly SOURCE_BIN_FILE=${SOURCE_BIN_PATH}/${APP_NAME}

readonly CURRENT_BIN_PATH=/usr/bin
readonly CURRENT_BIN_PATH_LEGACY=/usr/local/bin
readonly CURRENT_BIN_FILE=${CURRENT_BIN_PATH}/${APP_NAME}

CURRENT_BIN_FILE_LEGACY=$(realpath -e ${CURRENT_BIN_PATH}/${APP_NAME_LEGACY} || realpath -e ${CURRENT_BIN_PATH_LEGACY}/${APP_NAME_LEGACY} || which ${APP_NAME_LEGACY} || echo CURRENT_BIN_FILE_LEGACY_NOT_FOUND)
readonly CURRENT_BIN_FILE_LEGACY

SOURCE_VERSION="$(${SOURCE_BIN_FILE} -v)"
readonly SOURCE_VERSION

CURRENT_VERSION="$(${CURRENT_BIN_FILE} -v || ${CURRENT_BIN_FILE_LEGACY} -v || (stat "${CURRENT_BIN_FILE_LEGACY}" > /dev/null && echo LEGACY_WITHOUT_VERSION) || echo CURRENT_VERSION_NOT_FOUND)"
readonly CURRENT_VERSION

__info_done "CURRENT_VERSION: ${CURRENT_VERSION}"
__info_done "SOURCE_VERSION: ${SOURCE_VERSION}"

NEED_MIGRATION=$(__is_migration_needed "${CURRENT_VERSION}" "${SOURCE_VERSION}" && echo "true" || echo "false")
readonly NEED_MIGRATION

if [ "${NEED_MIGRATION}" = "false" ]; then
    __info_done "Migration is not needed."
    exit 0
fi

ARCH="unknown"

case $(uname -m) in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    armv7l)
        ARCH="arm-7"
        ;;
    *)
        __error "Unsupported architecture"
        ;;
esac

__info "ARCH: ${ARCH}"

MIGRATION_SERVICE_DIR=${1}

if [ -z "${MIGRATION_SERVICE_DIR}" ]; then
    MIGRATION_SERVICE_DIR=${BUILD_PATH}/scripts/migration/service.d/${APP_NAME_SHORT}
fi

readonly MIGRATION_LIST_FILE=${MIGRATION_SERVICE_DIR}/migration.list

MIGRATION_PATH=()
CURRENT_VERSION_FOUND="false"

# a VERSION_PAIR looks like "v0.3.5 v0.3.6-alpha2"
#
# - "v0.3.5" is the current version installed on this host
# - "v0.3.6-alpha2" is the version of the migration tool from GitHub
while read -r VERSION_PAIR; do
    if [ -z "${VERSION_PAIR}" ]; then
        continue
    fi

    # obtain "v0.3.5" from "v0.3.5 v0.3.6-alpha2"
    VER1=$(echo "${VERSION_PAIR}" | cut -d' ' -f1)

    # obtain "v0.3.6-alpha2" from "v0.3.5 v0.3.6-alpha2"
    VER2=$(echo "${VERSION_PAIR}" | cut -d' ' -f2)

    if [ "${CURRENT_VERSION}" = "${VER1// /}" ] || [ "${CURRENT_VERSION}" = "LEGACY_WITHOUT_VERSION" ]; then
        CURRENT_VERSION_FOUND="true"
    fi

    if [ "${CURRENT_VERSION_FOUND}" = "true" ]; then
        MIGRATION_PATH+=("${VER2// /}")
    fi
done < "${MIGRATION_LIST_FILE}"

if [ ${#MIGRATION_PATH[@]} -eq 0 ]; then
    __warning "No migration path found from ${CURRENT_VERSION} to ${SOURCE_VERSION}"
    exit 0
fi

pushd "${MIGRATION_SERVICE_DIR}"

{
    for VER2 in "${MIGRATION_PATH[@]}"; do
        MIGRATION_TOOL_FILE=linux-"${ARCH}"-"${APP_NAME}"-migration-tool-"${VER2}".tar.gz

        if [ -f "${MIGRATION_TOOL_FILE}" ]; then
            __info "Migration tool ${MIGRATION_TOOL_FILE} exists. Skip downloading."
            continue
        fi

        MIGRATION_TOOL_URL=${DOWNLOAD_DOMAIN}IceWhaleTech/"${APP_NAME_FORMAL}"/releases/download/"${VER2}"/linux-"${ARCH}"-"${APP_NAME}"-migration-tool-"${VER2}".tar.gz
        __info "Dowloading ${MIGRATION_TOOL_URL}..."
        curl -fsSL -O "${MIGRATION_TOOL_URL}"
    done
} || {
    popd
    __error "Failed to download migration tools"
}

{
    for VER2 in "${MIGRATION_PATH[@]}"; do
        MIGRATION_TOOL_FILE=linux-"${ARCH}"-"${APP_NAME}"-migration-tool-"${VER2}".tar.gz
        __info "Extracting ${MIGRATION_TOOL_FILE}..."
        tar zxvf "${MIGRATION_TOOL_FILE}" || __error "Failed to extract ${MIGRATION_TOOL_FILE}"

        MIGRATION_TOOL_PATH=build/sysroot/usr/bin/${APP_NAME}-migration-tool
        __info "Running ${MIGRATION_TOOL_PATH}..."
        ${MIGRATION_TOOL_PATH}
    done
} || {
    popd
    __error "Failed to extract and run migration tools"
}

popd

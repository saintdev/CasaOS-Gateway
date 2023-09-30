#!/bin/sh

set -e

readonly APP_NAME_SHORT=gateway

__get_setup_script_directory_by_os_release() {

	(
		cd "$(dirname "${0}")/../service.d/${APP_NAME_SHORT}" >/dev/null 2>&1

		# shellcheck source=/dev/null
		(
			. /etc/os-release
			{
				cd "${ID}"/"${VERSION_CODENAME}" >/dev/null 2>&1
			} || {
				cd "${ID}" >/dev/null 2>&1
			} || {
                [ -n "${ID_LIKE}" ] && for ID in ${ID_LIKE}; do
				    cd "${ID}" >/dev/null && break
                done
			} || {
				echo "Unsupported OS: ${ID} ${VERSION_CODENAME} (${ID_LIKE})"
				exit 1
			}

			pwd
		) || {
			echo "Unsupported OS: unknown"
			exit 1
		}

	) || exit 1
}

SETUP_SCRIPT_DIRECTORY=$(__get_setup_script_directory_by_os_release)

readonly SETUP_SCRIPT_DIRECTORY
readonly SETUP_SCRIPT_FILENAME="cleanup-${APP_NAME_SHORT}.sh"
readonly SETUP_SCRIPT_FILEPATH="${SETUP_SCRIPT_DIRECTORY}/${SETUP_SCRIPT_FILENAME}"

echo "🟩 Running ${SETUP_SCRIPT_FILENAME}..."
$SHELL "${SETUP_SCRIPT_FILEPATH}" "${BUILD_PATH}"

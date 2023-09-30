#!/bin/sh

set -e

readonly CASA_EXEC=casaos-gateway
readonly CASA_SERVICE=casaos-gateway

readonly CASA_CONF=/etc/casaos/gateway.ini

readonly COLOUR_GREEN='\e[38;5;154m' # green  		| Lines, bullets and separators
readonly COLOUR_WHITE='\e[1m'        # Bold white	| Main descriptions
readonly COLOUR_GREY='\e[90m'        # Grey  		| Credits
readonly COLOUR_RED='\e[91m'         # Red   		| Update notifications Alert
readonly COLOUR_YELLOW='\e[33m'      # Yellow		| Emphasis

Show() {
    case $1 in
        0 ) echo -e "${COLOUR_GREY}[$COLOUR_RESET${COLOUR_GREEN}  OK  $COLOUR_RESET${COLOUR_GREY}]$COLOUR_RESET $2";;  # OK
        1 ) echo -e "${COLOUR_GREY}[$COLOUR_RESET${COLOUR_RED}FAILED$COLOUR_RESET${COLOUR_GREY}]$COLOUR_RESET $2";;    # FAILED
        2 ) echo -e "${COLOUR_GREY}[$COLOUR_RESET${COLOUR_GREEN} INFO $COLOUR_RESET${COLOUR_GREY}]$COLOUR_RESET $2";;  # INFO
        3 ) echo -e "${COLOUR_GREY}[$COLOUR_RESET${COLOUR_YELLOW}NOTICE$COLOUR_RESET${COLOUR_GREY}]$COLOUR_RESET $2";; # NOTICE
    esac
}

Warn() {
    echo -e "${COLOUR_RED}$1$COLOUR_RESET"
}

trap 'onCtrlC' INT
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
}

if [ ! -x "$(command -v ${CASA_EXEC})" ]; then
    Show 2 "${CASA_EXEC} is not detected, exit the script."
    exit 1
fi

Show 2 "Stopping ${CASA_SERVICE}..."
{
    rc-update "${CASA_SERVICE}" del
    rc-service --ifexists "${CASA_SERVICE}" stop
} || Show 3 "Failed to disable ${CASA_SERVICE}"

rm -rvf "$(which ${CASA_EXEC})" || Show 3 "Failed to remove ${CASA_EXEC}"
rm -rvf "${CASA_CONF}" || Show 3 "Failed to remove ${CASA_CONF}"

rm -rvf /var/run/casaos/gateway.pid
rm -rvf /var/run/casaos/management.url
rm -rvf /var/run/casaos/routes.json
rm -rvf /var/run/casaos/static.url
rm -rvf /var/lib/casaos/www

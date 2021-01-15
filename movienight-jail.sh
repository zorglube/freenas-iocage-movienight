#!/bin/sh
# Build an iocage jail under FreeNAS 11.3 using the current release of Movie Night
# git clone https://github.com/zorglube/freenas-iocage-movienight

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

#####
#
# General configuration
#
#####

# Initialize defaults
JAIL_IP=""
JAIL_INTERFACES=""
DEFAULT_GW_IP=""
INTERFACE="vnet0"
VNET="on"
JAIL_NAME="movienight"
CONFIG_NAME="mn-config"
GO_DL_VERSION=""
UID="movien"
GID=${UID}
UID_GID_ID="850"
ENV_VAR_UPDATE="env_var_update.sh"
TARGET=""
ARCH=""
MN_REPO=""
# turn on the colors for the `iocage` command. 
IOCAGE_COLOR=true

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "${SCRIPT}")

# Check for mn-config and set configuration
if ! [ -e "${SCRIPTPATH}"/"${CONFIG_NAME}" ]; then
  echo "${SCRIPTPATH}/${CONFIG_NAME} must exist."
  exit 1
fi

# Load conf vars
. "${SCRIPTPATH}"/"${CONFIG_NAME}"

INCLUDES_PATH="${SCRIPTPATH}"/includes

JAILS_MOUNT=$(zfs get -H -o value mountpoint $(iocage get -p)/iocage)
# FreeNAS/TrueNAS Running instance version 
RELEASE=$(freebsd-version | sed "s/STABLE/RELEASE/g" | sed "s/-p[0-9]*//")
# Arbitrary selection of an version of the `iocage`
#RELEASE=12.2-RELEASE

#####
#
# Delete old Jail
#
#####
iocage destroy ${JAIL_NAME} --force --recursive

#####
#
# Input/Config Sanity checks
#
#####

# Check that necessary variables were set by nextcloud-config
if [ -z "${JAIL_IP}" ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z "${JAIL_INTERFACES}" ]; then
  echo 'JAIL_INTERFACES not set, defaulting to: vnet0:bridge0'
  JAIL_INTERFACES="vnet0:bridge0"
fi
if [ -z "${DEFAULT_GW_IP}" ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z "${GO_DL_VERSION}" ]; then
  echo 'Configuration error: GO_DL_VERSION must be set'
  exit 1
fi
if [ -z "${TARGET}" ]; then
  echo 'Configuration error: TARGET must be set'
  exit 1
fi
if [ -z "${ARCH}" ]; then
  echo 'Configuration error: ARCH must be set'
  exit 1
fi
if [ -z "${MN_REPO}" ]; then
  echo 'Configuration error: ARCH must be set'
  exit 1
fi

# Extract IP and netmask, sanity check netmask
IP=$(echo ${JAIL_IP} | cut -f1 -d/)
NETMASK=$(echo ${JAIL_IP} | cut -f2 -d/)
if [ "${NETMASK}" = "${IP}" ]
then
  NETMASK="24"
fi
if [ "${NETMASK}" -lt 8 ] || [ "${NETMASK}" -gt 30 ]
then
  NETMASK="24"
fi

#####
#
# Jail Creation
#
#####

# List packages to be auto-installed after jail creation
cat <<__EOF__ >/tmp/pkg.json
	{
  "pkgs":[
  	"nano","bash","gzip","ca_root_nss","git","lang/go"
  ]
}
__EOF__

# Create the jail and install previously listed packages
if ! iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r "${RELEASE}" interfaces="${JAIL_INTERFACES}" ip4_addr="${INTERFACE}|${JAIL_IP}" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}" 
then
	echo "Failed to create jail"
	exit 1
fi
rm /tmp/pkg.json

##
#
# Create user that run the MN process into the jail
#
##
iocage exec "${JAIL_NAME}" "pw user add ${UID} -c ${GID} -u ${UID_GID_ID} -d /nonexistent -s /usr/bin/nologin"

#####
#
# GO Download and Setup
#
#####
USR_LOCAL="/usr/local"
ROOT_PROFILE="/root/.profile"
SHELL="/bin/bash"
OS=`uname`
INCLUDE_JAIL="/mnt/includes"

iocage exec "${JAIL_NAME}" mkdir -p ${INCLUDE_JAIL}
iocage fstab -a "${JAIL_NAME}" "${INCLUDES_PATH}" ${INCLUDE_JAIL} nullfs rw 0 0

if ! iocage restart "${JAIL_NAME}"
then 
    echo "Fail to restart Jail"
    exit 1
fi

#####
#
# MovieNight Download and Setup
#
#####
MN_URL=${MN_REPO}
MN_HOME="/usr/local/movienight"
MN_MAKEFILE="${MN_HOME}"/Makefile.BSD
MN_LOG_FILE=/var/log/movienight.log
BUILD_CMD="make TARGET=freebsd ARCH=amd64 -f ${MN_MAKEFILE} -C ${MN_HOME} -D SHELL=/usr/local/bin/bash"

if ! iocage exec "${JAIL_NAME}" mkdir "${MN_HOME}"
then
	echo "Failed to create download temp dir"
	exit 1
fi
iocage exec "${JAIL_NAME}" cd "${MN_HOME}"
if ! iocage exec "${JAIL_NAME}" git clone "${MN_URL}" "${MN_HOME}"
then
	echo "Failed to download Movie Night"
	exit 1
fi
if ! iocage exec "${JAIL_NAME}" "${BUILD_CMD}"
then
	echo "Failed to make Movie Night"
	exit 1
fi 
if ! iocage exec ${JAIL_NAME} touch ${MN_LOG_FILE}
then 
	echo "Cant create log file"
	exit 1
fi
if ! iocage exec ${JAIL_NAME} chown ${UID}:${GID} ${MN_LOG_FILE} 
then
	echo "Can't chown ${MN_LOG_FILE}"
	exit 1
fi
if ! iocage exec ${JAIL_NAME} chown -R ${UID}:${GID} ${MN_HOME}
then
	echo "Failed to chown ${MN_HOME}"
	exit 1
fi 

# Copy pre-written config files
iocage exec "${JAIL_NAME}" cp ${INCLUDE_JAIL}/movienight /usr/local/etc/rc.d/
iocage exec "${JAIL_NAME}" chmod +x /usr/local/etc/rc.d/movienight
iocage exec "${JAIL_NAME}" sysrc movienight_enable=YES

iocage restart "${JAIL_NAME}"

# Don't need /mnt/includes any more, so unmount it
iocage fstab -r "${JAIL_NAME}" "${INCLUDES_PATH}" ${INCLUDE_JAIL} nullfs rw 0 0
iocage exec "${JAIL_NAME}" rmdir ${INCLUDE_JAIL}

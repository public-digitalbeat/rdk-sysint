#!/bin/busybox sh

. /etc/include.properties
. /etc/device.properties

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     . /lib/rdk/commonUtils.sh
fi

if [ "$DEVICE_TYPE" = "mediaclient" ]; then
     . /lib/rdk/utils.sh
fi

if [ -f /etc/mount-utils/getConfigFile.sh ]; then
      mkdir -p /tmp/.dropbear
      . /etc/mount-utils/getConfigFile.sh
fi

WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"

if [ -f /tmp/SSH.pid ]; then
   if [ -d /proc/`cat /tmp/SSH.pid` ]; then
      echo "An instance of startSSH.sh is already running !!! Exiting !!!"
      exit 0
   fi
fi

echo $$ > /tmp/SSH.pid

if [ ! -f /etc/sshbanner.txt ]; then
    echo "Simple dropbear SSH Service. Welcome to $HOSTNAME..." > /etc/sshbanner.txt
fi

if [ -e /sbin/dropbear ] || [ -e /usr/sbin/dropbear ] ; then
    if [ ! -e /etc/dropbear/dropbear_rsa_host_key ]; then
        mkdir -p /etc/dropbear
        dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
        dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
   fi
   IP_ADDRESS_PARAM="-p 22"
fi

exit 0


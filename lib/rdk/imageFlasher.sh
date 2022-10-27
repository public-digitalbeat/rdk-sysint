#!/bin/sh

. /etc/device.properties

# input arguments
PROTO=$1
CLOUD_LOCATION=$2
DOWNLOAD_LOCATION=$3
UPGRADE_FILE=$4
REBOOT_FLAG=$5
PDRI_UPGRADE=$6

if [ ! $PROTO ];then echo "Missing the upgrade proto..!"; exit -2;fi
if [ ! $CLOUD_LOCATION ];then echo "Missing the cloud image location..!"; exit -2;fi
if [ ! $DOWNLOAD_LOCATION ];then echo "Missing the local download image location..!"; exit -2;fi
if [ ! $UPGRADE_FILE ];then echo "Missing the image file..!"; exit -2;fi
if [ ! $REBOOT_FLAG ] && [  "$DEVICE_TYPE" != "mediaclient" ];then echo "Missing the reboot flag..!"; exit -2;fi

ret=1

if [ "$SOC" == "Amlogic" ]; then
    if [ -f /usr/bin/mfrUtil ];then
        # Flashing the image
        echo "/usr/bin/mfrUtil -u $DOWNLOAD_LOCATION/$UPGRADE_FILE"
        /usr/bin/mfrUtil -u $DOWNLOAD_LOCATION/$UPGRADE_FILE
        ret=$?
    else
       echo "mfrUtil Utility is missing"
        ret=1
    fi
    exit $ret
fi

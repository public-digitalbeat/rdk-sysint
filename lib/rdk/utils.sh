#!/bin/sh

export PATH=$PATH:/sbin
# Scripts having common utility functions
. /etc/common.properties
. /etc/include.properties
. /etc/device.properties

# Secure bootlog path
mkdir -p $SECURE_PATH
mkdir -p $SECURE_BOOTLOG_PATH

# HP40A-686: Once RFC configuration on VA related decision completes; update accordingly.
mkdir -p $SECURE_RFC_PATH

#Adding the Xconf cloudurl for firmware upgrade
echo "$CLOUDURL" > /opt/swupdate.conf

#temporary change to make xconf firmware download work(need to remove this work around once we get proper changes for the same)
touch /etc/authService.conf

# HP40A-943: Force aamp to use westerossink until respective changes become available in stable2.
if [ ! -f /opt/aamp.cfg ]; then
    echo "useWesterosSink=1" > /opt/aamp.cfg
fi

Timestamp()
{
            date +"%Y-%m-%d %T"
}
# Last modified time
getLastModifiedTimeOfFile()
{
    if [ -f $1 ] ; then
        stat -c '%y' $1 | cut -d '.' -f1 | sed -e 's/[ :]/-/g'
    fi
}
# Set the name of the log file using SHA1
setLogFile()
{
    fileName=`basename $6`
    echo $1"_mac"$2"_dat"$3"_box"$4"_mod"$5"_"$fileName
}
# Returns the specified MAC as a decimal integer string
# Argument must be an integer between 0 and 3, inclusive.
#    0 - Ethernet MAC
#    1 - Settop MAC
#    2 - WiFi MAC
#    3 - Bluetooth MAC
getRawMac()
{
        if [ -f /sys/class/net/$ETHERNET_INTERFACE/address ]; then
                oper=$(cat /sys/class/net/$ETHERNET_INTERFACE/address|tr [a-z] [A-Z]);
                echo $oper;
        else
                echo "0:0:0:0:0:0"
        fi
}
# Get the MAC address of the machine
getMacAddressOnly()
{
   #This needs to be revisited. Currently just returning ethernet
   getRawMac
}
# Get the SHA1 checksum
getSHA1()
{
    sha1sum $1 | cut -f1 -d" "
}
# IP address of the machine
getIPAddress()
{
    echo "Inside get ip address" >> $LOG_PATH/dcmscript.log
    if [ -f /sys/class/net/$WIFI_INTERFACE/operstate ]; then
        oprstate=`cat /sys/class/net/$WIFI_INTERFACE/operstate`;
        if [ "x$oprstate" == "xup" ] ; then
            interface=`getWiFiInterface`
        else
            interface=`getMoCAInterface`
        fi;
    fi

    if [ -f /tmp/estb_ipv6 ]; then
        ifconfig -a $interface | grep inet6 | tr -s " " | grep -v Link | cut -d " " -f4 | cut -d "/" -f1
    else
        ifconfig -a $interface | grep inet | grep -v inet6 | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g'
    fi
}
processCheck()
{
   ps -ef | grep $1 | grep -v grep > /dev/null 2>/dev/null
   if [ $? -ne 0 ]; then
         echo "1"
   else
         echo "0"
   fi
}
getMacAddress()
{
   getRawMac
}
getEstbMacAddress()
{
   getRawMac
}
getWiFiMacAddress()
{
         if [ -f /sys/class/net/$WIFI_INTERFACE/address ]; then
                oper=$(cat /sys/class/net/$WIFI_INTERFACE/address|tr [a-z] [A-Z]);
                echo $oper;
        else
                echo "0:0:0:0:0:0"
        fi

}
getDeviceBluetoothMac()
{
    bluetooth_mac="00:00:00:00:00:00"
    hash hcitool >/dev/null 2>&1
    if [ $? -eq 0 ] ; then
        bluetooth_mac=`hcitool dev |grep hci |cut -d$'\t' -f3|tr -d '\r\n'`
    fi
    echo $bluetooth_mac
}
getRf4ceMacAddress()
{
 echo "0:0:0:0:0:0"
}
getEstbMacAddressWithoutColon()
{
    echo `getRawMac | sed -e 's/://g'`
}
rebootFunc()
{
    sync
    if [[ $1 == "" ]] && [[ $2 == "" ]]; then
       process=`cat /proc/$PPID/cmdline`
       reason="Rebooting by calling rebootFunc of utils.sh script..."
    else
       process=$1
       reason=$2
    fi
    /rebootNow.sh -s $process -o $reason
}
# Return system uptime in seconds
Uptime()
{
     cat /proc/uptime | awk '{ split($1,a,".");  print a[1]; }'
}
getMoCAInterface()
{
        interface=$MOCA_INTERFACE
        if [ ! "$interface" ]; then
                interface=eth0
        fi
        echo $interface
}
getWiFiInterface()
{
        interface=$WIFI_INTERFACE
        if [ ! "$interface" ]; then
                interface=wlan0
        fi
        echo $interface
}
getModel()
{
  echo "$MODEL_NUM"
}
checkWiFiModule()
{
    #Check the status of ethernet, if it is up it takes precedence over wifi.
    #If ethernet link is down (wait and retry for 5 seconds), start in wifi mode by default

    x=0
    status=1
    ethernet_interface=`getMoCAInterface`
    if [ -f /sys/class/net/$WIFI_INTERFACE/operstate ]; then
        wifistate=`cat /sys/class/net/$WIFI_INTERFACE/operstate`
        if [ "x$wifistate" == "xup" ]; then
            echo "`/bin/timestamp`::checkWiFiModule()::Already started in wifi mode" >> /opt/logs/ipSetupLogs.txt
            status=1
        fi
    else
        ifconfig $ethernet_interface up
        while [ $x -ne 5 ]
        do
            x=`expr $x + 1`
            ethernet_state=`cat /sys/class/net/$ethernet_interface/operstate`
            echo "`/bin/timestamp`::checkWiFiModule()::ethernet status is : $ethernet_state" >> /opt/logs/ipSetupLogs.txt
            if [ "$ethernet_state" == "up" ] ; then
                x=5
                status=0
                echo "`/bin/timestamp`::checkWiFiModule()::Starting in ethernet mode" >> /opt/logs/ipSetupLogs.txt
            else
                sleep 1
            fi
        done
    fi

    echo "`/bin/timestamp`::checkWiFiModule() status is : $status" >> /opt/logs/ipSetupLogs.txt
    echo $status
}
checkAutoIpDefaultRoute()
{
    gwIpv6Moca=`ip -6 route | grep $MOCA_INTERFACE | awk '/default/ { print $3 }'`
    if [ ! -z "$gwIpv6Moca" ]; then
        echo "`/bin/timestamp` $gwIpv6Moca auto ip route is there" >> /opt/logs/gwSetupLogs.txt
        return 1
    else
        gwIpv4Moca=`route -n | grep 'UG[ \t]' | grep $MOCA_INTERFACE | awk '{print $2}' | grep 169.254`
        if [ ! -z "$gwIpv4Moca" ]; then
            echo "`/bin/timestamp` $gwIpv4Moca auto ip route is there" >> /opt/logs/gwSetupLogs.txt
            return 1
        else
            if [ ! -z "$WIFI_INTERFACE" ]; then
                gwIpv6Wifi=`ip -6 route | grep $WIFI_INTERFACE | awk '/default/ { print $3 }'`
            else
                echo "`/bin/timestamp` no wifi interface to continue checking for auto ip route" >> /opt/logs/gwSetupLogs.txt
                return 0
            fi
            if [ !  -z "$gwIpv6Wifi" ]; then
                echo "`/bin/timestamp` $gwIpv6Wifi auto ip route is there" >> /opt/logs/gwSetupLogs.txt
                return 1
            else
                gwIpv4Wifi=`route -n | grep 'UG[ \t]' | grep $WIFI_INTERFACE | awk '{print $2}' | grep 169.254`
                if [ !  -z "$gwIpv4Wifi" ]; then
                    echo "`/bin/timestamp` $gwIpv6Wifi auto ip route is there" >> /opt/logs/gwSetupLogs.txt
                    return 1
                else
                    echo "`/bin/timestamp` auto ip route is not there " >> /opt/logs/gwSetupLogs.txt
                    return 0
                fi
            fi
        fi
    fi
}

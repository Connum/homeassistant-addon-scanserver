#!/usr/bin/with-contenv bashio

ulimit -n 1048576

echo "copying defaults and scan_pre from /opt/sane-scan-pdf to /config/sane-scan-pdf if non-existing"
mkdir -p "/config/sane-scan-pdf"
if [ ! -f "/config/sane-scan-pdf/defaults" ]; then
    mv /opt/sane-scan-pdf/defaults /config/sane-scan-pdf/defaults
else
    rm /opt/sane-scan-pdf/defaults
fi
ln -s /config/sane-scan-pdf/defaults /opt/sane-scan-pdf/defaults

if [ ! -f "/config/sane-scan-pdf/scan_pre" ]; then
    mv /opt/sane-scan-pdf/scan_pre /config/sane-scan-pdf/scan_pre
else
    rm /opt/sane-scan-pdf/scan_pre
fi
ln -s /config/sane-scan-pdf/scan_pre /opt/sane-scan-pdf/scan_pre

chmod a+x /config/sane-scan-pdf/defaults /config/sane-scan-pdf/scan_pre

# custom logger to make default scripts work without needing to install logging packages
# echo '#!/bin/bash
# TAG=""; while getopts "t:" opt; do 
#   case $opt in 
#     t) TAG="$OPTARG" ;; 
#   esac 
# done; shift $((OPTIND-1)); 
# if [ -n "$TAG" ]; then 
#   echo "[$TAG] $@"; 
# else 
#   echo "$@"; 
# fi' > /usr/bin/logger && chmod +x /usr/bin/logger

# copy custom component if it doesn't already exist
if [ ! -d "/homeassistant/custom_components/scan_server_integration" ]; then
  echo "Custom integration not found, copying..."
    mkdir -p /homeassistant/custom_components/scan_server_integration
    cp -r /custom_components/scan_server_integration/* /homeassistant/custom_components/scan_server_integration/
fi
# @TODO check component version and update if necessary

CONFIG_PATH_DLL="/config/dll.conf"
SCANBD_CONF_DLL="/etc/scanbd/dll.conf"

echo "Checking for $CONFIG_PATH_DLL"
# Check if /config/dll.conf exists
if [ ! -f "$CONFIG_PATH_DLL" ]; then
    mv "$SCANBD_CONF_DLL" "$CONFIG_PATH_DLL"
    echo "created default config"
else
  echo "use existing config"
fi

# Ensure /etc/scanbd/dll.conf is a symlink to /config/dll.conf
rm -f "$SCANBD_CONF_DLL"
ln -s "$CONFIG_PATH_DLL" "$SCANBD_CONF_DLL"



CONFIG_PATH_SANED="/config/saned.conf"
SANED_CONF="/etc/sane.d/saned.conf"

echo "Checking for $CONFIG_PATH_SANED"
# Check if /config/saned.conf exists
if [ ! -f "$CONFIG_PATH_SANED" ]; then
    # update /config/saned.conf
    echo -e "\n# Allow all private network ranges\nlocalhost\n192.168.0.0/16\n10.0.0.0/8\n172.16.0.0/12" | tee -a $SANED_CONF
    # Otherwise, back up and move the existing config
    mv "$SANED_CONF" "$CONFIG_PATH_SANED"

    echo "created default config"
else
  echo "use existing config"
fi

# Ensure /etc/sane.d/saned.conf is a symlink to /config/saned.conf
rm -f "$SANED_CONF"
ln -s "$CONFIG_PATH_SANED" "$SANED_CONF"


CONFIG_PATH_SCANBD="/config/scanbd.conf"
SCANBD_CONF="/etc/scanbd/scanbd.conf"

echo "Checking for $CONFIG_PATH_SCANBD"
# Check if /config/scanbd.conf exists
if [ ! -f "$CONFIG_PATH_SCANBD" ]; then
    # Otherwise, back up and move the existing config
    mv "$SCANBD_CONF" "$CONFIG_PATH_SCANBD"

    echo "created default config"
else
  echo "use existing config"
fi

# Ensure /etc/scanbd/scanbd.conf is a symlink to /config/scanbd.conf
rm -f "$SCANBD_CONF"
ln -s "$CONFIG_PATH_SCANBD" "$SCANBD_CONF"


if [ ! -d "/config/scripts" ]; then
    echo "creating default scanbd scripts in /config/scripts"
    
    # Move the folder and its contents
    mv /usr/share/scanbd/scripts /config/
else
    echo "Using existing scanbd scripts from /config/scripts"
fi

ln -sfn /config/scripts /etc/scanbd/scripts

echo "Starting dbus-daemon..."
dbus-daemon --system

echo "Starting inetd..."
service openbsd-inetd start

#echo "Starting saned..."
#export SANE_CONFIG_DIR=/etc/sane.d/
#saned -elD --user=root -d7

#echo "Starting scanbd..."
export SANE_CONFIG_DIR=/etc/scanbd/
scanbd -d2 -f -c /etc/scanbd/scanbd.conf 

#echo "Detected devices:"
#scanimage -L

#sane-find-scanner | sed -En '
#/^found possible / {
#  s/^found possible USB scanner \(vendor=0x[0-9a-f]+ \[([^]]+)\], product=0x[0-9a-f]+ \[([^]]+)\]\) at (.*)/  - vendor: "\1"\n    product: "\2"\n    address: "\3"/p
#}
#' | sed '1i scanners:' > /config/devices.yaml
#cat /config/devices.yaml

tail -f /dev/null

#!/usr/bin/with-contenv bashio

ulimit -n 1048576

chmod a+x /usr/bin/get_scan_filename

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
    # Otherwise, move the existing config
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
    # Otherwise, move the existing config
    mv "$SCANBD_CONF" "$CONFIG_PATH_SCANBD"
    sed -i 's/"test\.script"/"scan.script"/g' "$CONFIG_PATH_SCANBD"

    echo "created default config"
else
  echo "use existing config"
fi

# Ensure /etc/scanbd/scanbd.conf is a symlink to /config/scanbd.conf
rm -f "$SCANBD_CONF"
ln -s "$CONFIG_PATH_SCANBD" "$SCANBD_CONF"

SCRIPT_PATH="/config/scripts"
if [ ! -d "$SCRIPT_PATH" ]; then
    echo "creating default scanbd scripts in $SCRIPT_PATH"
    
    # Move the folder and its contents
    mv /usr/share/scanbd/scripts /config/
else
    echo "Using existing scanbd scripts from $SCRIPT_PATH"
fi

SCAN_SCRIPT="$SCRIPT_PATH/scan.script"
SCAN_SCRIPT_SOURCE="src/scripts/scan.script"
if [ ! -f "$SCAN_SCRIPT" ]; then
    mv "$SCAN_SCRIPT_SOURCE" "$SCRIPT_PATH"
fi

chmod a+x "$SCRIPT_PATH/$(basename "$SCAN_SCRIPT")"

ln -sfn /config/scripts /etc/scanbd/scripts

echo "Starting dbus-daemon..."
dbus-daemon --system

echo "Starting inetd..."
service openbsd-inetd start

OPTIONS_FILE="/data/options.json"

# Function to process options
reload_options() {
    NETSHARE_SERVER=$(jq -r '.netshare_server' $OPTIONS_FILE)
    NETSHARE_USERNAME=$(jq -r '.netshare_username' $OPTIONS_FILE)
    NETSHARE_PASSWORD=$(jq -r '.netshare_password' $OPTIONS_FILE)
    NETSHARE_PATH=$(jq -r '.netshare_path' $OPTIONS_FILE)
    NETSHARE_PATH="${NETSHARE_PATH##[\\/]}" # remove leading slashes

    # delete previous mount, ignoring if it doesn't exist
    curl -sSL -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/mounts/scanserver -X DELETE > /dev/null

    if [[ -n "$NETSHARE_SERVER" ]]; then
        JSON_DATA=$(jq -n \
            --arg name "scanserver" \
            --arg usage "share" \
            --arg type "cifs" \
            --arg server "$NETSHARE_SERVER" \
            --arg share "$NETSHARE_PATH" \
            --arg username "$NETSHARE_USERNAME" \
            --arg password "$NETSHARE_PASSWORD" \
            --argjson read_only false \
            '{
                name: $name,
                usage: $usage,
                type: $type,
                server: $server,
                share: $share,
                username: $username,
                password: $password,
                read_only: $read_only
            }')

        # Send the JSON data in the POST request
        RESPONSE=$(curl -sSL -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
            -H "Content-Type: application/json" \
            -X POST -d "$JSON_DATA" http://supervisor/mounts)
        RESPONSE_RESULT=$(jq -r ".result" <<< "$RESPONSE")
        
        if [[ $RESPONSE_RESULT != 'ok' ]] then
            curl -X POST \
                -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
                -H "Content-Type: application/json" \
                -d '{
                    "message": "The network share could not be mounted, please check the host, user, password and path in the add-on options.",
                    "title": "Scan Server Error: Could not mount network share",
                    "notification_id": "scan_server_error"
                }' \
                http://supervisor/core/api/services/persistent_notification/create
        else
            echo "Network share $NETSHARE_SERVER/$NETSHARE_PATH mounted to /share/scanserver"
        fi
        
    fi
}

# Initial load of options
reload_options

# Listen for SIGHUP to trigger reloads
trap reload_options SIGHUP

echo "Starting scanbd..."
export SANE_CONFIG_DIR=/etc/scanbd/
scanbd -d2 -f -c /etc/scanbd/scanbd.conf 

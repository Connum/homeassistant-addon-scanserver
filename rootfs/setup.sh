INETD_CONFIG="/etc/inetd.conf"
SERVICES_CONFIG="/etc/services"
DBUS_CONFIG="/etc/dbus-1/system.d/scanbd_dbus.conf"

echo "configuring $INETD_CONFIG"
SANE_PORT_CONFIG="sane-port       stream  tcp     nowait  root    /usr/sbin/scanbm scanbm"
# Replace the line starting with 'sane-port' or append if not found
if grep -q "^sane-port" "$INETD_CONFIG"; then
    sed -i "s|^sane-port.*|$SANE_PORT_CONFIG|" "$INETD_CONFIG"
    echo "Updated sane-port entry in $INETD_CONFIG."
else
    echo "$SANE_PORT_CONFIG" >> "$INETD_CONFIG"
    echo "Added sane-port entry to $INETD_CONFIG."
fi

echo "configuring $SERVICES_CONFIG"
echo "sane-port 6566/tcp # SANE network scanner daemon" >> "$SERVICES_CONFIG"

echo "configuring $DBUS_CONFIG"
# Replace user="saned" with user="root"
sed -i 's/user="saned"/user="root"/g' "$DBUS_CONFIG"
echo "changed dbus user from saned to root" 

echo "set scanbd config..."

# Use sed to replace 'user = saned' with 'user = root'
sed -i 's/^\([[:space:]]*user[[:space:]]*=[[:space:]]*\)saned/\1root/' "/etc/scanbd/scanbd.conf"

echo "set /etc/default/saned"
sed -i 's/^\([[:space:]]*RUN_AS_USER[[:space:]]*=[[:space:]]*\)saned/\1root/' "/etc/default/saned"

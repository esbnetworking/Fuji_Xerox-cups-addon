#!/usr/bin/with-contenv bash

# 1. Create directories in HA share
mkdir -p /share/cups/cache /share/cups/logs /share/cups/state /share/cups/config/ppd /share/cups/config/ssl
chown -R root:lp /share/cups
chmod -R 775 /share/cups

# Clean up stale locks/sockets from previous runs
rm -f /run/cups/cupsd.pid /run/cups/cups.sock \
      /run/dbus/pid /run/dbus/system_bus_socket \
      /run/avahi-daemon/pid /run/avahi-daemon/socket \
      /share/cups/state/cupsd.pid 2>/dev/null || true

# 2. Write cupsd.conf if needed (or write fresh config)
cat > /share/cups/config/cupsd.conf << 'EOL'
ServerAlias *
Port 631
Listen /run/cups/cups.sock

WebInterface Yes
DefaultAuthType None
DefaultEncryption Never
Browsing Yes
BrowseLocalProtocols dnssd
DefaultShared Yes
JobSheets none,none
PreserveJobHistory Yes
PreserveJobFiles No
MaxJobTime 10800

ErrorPolicy retry-job

<Location />
  Order allow,deny
  Allow localhost
  Allow @LOCAL
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
  Allow fe80::/10
  Allow fd00::/8
</Location>

<Location /admin>
  Order allow,deny
  Allow localhost
  Allow @LOCAL
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
  Allow fe80::/10
  Allow fd00::/8
</Location>

<Location /admin/conf>
  Order allow,deny
  Allow localhost
  Allow @LOCAL
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
  Allow fe80::/10
  Allow fd00::/8
</Location>

<Location /jobs>
  Order allow,deny
  Allow localhost
  Allow @LOCAL
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
  Allow fe80::/10
  Allow fd00::/8
</Location>

<Policy default>
  JobPrivateAccess all
  JobPrivateValues none
  SubscriptionPrivateAccess all
  SubscriptionPrivateValues none

  <Limit Create-Job Print-Job Print-URI Validate-Job>
    Order allow,deny
    Allow localhost
    Allow @LOCAL
    Allow 10.0.0.0/8
    Allow 172.16.0.0/12
    Allow 192.168.0.0/16
    Allow fe80::/10
    Allow fd00::/8
  </Limit>

  <Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Jobs Set-Job-Attributes Create-Job-Subscription Renew-Subscription Cancel-Subscription Get-Notifications Reprocess-Job Cancel-Job Cancel-Jobs Cancel-Current-Job Cancel-My-Jobs Suspend-Current-Job Resume-Job Close-Job CUPS-Move-Job CUPS-Get-Document Pause-Printer Resume-Printer Enable-Printer Disable-Printer Pause-Printer-After-Current-Job Hold-New-Jobs Release-Held-New-Jobs CUPS-Accept-Jobs CUPS-Reject-Jobs Promote-Job CUPS-Add-Modify-Printer CUPS-Delete-Printer CUPS-Add-Modify-Class CUPS-Delete-Class CUPS-Set-Default CUPS-Get-Devices>
    AuthType None
    Order allow,deny
    Allow localhost
    Allow @LOCAL
    Allow 10.0.0.0/8
    Allow 172.16.0.0/12
    Allow 192.168.0.0/16
    Allow fe80::/10
    Allow fd00::/8
  </Limit>

  <Limit All>
    AuthType None
    Order allow,deny
    Allow localhost
    Allow @LOCAL
    Allow 10.0.0.0/8
    Allow 172.16.0.0/12
    Allow 192.168.0.0/16
    Allow fe80::/10
    Allow fd00::/8
  </Limit>
</Policy>
EOL

# 3. Symlink /etc/cups to persistent config
if [ -d /etc/cups ] && [ ! -L /etc/cups ]; then
    for item in /etc/cups/*; do
        [ -e "$item" ] || continue
        base="$(basename "$item")"
        case "$base" in
            cupsd.conf|printers.conf|printers.conf.O|ppd|ssl) continue ;;
        esac
        if [ ! -e "/share/cups/config/$base" ]; then
            cp -r "$item" "/share/cups/config/$base"
        fi
    done
    touch /share/cups/config/printers.conf
    rm -rf /etc/cups
    ln -sf /share/cups/config /etc/cups
else
    rm -rf /etc/cups
    ln -sf /share/cups/config /etc/cups
fi

[ ! -f /share/cups/config/printers.conf ] && touch /share/cups/config/printers.conf

# 4. Install user deb if specified
DRIVER_DEB=$(jq -r '.printer_driver_deb // empty' /data/options.json 2>/dev/null)
if [ -n "$DRIVER_DEB" ]; then
    DRIVER_PATH="/share/${DRIVER_DEB}"
    if [ -f "$DRIVER_PATH" ]; then
        EXTRACT_DIR=$(mktemp -d)
        dpkg -x "$DRIVER_PATH" "$EXTRACT_DIR"
        [ -d "${EXTRACT_DIR}/usr/lib/cups/filter" ] && cp -r "${EXTRACT_DIR}/usr/lib/cups/filter/." /usr/lib/cups/filter/ && chmod 755 /usr/lib/cups/filter/*
        [ -d "${EXTRACT_DIR}/usr/lib" ] && find "${EXTRACT_DIR}/usr/lib" -name "*.so*" -exec cp {} /usr/lib/ \;
        [ -d "${EXTRACT_DIR}/usr/share/cups/model" ] && cp -r "${EXTRACT_DIR}/usr/share/cups/model/." /usr/share/cups/model/
        rm -rf "$EXTRACT_DIR"
    fi
fi

echo "Initialization complete."
exit 0

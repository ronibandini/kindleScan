#!/bin/sh
#
# KindleScan 
# Network discovery tool
# Roni Bandini, Nov 2026
# Buenos Aires, Argentina
#
set +m 2>/dev/null

SUBNET="$1"
TIMEOUT="${2:-1}"
CONCURRENCY="${3:-16}"
START="${4:-1}"
END="${5:-254}"

# Settings
OBFUSCATE_MAC=0   # Seteando en 1 hace mask de los ult 4 chars  

CAM_PORTS="80 443 554 8000 8080 8554 8899 37777"
DRIVE_PORTS="445 139 2049 21"
PRINT_PORTS="515 631 9100"
OTHER_PORTS="22 23 53"
WEB_PORTS="80 8080 8000"

detect_subnet() {
    ip=""
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 -o addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | grep -v '^127\.' | head -n1)
    fi
    if [ -z "$ip" ] && command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p' | grep -v '^127\.' | head -n1)
        [ -z "$ip" ] && ip=$(ifconfig 2>/dev/null | sed -n 's/.*inet \([0-9.]*\) .*/\1/p' | grep -v '^127\.' | head -n1)
    fi
    echo "$ip"
}

detect_gateway() {
    gw=""
    if command -v ip >/dev/null 2>&1; then
        gw=$(ip route show default 2>/dev/null | awk '/default/{print $3; exit}')
    fi
    if [ -z "$gw" ] && command -v route >/dev/null 2>&1; then
        gw=$(route -n 2>/dev/null | awk '$1=="0.0.0.0"{print $2; exit}')
    fi
    echo "$gw"
}

detect_dns() {
    [ -r /etc/resolv.conf ] && awk '/^nameserver/{print $2}' /etc/resolv.conf 2>/dev/null | tr '\n' ' '
}

get_storage_info() {
    # Extract available/free blocks from busybox df for root or /mnt/us
    DF_LINE=$(df 2>/dev/null | grep -E '/mnt/us$| /$' | head -n1)
    if [ -n "$DF_LINE" ]; then
        AVAIL=$(echo "$DF_LINE" | awk '{print $4}')
        TOTAL=$(echo "$DF_LINE" | awk '{print $2}')
        USEPCT=$(echo "$DF_LINE" | awk '{print $5}')
        echo "Total: ${TOTAL}K | Free: ${AVAIL}K (${USEPCT} used)"
    else
        df 2>/dev/null | head -n2 | tail -n1
    fi
}

format_mac() {
    MAC="$1"
    [ -z "$MAC" ] && return
    if [ "$OBFUSCATE_MAC" = "1" ]; then
        # Mask last 4 hex chars (e.g., AA:BB:CC:DD:XX:XX)
        echo "$MAC" | sed 's/[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]$/XX:XX/'
    else
        echo "$MAC"
    fi
}

port_open() {
    timeout "$((TIMEOUT + 1))" nc -w "$TIMEOUT" "$1" "$2" </dev/null >/dev/null 2>&1
}

http_info() {
    RESP=$(printf 'GET / HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n' "$1" \
        | timeout "$((TIMEOUT + 1))" nc -w "$TIMEOUT" "$1" "$2" 2>/dev/null \
        | tr -d '\r')
    [ -z "$RESP" ] && return
    echo "$RESP" | head -n1
    echo "$RESP" | grep -i '^Server:' | head -n1
    echo "$RESP" | grep -i '^Location:' | head -n1
}

get_mac() {
    awk -v ip="$1" '$1==ip {print toupper($4)}' /proc/net/arp 2>/dev/null
}

# Ampliar la lista de vendors 
vendor_for_mac() {
    PREFIX=$(echo "$1" | cut -d: -f1-3)
    case "$PREFIX" in
        E4:D5:8B|C8:A7:02|08:54:11|08:A1:89|08:CC:81|24:0F:9B|24:32:AE|24:48:45|2C:A5:9C|40:AC:BF|\
        44:19:B6|44:A6:42|4C:62:DF|4C:BD:8F|4C:F5:DC|58:50:ED|5C:34:5B|68:6D:BC|80:F5:AE|8C:E7:48|\
        A0:FF:0C|A4:14:37|BC:AD:28|C0:51:7E|DC:07:F8|E0:BA:AD|E0:CA:3C|84:9A:40|98:8B:0A|00:BC:99)
            echo "Hikvision" ;;
        08:ED:ED|14:A7:8B|38:AF:29|3C:E3:6B|5C:F5:1A|64:FD:29|74:C9:29|8C:E9:B4|9C:14:63|A0:BD:1D|\
        C0:39:5A|D4:43:0E|E0:50:8B|E4:24:6C|30:DD:AA|FC:B6:9D|90:02:A9|B4:4C:3B|E0:2E:FE|40:7A:A4)
            echo "Dahua" ;;
        08:3A:2F)
            echo "Guangzhou Juan (DVR/NVR OEM)" ;;
        00:30:6E|00:50:8B|00:60:B0|00:68:EB|10:1F:74|10:60:4B|18:A9:05|2C:44:FD|30:24:A9|30:8D:99|\
        3C:D9:2B|40:A8:F0|44:31:92|48:0F:CF|50:65:F3|5C:60:BA|6C:3B:E5|78:48:59|80:C1:6E|84:34:97|\
        98:E7:F4|A0:D3:C1|B0:5A:DA|C4:34:6B|D4:C9:EF|E4:11:5B|F4:CE:46|28:92:4A|6C:0B:5E|70:5A:0F|9C:D2:1E)
            echo "HP Inc" ;;
        00:11:32|90:09:D0)
            echo "Synology" ;;
        24:5E:BE|E8:43:B6)
            echo "QNAP" ;;
        00:0A:EB|00:14:78|00:19:E0|00:1D:0F|00:21:27|00:23:CD|00:25:86|00:27:19|14:CC:20|18:A6:F7|\
        1C:3B:F3|30:B5:C2|34:E8:94|3C:84:6A|50:C7:BF|5C:63:BF|64:70:02|78:A1:06|8C:21:0A|A4:2B:B0|\
        B0:48:7A|C0:25:E9|D8:0D:17|EC:08:6B|F4:F2:6D|60:A4:B7|5C:A6:E6|40:ED:00|A8:6E:84|DC:62:79)
            echo "TP-Link" ;;
        A8:9C:6C|1C:0B:8B|44:D9:E7|D4:89:C1|A4:F8:FF|B4:FB:E4|F4:E2:C6|74:83:C2|68:D7:9A|24:5A:4C|70:A7:41)
            echo "Ubiquiti" ;;
        6C:D1:E5|10:86:F4|28:45:AC|4C:2B:3B|58:B1:8F|60:B0:E8|88:15:66|A4:43:80|B8:3C:20|E4:B1:07|\
        24:DE:EB|34:FF:F3|9C:97:93|B0:7A:DF|D8:20:A2|00:66:4B|04:F9:38|08:19:A6|0C:37:DC|10:47:80|\
        14:A0:F8|18:D6:DD|1C:1D:67|20:08:ED|24:69:A5|28:A6:DB|2C:3A:91|30:87:30|34:29:12|38:47:BC|\
        3C:47:11|40:4D:8E|44:6A:2E|48:46:FB|4C:8B:EF|50:66:E5|54:25:EA|58:60:5F|5C:78:F8|60:E7:01|\
        64:6D:6C|68:A0:3E|6C:14:6E|70:72:3C|74:4D:6D|78:5B:64|7C:94:2A|80:71:7A|84:A8:E4|88:69:3D)
            echo "Huawei" ;;
        00:0E:59|00:15:56|00:19:4B|00:1B:BF|00:1F:95|00:23:48|00:25:69|00:37:B7|00:60:4C|00:78:9E|\
        04:E3:1A|08:3E:5D|0C:AC:8A|10:06:45|10:D7:B0|18:1E:78|18:62:2C|18:6A:81|18:90:D8|20:47:B5|\
        24:20:C7|28:9E:FC|2C:39:96|30:24:78|34:49:5B|34:5D:9E|38:35:FB|3C:58:5D|44:05:3F|48:29:52|\
        50:6F:0C|54:47:CC|58:1D:D8|58:90:43|64:66:24|6C:2E:85|70:0B:01|78:65:59|7C:03:4C|84:1E:A3|\
        90:4D:4A|A0:39:EE|A0:55:1F|A0:7F:8A|A4:08:F5|B0:5B:99|C0:3C:04|CC:33:BB|D0:6D:C9|D8:7D:7F)
            echo "Sagemcom" ;;
        00:01:5C|00:19:C0|00:15:A2|00:1A:1B|00:16:26|00:1C:11|00:15:A3|00:1A:66|00:16:B5|00:1A:AD|\
        00:00:C5|00:03:E0|00:0C:E5|00:0F:9F|00:11:AE|00:12:25|00:12:8A|00:12:C9|00:14:04|00:13:71|\
        00:15:96|00:15:9A|00:15:CE|00:15:CF|00:15:D0|00:17:84|00:17:E2|00:17:EE|00:18:A4|00:18:C0|\
        00:19:5E|00:19:A6|00:1A:DB|00:1A:DE|00:1B:52|00:1B:DD|00:1C:12|00:1D:6B|00:1D:BE|00:1E:46)
            echo "CommScope/ARRIS" ;;
        00:15:EB|28:DB:02|3C:76:25|44:F4:36|00:19:C6|BC:FF:54|00:1E:73|00:22:93|00:26:ED|E4:7E:9A|\
        D0:DD:7C|58:92:04|8C:18:01|2C:B6:C2|48:D6:82|E4:4E:12|04:1D:C7|04:20:84|04:95:73|54:88:D5|\
        08:18:1A|08:3F:BC|08:60:83|08:9A:C7|08:AA:89|08:E6:3B|0C:01:4B|0C:12:62|0C:37:47|0C:72:D9|\
        10:10:81|10:12:D0|10:3C:59|10:D0:AB|14:00:7D|14:09:B4|14:3E:BF|14:60:80|14:6B:9A|14:CA:56|\
        18:13:2D|18:44:E6|18:5E:0B|18:68:6A|18:79:FD|1C:27:04|1C:67:4A|20:08:89|20:10:8A|20:3A:EB)
            echo "ZTE" ;;
        F4:F5:A5|3C:25:D7|00:31:26|F8:5C:4D|00:02:EE|00:11:9F|18:86:AC|40:48:6E|08:9B:B9|B0:D1:D6|\
        08:47:D0|BC:51:5F|60:98:49|90:F0:4C|C4:48:FA)
            echo "Nokia" ;;
        00:11:F5|00:16:E3|00:1B:9E|00:21:63|00:24:D2|00:26:B6|00:90:96|08:33:ED|08:6A:0A|08:B0:55|\
        1C:24:CD|1C:B0:44|24:EC:99|2C:EA:DC|38:88:71|4C:AB:F8|4C:ED:DE|50:5F:B5|74:93:DA|78:29:ED|\
        7C:B7:33|7C:DB:98|80:78:71|88:33:74|88:DE:7C|88:FE:B6|90:D3:CF|94:0F:3B|94:32:51|94:91:7F|\
        94:C2:EF|A0:64:8F|A0:8A:06|A4:97:33|B0:EA:BC|B4:74:9F|B4:82:FE|B4:EE:B4|C0:D9:62|C8:B4:22|\
        CC:37:A9|D4:7B:B0|D8:FB:5E|DC:08:DA|E0:CA:94|E0:CE:C3|E8:39:DF|E8:D1:1B|F4:52:46|F4:69:42)
            echo "Askey" ;;
        *)
            echo "" ;;
    esac
}

# Hints locales, ampliar
router_hint_for_vendor() {
    case "$1" in
        Huawei)    echo "Huawei ONT (HG8245x) - Personal/Claro fiber" ;;
        Sagemcom)  echo "Sagemcom F@st modem/router - Personal/Telecentro" ;;
        CommScope/ARRIS)
                   echo "Technicolor/Arris cable modem - Personal/Telecentro" ;;
        ZTE)       echo "ZTE ONT (F670L/F660) - Claro fiber" ;;
        Nokia)     echo "Nokia G-2425G-B | User: admin/custadmin | Pass: f4st3896 / CalVxePV1!" ;;
        Askey)     echo "Askey/Mitrastar HGU - Movistar fiber" ;;
        "Guangzhou Juan (DVR/NVR OEM)")
                   echo "Guangzhou Juan DVR | User: admin | Pass: (blank)/123456/888888" ;;
        "HP Inc")  echo "HP LaserJet P1102w | User: admin | Pass: (blank)" ;;
        *)         echo "" ;;
    esac
}

LOCAL_IP=$(detect_subnet)

if [ -z "$SUBNET" ]; then
    if [ -z "$LOCAL_IP" ]; then
        echo "Could not autodetect local IP. Run with a subnet argument, e.g.:"
        echo "  $0 192.168.1"
        exit 1
    fi
    SUBNET=$(echo "$LOCAL_IP" | cut -d. -f1-3)
fi

if ! command -v timeout >/dev/null 2>&1; then
    echo "The 'timeout' command is required but was not found. Abortanding (sic)."
    exit 1
fi

if ! command -v flock >/dev/null 2>&1; then
    echo "The 'flock' command is required but was not found. Abortanding (sic)."
    exit 1
fi

GATEWAY=$(detect_gateway)
DNS_SERVERS=$(detect_dns)
HOSTNAME_STR=$(hostname 2>/dev/null)
STORAGE_INFO=$(get_storage_info)

TMPBASE=$(mktemp -d /tmp/kindlescan.XXXXXX 2>/dev/null || mktemp -d)
for f in found cams drives prints vendors; do
    echo 0 > "$TMPBASE/$f"
done
: > "$TMPBASE/router_info"

increment_counter() {
    FILE="$1"
    (
        flock -x 9
        val=$(cat "$FILE" 2>/dev/null)
        [ -z "$val" ] && val=0
        val=$((val + 1))
        echo "$val" > "$FILE"
        echo "$val"
    ) 9>"$FILE.lock"
}

clear 2>/dev/null

# Header
cat <<BANNER
+----------------------------------------+
|              KINDLE SCAN               |
|            by @ronibandini             |
+----------------------------------------+
  Subnet:      $SUBNET.0/24
  Range:       .$START - .$END
  Timeout:     ${TIMEOUT}s  Jobs: $CONCURRENCY
+----------------------------------------+
BANNER

progress_bar() {
    N="$1"
    TOTAL="$2"
    WIDTH=8
    FILLED=$(( N * WIDTH / TOTAL ))
    [ "$FILLED" -gt "$WIDTH" ] && FILLED="$WIDTH"
    PCT=$(( N * 100 / TOTAL ))

    BAR="["
    f=0
    while [ "$f" -lt "$FILLED" ]; do
        BAR="${BAR}#"
        f=$((f + 1))
    done
    while [ "$f" -lt "$WIDTH" ]; do
        BAR="${BAR}-"
        f=$((f + 1))
    done
    BAR="${BAR}]"
    printf '%s %3d%%' "$BAR" "$PCT"
}

scan_host() {
    IP="$1"
    N="$2"
    TOTAL="$3"
    echo "Scanning $IP"

    CAMS=""
    DRIVES=""
    PRINTS=""
    OTHERS=""
    WEBHITS=""

    for PORT in $CAM_PORTS; do
        if port_open "$IP" "$PORT"; then
            CAMS="$CAMS $PORT"
            case " $WEB_PORTS " in *" $PORT "*) WEBHITS="$WEBHITS $PORT" ;; esac
        fi
    done
    for PORT in $DRIVE_PORTS; do
        port_open "$IP" "$PORT" && DRIVES="$DRIVES $PORT"
    done
    for PORT in $PRINT_PORTS; do
        port_open "$IP" "$PORT" && PRINTS="$PRINTS $PORT"
    done
    for PORT in $OTHER_PORTS; do
        port_open "$IP" "$PORT" && OTHERS="$OTHERS $PORT"
    done

    if [ -n "$CAMS$DRIVES$PRINTS$OTHERS" ]; then
        increment_counter "$TMPBASE/found" >/dev/null
        [ -n "$CAMS" ]   && increment_counter "$TMPBASE/cams" >/dev/null
        [ -n "$DRIVES" ] && increment_counter "$TMPBASE/drives" >/dev/null
        [ -n "$PRINTS" ] && increment_counter "$TMPBASE/prints" >/dev/null

        RAW_MAC=$(get_mac "$IP")
        MAC=$(format_mac "$RAW_MAC")
        VENDOR=""
        [ -n "$RAW_MAC" ] && [ "$RAW_MAC" != "00:00:00:00:00:00" ] && VENDOR=$(vendor_for_mac "$RAW_MAC")

        echo
        if [ -n "$VENDOR" ]; then
            echo ">>> FOUND: $IP  [$VENDOR]  MAC: $MAC"
            increment_counter "$TMPBASE/vendors" >/dev/null
            HINT=$(router_hint_for_vendor "$VENDOR")
            [ -n "$HINT" ] && echo "    [!]: $HINT"
            if [ -n "$GATEWAY" ] && [ "$IP" = "$GATEWAY" ]; then
                {
                    flock -x 9
                    echo "$IP|$VENDOR|$MAC|$HINT" > "$TMPBASE/router_info"
                } 9>"$TMPBASE/router_info.lock"
            fi
        elif [ -n "$RAW_MAC" ] && [ "$RAW_MAC" != "00:00:00:00:00:00" ]; then
            echo ">>> FOUND: $IP  MAC: $MAC (unknown)"
        else
            echo ">>> FOUND: $IP"
        fi

        [ -n "$CAMS" ]   && echo "    Cams:    $CAMS"
        [ -n "$DRIVES" ] && echo "    Drives:  $DRIVES"
        [ -n "$PRINTS" ] && echo "    Prints:  $PRINTS"
        [ -n "$OTHERS" ] && echo "    Others:  $OTHERS"

        for PORT in $WEBHITS; do
            INFO=$(http_info "$IP" "$PORT")
            if [ -n "$INFO" ]; then
                echo "    --- HTTP ($PORT) ---"
                echo "$INFO" | sed 's/^/    /'
            else
                echo "    HTTP ($PORT):   (no response)"
            fi
        done
        echo
    fi
}

TOTAL=$((END - START + 1))
JOBS=0
N=0
i="$START"
START_TIME=$(date +%s 2>/dev/null)
while [ "$i" -le "$END" ]; do
    IP="$SUBNET.$i"
    N=$((N + 1))
    scan_host "$IP" "$N" "$TOTAL" &
    JOBS=$((JOBS + 1))
    if [ "$JOBS" -ge "$CONCURRENCY" ]; then
        wait
        JOBS=0
        BAR=$(progress_bar "$N" "$TOTAL")
        echo "-- Progress: $BAR ($N/$TOTAL) --"
    fi
    i=$((i + 1))
done
if [ "$JOBS" -gt 0 ]; then
    wait
    BAR=$(progress_bar "$N" "$TOTAL")
    echo "-- Progress: $BAR ($N/$TOTAL) --"
fi
END_TIME=$(date +%s 2>/dev/null)

FOUND_COUNT=$(cat "$TMPBASE/found" 2>/dev/null)
CAM_COUNT=$(cat "$TMPBASE/cams" 2>/dev/null)
DRIVE_COUNT=$(cat "$TMPBASE/drives" 2>/dev/null)
PRINT_COUNT=$(cat "$TMPBASE/prints" 2>/dev/null)
VENDOR_COUNT=$(cat "$TMPBASE/vendors" 2>/dev/null)
ROUTER_LINE=$(cat "$TMPBASE/router_info" 2>/dev/null)

echo
echo "+----------------------------------------+"
echo "|             SCAN SUMMARY               |"
echo "+----------------------------------------+"
echo "  Scanned:       $TOTAL"
echo "  Found:         $FOUND_COUNT"
echo "  Cams:          $CAM_COUNT"
echo "  Drives:        $DRIVE_COUNT"
echo "  Printers:      $PRINT_COUNT"
echo "  Identified:    $VENDOR_COUNT"
if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
    ELAPSED=$((END_TIME - START_TIME))
    echo "  Time:          ${ELAPSED}s"
fi
echo "+----------------------------------------+"
echo "|            KINDLE HOST INFO            |"
echo "+----------------------------------------+"
[ -n "$HOSTNAME_STR" ] && echo "  Hostname:      $HOSTNAME_STR"
[ -n "$LOCAL_IP" ]     && echo "  IP:            $LOCAL_IP"
[ -n "$GATEWAY" ]      && echo "  Gateway:       $GATEWAY" || echo "  Gateway:       (none)"
[ -n "$DNS_SERVERS" ]  && echo "  DNS:           $DNS_SERVERS"
[ -n "$STORAGE_INFO" ] && echo "  Storage:       $STORAGE_INFO"
if [ -n "$ROUTER_LINE" ]; then
    R_VENDOR=$(echo "$ROUTER_LINE" | cut -d'|' -f2)
    R_MAC=$(echo "$ROUTER_LINE" | cut -d'|' -f3)
    R_HINT=$(echo "$ROUTER_LINE" | cut -d'|' -f4)
    echo "  Router:        [$R_VENDOR] $R_MAC"
    [ -n "$R_HINT" ] && echo "                 $R_HINT"
elif [ -n "$GATEWAY" ]; then
    echo "  Router:        not in vendor table"
fi
echo "+----------------------------------------+"

rm -rf "$TMPBASE" 2>/dev/null

echo
echo "Scan complete."
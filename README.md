# KindleScan 📱🔍

> Lightweight, zero-dependency local network discovery shell script optimized for jailbroken Amazon Kindle devices 

KindleScan turns jailbroken E-Readers into portable, silent, low-power network discovery tools. Designed specifically for low-resource environments and small eInk screens, it quickly audits subnets for IP cameras, NVR/DVRs, network shares, printers, and ISP gateways—complete with MAC OUI vendor matching and default credential hints for targeted devices.

---

## 📸 Key Features

- **Built for Kindle (BusyBox `ash`):** Runs natively without Python, Nmap, or heavy dependencies—only basic tools like `nc` (netcat), `awk`, `sed`, and `timeout`.
- **eInk Display Optimized:** Fixed 40-character column layouts to prevent word wrapping on narrow terminal viewers (e.g., Kterm).
- **CCTV & Media Device Detection:** Targets common IP camera, RTSP, DVR/NVR, NAS, and web admin panel ports.
- **MAC Vendor Matching & Hints:** Recognizes camera brands, printer models, and ISP-branded routers, printing actionable default credential hints where relevant.
- **Privacy Mode (MAC Masking):** Toggleable setting (`OBFUSCATE_MAC=1`) to automatically obfuscate the last 4 characters of MAC addresses in output/screenshots.
- **Parallel Scanning:** Configurable concurrency batching using process isolation and safe atomic counters (`flock`).
- **Host Diagnostics:** Displays local Kindle system statistics, available storage space, gateway, and DNS info.

---

## ⚡ Quick Start

### 1. Download & Prepare
Transfer `kindlescan.sh` to your Kindle via SSH or USB storage (`/mnt/us/`):

```bash
chmod +x kindlescan.sh
```

### 2. Usage Syntax

```bash
./kindlescan.sh [SUBNET] [TIMEOUT] [CONCURRENCY] [START] [END]
```

| Parameter | Description | Default |
| :--- | :--- | :--- |
| `SUBNET` | Network prefix (e.g., `192.168.1`) | Auto-detected |
| `TIMEOUT` | TCP connection timeout in seconds | `1` |
| `CONCURRENCY` | Parallel processes per batch | `16` |
| `START` | Starting host IP suffix | `1` |
| `END` | Ending host IP suffix | `254` |

### 3. Examples

```bash
# Auto-detect subnet and run a full scan:
./kindlescan.sh

# Scan 192.168.1.0/24 with 1s timeout and 16 parallel threads:
./kindlescan.sh 192.168.1 1 16

# Quick probe of range .1 to .20:
./kindlescan.sh 192.168.1 1 16 1 20
```

---

## 🔓 Kindle Jailbreaking Overview

To execute custom shell scripts like `KindleScan`, your Amazon Kindle must be jailbroken and running custom terminal software (such as **Kterm**).

> **Disclaimer:** Jailbreaking alters your Kindle's system software. Proceed carefully and verify your device model and firmware version before attempting.

### Supported Firmware & Methods
Jailbreaking methods depend strictly on your firmware version. Modern Kindle Jailbreaks include:

- **LanguageBreak:** Works on firmware `5.13.7` to `5.16.2.1.1` across most modern Kindle hardware.
- **WinterBreak:** Works on newer firmware up to `5.16.2.1.1`.
- **WatchThis:** Factory software rollback method for older builds.

For step-by-step instructions, hardware guides, and safety checks, refer to the official [KindleModding Guide](https://kindlemodding.org/jailbreaking/).

### Basic Jailbreak Workflow

1. **Check Firmware Version:** Go to `Settings > Device Options > Device Info` on your Kindle.
2. **Prevent Auto-Updates:** Put your device in Airplane Mode immediately to prevent automatic Amazon updates from patching jailbreak entry points.
3. **Apply Jailbreak:** Follow the exact procedure for your specific firmware model at [kindlemodding.org](https://kindlemodding.org/jailbreaking/).
4. **Install KUAL & Kterm:** Install **KUAL** (Kindle Unified Application Launcher) and **Kterm** (Kindle Terminal) to run custom shell tools.

---

## ⚙️ Configuration & Customization

Open `kindlescan.sh` in any text editor to modify the top configuration flags:

```sh
# Toggle MAC masking (1 = ON, 0 = OFF)
OBFUSCATE_MAC=1

# Scan port targets
CAM_PORTS="80 443 554 8000 8080 8554 8899 37777"
DRIVE_PORTS="445 139 2049 21"
PRINT_PORTS="515 631 9100"
```

---

## 📄 Output Sample

```text
+----------------------------------------+
|              KINDLE SCAN               |
|            by @ronibandini             |
+----------------------------------------+
  Subnet:      192.168.1.0/24
  Range:       .1 - .254
  Timeout:     1s  Jobs: 16
+----------------------------------------+

>>> FOUND: 192.168.1.1  [Nokia]  MAC: C4:48:FA:09:XX:XX
    [!]: Nokia G-2425G-B | User: admin/custadmin | Pass: f4st3896 / CalVxePV1!
    Cams:    80
    --- HTTP (80) ---
    HTTP/1.1 200 OK

>>> FOUND: 192.168.1.5  [HP Inc]  MAC: 9C:D2:1E:E8:XX:XX
    [!]: HP LaserJet P1102w | User: admin | Pass: (blank)
    Cams:    80 8080
    Prints:  515 631 9100

+----------------------------------------+
|             SCAN SUMMARY               |
+----------------------------------------+
  Scanned:       254
  Found:         2
  Cams:          2
  Drives:        0
  Printers:      1
  Identified:    2
  Time:          18s
+----------------------------------------+
|            KINDLE HOST INFO            |
+----------------------------------------+
  IP:            192.168.1.42
  Gateway:       192.168.1.1
  Storage:       Total: 3042120K | Free: 1845200K (39% used)
+----------------------------------------+
```

---

## 📜 License

Created by **[@ronibandini](https://github.com/ronibandini)** under the GPL License. Feel free to modify, extend, and share!

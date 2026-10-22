# Add an ESP32-H2 Thread radio to a Silvercrest TYGWZ1

**README v1 — working draft — 21 October 2026**

This guide adds a separate Thread radio to a Lidl Silvercrest TYGWZ1 / RTL8196E running jnilo1's Open Linux Firmware.  
The existing EFR32 provides Zigbee on TCP **8888**.  
  
An ESP32-H2 running OpenThread RCP firmware uses the freed console UART **ttyS0**, exposed on TCP **8889**.  
Home Assistant runs OTBR.
  
Follow the upstream documentation for standard installation, radio flashing, building and upgrades. This README focuses on the additional changes and their order.
  
The original target is project release **v4.7.0**, not Linux kernel version 4.7.0. Record the release and commit actually used. Release-specific build and flash commands have not been verified in this draft; links to main may change.  
  
## 1. Prepare an Ubuntu machine or a temporary VM

- Ubuntu matching the version supported by the upstream build instructions for the selected revision (I am running Ubuntu Server 26.04).  
- At least 8 GB RAM.  
- Enough disk space to hold all the Build Files, at least 30 GB.  
- Network adapter on the same IP subnet as the Silvercrest gateway, with an x.x.x.6/24 unused for temporary bootloader/TFTP address.
- Disk-backed temporary build storage as described below; a small RAM-backed /tmp is insufficient for this setup.


If you use the TTL adapter from inside the VM, pass the USB adapter through to the guest and verify serial access before continuing.

### Check the actual root filesystem size

~~~sh
lsblk
~~~

If the volume group has unallocated space, extend the root logical volume/filesystem using the appropriate procedure for your layout.


### Check temporary build storage

Before starting the upstream build environment installation, check where temporary files will be stored:

~~~sh
df -h /tmp
sudo mkdir -p /var/tmp/build-tmp
sudo chmod 1777 /var/tmp/build-tmp
sudo mount --bind /var/tmp/build-tmp /tmp
df -h /tmp
~~~

Confirm that /tmp now shows the disk-backed filesystem and sufficient free space.  
The move will not survive a reboot.  


## 2. Install Open Linux Firmware and get Zigbee working

1. Flash the Silvercrest with Open Linux Firmware following the [Getting Started guide](https://github.com/jnilo1/rtl8196e-gateway/blob/main/docs/getting-started.md). Follow its safety, backup and recovery instructions.
2. Flash the EFR32 Zigbee radio following the same guide.
3. Configure your Zigbee integration to use TCP **8888**, and migrate your Zigbee devices using the procedure appropriate for your current installation.
4. Verify reliable operation of your Zigbee devices.
5. Keep the console connected through a **3.3 V TTL UART adapter** and confirm that it still works.

**Checkpoint:** A working Linux/Zigbee gateway with a working serial console.
  
## 3. Prepare the build environment

1. Follow the [Build Environment README](https://github.com/jnilo1/rtl8196e-gateway/blob/main/1-Build-Environment/README.md#native-setup).  
2. Confirm network administration and the recovery procedure are available before removing serial console access.  


#### Silicon Labs tools: resolve download failures before declaring setup complete

The fresh installation successfully produced Lexra GCC 15.2.0 (crosstool-NG 1.28.0.3_a3fef85) and the Realtek tools. It then failed downloading slc-cli: the public URL in install_silabs.sh returned HTTP 403 from Akamai. This does not establish the reason for the rejection.

**Temporary procedure:**  
Silicon Labs' manual download links
  
https://www.silabs.com/documents/login/software/slc_cli_linux.zip  
https://www.silabs.com/documents/login/software/SimplicityCommander-Linux.zip  
  
Download the Linux ZIP through the official link in the browser and copy it to the Ubuntu build machine.

~~~powershell
scp "$env:USERPROFILE\Downloads\slc_cli_linux.zip" username@UBUNTU_IP:/home/username/rtl8196e-gateway/silabs-tools
scp "$env:USERPROFILE\Downloads\SimplicityCommander-Linux.zip" username@UBUNTU_IP:/home/username/rtl8196e-gateway/silabs-tools/Commander.zip
~~~

On Ubuntu, validate the copied archive and inspect its top-level paths before installing:

~~~sh
cd ~/rtl8196e-gateway/silabs-tools
unzip -q -o "$SLC_ZIP"
rm "$SLC_ZIP"
chmod +x slc_cli/slc

unzip -q commander.zip
tar xf SimplicityCommander-Linux/Commander_linux_x86_64_*.tar.bz -C .
rm -rf commander.zip SimplicityCommander-Linux
~~~

After manually installing the downloaded tools, rerun the installer:

~~~sh
cd ~/rtl8196e-gateway/1-Build-Environment
sudo ./install_deps.sh
~~~

#### Expected result  
SETUP COMPLETE - All tools are ready  

## 4. Apply the Linux 6.18 changes

All source edits below use sed. Run them from the repository root on a clean checkout of the selected revision. Copy commands must run only once: their destination directories/files must not already exist. Do not rerun the whole sequence over an existing modified tree.

These commands follow the recovered 6.18 source and patch layout. sed does not fail when a search pattern is missing, so review the final diff before building. Record the repository commit; the original installation's exact commit is still unknown.

### Set the paths

~~~sh
P=3-Main-SoC-Realtek-RTL8196E
KERNEL_SRC="$P/32-Kernel"
BASE="$KERNEL_SRC/files-6.18/drivers/net"
DTS="$KERNEL_SRC/files-6.18/arch/mips/boot/dts/realtek/rtl8196e.dts"
PATCHES="$KERNEL_SRC/patches-6.18"
INIT="$P/34-Userdata/skeleton/etc/init.d"
~~~

Keep the same shell open for the following commands.

### Disable the Linux console and serial login

Replace the console boot argument without changing the root filesystem arguments, then remove the ttyS0 getty entry:

~~~sh
sed -i 's/console=ttyS0,38400/console=null/' "$DTS"
sed -i '\|^ttyS0::respawn:/sbin/getty -L 38400 ttyS0 vt100$|d' "$P/33-Rootfs/skeleton/etc/inittab"
~~~

This removes both Linux console use and the login process from ttyS0. It does not silence the bootloader.
### Copy and modify the bridge driver

Retain the original Zigbee bridge and create a separate driver for H2:

~~~sh
cp -a "$BASE/rtl8196e-uart-bridge" "$BASE/rtl8196e-uart-bridge2"
mv "$BASE/rtl8196e-uart-bridge2/rtl8196e_uart_bridge_main.c" \
   "$BASE/rtl8196e-uart-bridge2/rtl8196e_uart_bridge2_main.c"

sed -i \
  -e 's/rtl8196e-uart-bridge"/rtl8196e-uart-bridge2"/g' \
  -e 's|"/dev/ttyS1"|"/dev/ttyS0"|g' \
  -e 's/rtl_port[[:space:]]*=[[:space:]]*8888;/rtl_port = 8889;/' \
  -e 's/rtl_baud[[:space:]]*=[[:space:]]*[0-9][0-9]*;/rtl_baud = 115200;/' \
  -e 's/rtl_flow_control[[:space:]]*=[[:space:]]*BRIDGE_FC_HW;/rtl_flow_control = 0;/' \
  -e 's/rtl_nrst_gpio[[:space:]]*=[[:space:]]*12;/rtl_nrst_gpio = -1;/' \
  -e 's/"uart-bridge-client"/"uart-bridge2-client"/g' \
  -e 's/port (default 8888)/port (default 8889)/' \
  -e 's/echo uart-bridge-client/echo uart-bridge2-client/' \
  "$BASE/rtl8196e-uart-bridge2/rtl8196e_uart_bridge2_main.c"
~~~

This assigns ttyS0, TCP 8889 and 115200 baud; disables flow control and the EFR32 reset GPIO; and gives bridge2 separate driver, LED-trigger and device-tree lookup names. No H2 reset GPIO is assigned. The driver changes have been compared against the expected diff on the new installation; image assembly succeeded, but the first upgrade still used the unmodified kernel; the subsequent explicit kernel build and upgrade successfully armed both bridges.

### Give bridge2 its own build configuration

Rename the copied Kconfig symbol and the object names in its Makefile:

~~~sh
sed -i \
  -e 's/^config RTL8196E_UART_BRIDGE$/config RTL8196E_UART_BRIDGE2/' \
  -e 's/Realtek RTL8196E in-kernel/Realtek RTL8196E second in-kernel/' \
  "$BASE/rtl8196e-uart-bridge2/Kconfig"

sed -i \
  -e 's/CONFIG_RTL8196E_UART_BRIDGE)/CONFIG_RTL8196E_UART_BRIDGE2)/g' \
  -e 's/rtl8196e_uart_bridge/rtl8196e_uart_bridge2/g' \
  "$BASE/rtl8196e-uart-bridge2/Makefile"
~~~

Run the Makefile substitution only once on the original copy; a repeat would produce bridge22 object names.

Add bridge2 to the existing kernel patches. The hunk-header substitutions below match the recovered patch versions; check the resulting patches if upstream has changed:

~~~sh
sed -i \
  -e 's/^@@ -514,6 +514,8 @@/@@ -514,6 +514,9 @@/' \
  -e '/^+source "drivers\/net\/rtl8196e-uart-bridge\/Kconfig"$/a\
+source "drivers/net/rtl8196e-uart-bridge2/Kconfig"' \
  "$PATCHES/drivers-net-Kconfig.patch"

sed -i \
  -e 's/^@@ -54,6 +54,7 @@/@@ -54,6 +54,8 @@/' \
  -e '/^+obj-$(CONFIG_RTL8196E_UART_BRIDGE) += rtl8196e-uart-bridge\/$/a\
+obj-$(CONFIG_RTL8196E_UART_BRIDGE2) += rtl8196e-uart-bridge2/' \
  "$PATCHES/drivers-net-Makefile.patch"

sed -i '/^CONFIG_RTL8196E_UART_BRIDGE=y$/a\
CONFIG_RTL8196E_UART_BRIDGE2=y' \
  "$KERNEL_SRC/config-6.18-realtek.txt"
~~~

The original bridge remains enabled. Both bridge2 Makefile entries now use CONFIG_RTL8196E_UART_BRIDGE2. This corrects the recovered implementation, which used the original bridge symbol in both places; the new build has now run on the gateway and both bridges armed successfully.

### Create the startup script

Copy the original startup file, preserving its permissions, then replace its contents using sed:

~~~sh
cp -a "$INIT/S50uart_bridge" "$INIT/S51uart_bridge2"

sed -i '1,$c\
#!/bin/sh\
\
PARAMS=/sys/module/rtl8196e_uart_bridge2/parameters\
\
case "$1" in\
    start)\
        [ -d "$PARAMS" ] || exit 1\
        echo 0 > "$PARAMS/flow_control"\
        echo 1 > "$PARAMS/enable"\
        ;;\
    stop)\
        [ -d "$PARAMS" ] || exit 0\
        echo 0 > "$PARAMS/enable"\
        ;;\
    restart)\
        "$0" stop && "$0" start\
        ;;\
    *)\
        echo "Usage: $0 {start|stop|restart}"\
        exit 1\
        ;;\
esac\
\
exit 0' "$INIT/S51uart_bridge2"

chmod +x "$INIT/S51uart_bridge2"
~~~

The script uses the driver's compiled ttyS0/115200/8889 defaults, disables flow control and enables bridge2. It does not read or alter the original EFR32 radio configuration. Its contents match the recovered startup script.

### Review and compile

~~~sh
git diff --check
git diff -- . ':!*.img'
git status --short

cat "$BASE/rtl8196e-uart-bridge2/Kconfig"
cat "$BASE/rtl8196e-uart-bridge2/Makefile"
sh -n "$INIT/S51uart_bridge2"

diff -u \
  "$BASE/rtl8196e-uart-bridge/rtl8196e_uart_bridge_main.c" \
  "$BASE/rtl8196e-uart-bridge2/rtl8196e_uart_bridge2_main.c"
~~~

The last command is expected to report differences. New untracked files are not included in ordinary git diff, so review the copied driver files and startup script as well. Ensure no unrelated changes were introduced.

### Build from source before assembling the flash image

~~~sh
./3-Main-SoC-Realtek-RTL8196E/32-Kernel/build_kernel.sh
~~~


## 5. Upgrade and verify the freed UART

### Check the temporary bootloader/TFTP address first

In the upgrade setup used here, the temporary bootloader/TFTP address is **x.x.x.6** on the selected network. This is separate from the gateway's normal Linux address, here x.x.x.251.  
Confirm the actual bootloader address shown by your installer before proceeding; do not infer it from the Linux address alone.

**The temporary address must be free before the gateway enters bootloader mode.** If another device already uses x.x.x.6, the upgrade can fail or contact the wrong device. Check your DHCP leases/reservations, static-address records and the network itself. A missing ping response alone does not prove the address is unused.

Reserve/exclude the intended address from conflicting assignments, or select another free bootloader address using the options supported by your upstream revision. The inspected installer supports --boot-ip; check its local --help before using it. Keep the build VM on the same VLAN/subnet with bridged networking.


Use the [Upgrade guide README](https://github.com/jnilo1/rtl8196e-gateway/blob/main/docs/upgrading.md) as reference, for uploading the new firmware. 

After upgrading, run these checks **on the gateway**:

~~~sh
ls -l /userdata/etc/init.d/S51uart_bridge2
sh -n /userdata/etc/init.d/S51uart_bridge2
cat /proc/cmdline
ls /sys/module/rtl8196e_uart_bridge2/parameters
cat /sys/module/rtl8196e_uart_bridge2/parameters/armed
~~~

Confirm the script is executable, console=null is present, bridge2 parameters exist and armed is 1. Also verify that Zigbee still works on TCP 8888. A missing script after a kernel/rootfs-only update does not establish a driver fault: that update does not install the new userdata script.

### Confirmed gateway result

After the explicit kernel build and full upgrade, the gateway reported:

~~~text
dmesg
[   13.016640] rtl8196e-uart-bridge: armed on /dev/ttyS1 @ 115200 baud, listening on 0.0.0.0:8888
[   13.086640] rtl8196e-uart-bridge2: armed on /dev/ttyS0 @ 115200 baud, listening on 0.0.0.0:8889
[   17.557760] rtl8196e-uart-bridge: client connected from HA-Server:42578
~~~

This confirms that both drivers initialized and armed with the intended UARTs, baud rate and TCP ports.

1. Keep the TTL adapter connected while verifying the result.
2. Confirm that the gateway boots and remains accessible over the network.
3. Verify that Zigbee still works on TCP **8888**.
4. Observe the serial output during boot and after Linux starts. Confirm that Linux no longer writes console messages and that no login prompt appears. Check the running kernel command line and confirm that getty is absent.


## 6. Prepare the ESP32-H2

1. Flash the H2 over USB with OpenThread **RCP** firmware. The original setup used a standard Thread radio example.
2. Configure its transport UART for **115200 baud without hardware flow control**.
3. Verify the UART pins and serial framing. Keep debug/log output off the RCP transport UART.
4. Record the board model, example name, SDK version/commit, GPIO assignments and configuration.


**Not yet recorded:** Exact example, build/USB flash commands and GPIO numbers. Establish these for the selected board and firmware.


**Observed limitation:** 460800 baud caused communication errors in the original setup; 115200 was used instead. The cause is unknown. The existing Zigbee baud rate was also recalled as 115200 but requires verification.

## 7. Wire the H2 and configure TCP 8889

1. Disconnect power before changing wiring. Disconnect the TTL console adapter before connecting the H2.
2. Verify the actual ttyS0 pads and H2 RCP UART pins. Use **3.3 V logic**, not RS-232 or 5 V UART.
3. Connect gateway TX to H2 RX, gateway RX to H2 TX, and common GND. RTS/CTS is not used.
4. Provide a suitable, verified power supply. Avoid backfeeding if USB and gateway power are both present.
5. Configure a persistent, transparent serial-to-TCP bridge:

| Setting | Value |
| --- | --- |
| UART | /dev/ttyS0 |
| Baud rate | 115200 |
| Hardware flow control | Disabled |
| TCP port | 8889 |

6. Retain the existing EFR32 Zigbee bridge on TCP **8888**.

The bridge2 driver defaults and S51uart_bridge2 startup script are documented in step 4. After upgrading, verify that the script exists and is executable under /userdata/etc/init.d, then confirm bridge2 is armed and listening on TCP 8889.

Restrict radio ports to trusted local systems and use one active client per radio.

### Wiring diagram and connector pinout

The following pin mapping was confirmed by the owner for the installed gateway and H2 board. Pin numbers in the left column refer to the Silvercrest connector; GPIO23 and GPIO24 refer to ESP32-H2 GPIO numbers.

| Silvercrest connector pin | Signal | ESP32-H2 connection |
| --- | --- | --- |
| 1 | 3.3 V VCC | 3V3 |
| 2 | Ground | GND |
| 3 | RTL8196E serial TX | GPIO23 — U0RXD |
| 4 | RTL8196E serial RX | GPIO24 — U0TXD |
| 5 | EFR32 SWDIO | Not connected |
| 6 | EFR32 SWCLK | Not connected |

~~~mermaid
flowchart LR
    subgraph GW[Silvercrest connector]
        V["Pin 1 · 3.3 V VCC"]
        G["Pin 2 · GND"]
        T["Pin 3 · UART0 TX"]
        R["Pin 4 · UART0 RX"]
    end
    subgraph H2[ESP32-H2]
        HV["3V3"]
        HG["GND"]
        HR["GPIO23 · U0RXD"]
        HT["GPIO24 · U0TXD"]
    end
    V --> HV
    G --- HG
    T --> HR
    HT --> R
~~~

This is a connection diagram, not a physical connector orientation drawing. Identify pin 1 from the verified board pinout before wiring; do not infer it from the order of boxes or wire colours. Supply the H2 through its 3V3 pin from the gateway's 3.3 V connection in this installation. Avoid simultaneous USB power unless the board's power arrangement has been checked for backfeeding. Pins 5 and 6 remain unconnected. No RTS/CTS connections are used.

**RCP configuration confirmed from the firmware project:** CONFIG_OPENTHREAD_RCP_UART=y, UART port 0, 115200 baud, 8 data bits, no parity, 1 stop bit, and UART_HW_FLOWCTRL_DISABLE. CONFIG_OPENTHREAD_UART_PIN_MANUAL is not set, so the code uses UART_PIN_NO_CHANGE. The GPIO23/RX and GPIO24/TX assignments come from the owner's UART0 pin mapping; the manual-pin Kconfig defaults of RX=4 and TX=5 are inactive.

### Installation photos

![ESP32-H2 board positioned inside the Silvercrest gateway enclosure](images/silvercrest-h2-installation.jpg)

Overview of the ESP32-H2 placement and cable routing inside the original enclosure.

![Close-up of the wiring between the Silvercrest gateway and ESP32-H2 board](images/silvercrest-h2-wiring-detail.jpg)

Close-up of the connections with the H2 board lifted out for visibility. These photos document the physical installation; use the verified board pinouts and TX/RX/GND connection instructions above to identify signals. Wire colours alone do not establish pin functions or supply voltage.

## 8. Add OTBR to Home Assistant

Install the OpenThread Border Router add-on. The original setup used:

~~~yaml
device: /dev/ttyS3
baudrate: '115200'
flow_control: false
otbr_log_level: info
firewall: true
nat64: false
beta: false
network_device: 10.36.5.251:8889
~~~

1. Ensure the gateway has the expected address, here **10.36.5.251**.
2. Save the configuration and start OTBR.
3. Check its log for connection to the network RCP and successful radio initialization without repeated resets.
4. Configure HA's Thread integration and select the intended Thread network.
5. Test a known Thread device, then repeat after restarting both the gateway and OTBR.
6. Verify simultaneous Zigbee and Thread operation.

/dev/ttyS3 is reproduced from the original HA configuration; it is not the gateway UART. Verify that your installed add-on uses network_device and actually connects to TCP **8889**.

The original discussion reported an ESPHome-based H2 device using Thread. Its exact firmware and test coverage were not recorded.

## 9. Add Matter later

Once Thread is stable, configure HA's Matter functionality and test an actual Matter-over-Thread device separately. Check IPv6, local discovery and commissioning access as needed for your network.

**Matter had not yet been tested in the original setup.** Working Thread communication alone does not confirm Matter operation.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Errors at 460800 | Use 115200 on H2, gateway bridge and OTBR, without hardware flow control. |
| Linux output or login prompt on ttyS0 | DTS boot arguments, running kernel command line, getty removal and other serial logging services. |
| Only bootloader output remains | Distinguish it from Linux output and assess its effect on H2 startup. |
| TCP 8889 is unreachable | Gateway address, bridge startup, local network access and another client occupying the port. |
| TCP connects but RCP initialization fails | RCP firmware, pins, crossed TX/RX, GND, baud rate, framing, flow control and power. |
| Zigbee stops working | EFR32 firmware/configuration, TCP 8888 and unintended changes to its bridge. |
| Works until reboot | Persistent bridge settings, service startup and reconnection behavior. |
| Thread works but Matter does not | Matter commissioning, credentials, IPv6 and discovery. |

## References

- [Upstream Getting Started](https://jnilo1.github.io/rtl8196e-gateway/docs/getting-started/)
- [Upstream Build Environment README](https://github.com/jnilo1/rtl8196e-gateway/blob/main/1-Build-Environment/README.md)
- [Upstream repository](https://github.com/jnilo1/rtl8196e-gateway)

Setup observations and HA settings come from the original private discussion. Unrecorded commands remain explicitly marked above.

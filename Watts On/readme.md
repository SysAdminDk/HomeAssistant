# Export Your Own Historical Data from Watts On

> **Unofficial guide for Windows and PowerShell.** Tested in 2026, this method uses Android emulators to retrieve the local SQLite database used by the Watts On app. It is intended as a workaround until Watts On potentially offers a direct export feature.

This guide explains how to retrieve **your own** Watts On data, including historical electricity, water, and district heating measurements. You will obtain a local copy of the app's database that you can inspect or use with other tools.

**Important:** This method is unofficial, may stop working after app or Android updates, and is not affiliated with or endorsed by Watts On. Only access accounts and data you are authorized to use. The database may contain personal information: do not publish it or commit it to your Git repository.

## Overview

I used **two Android emulators**, each serving a different purpose:

| Emulator | System image | Purpose |
| --- | --- | --- |
| 1: Google Play | Android 13 / API 33 / x86_64 / **Play Store** | Install Watts On from the Play Store and extract its installation packages (split APKs) |
| 2: Google APIs | Android 13 / API 33 / x86_64 / **Google APIs** | Install the APKs, sign in, synchronize historical data, and extract the database using `adb root` |

Play Store emulator images normally do not allow `adb root`. Google APIs images can allow root access but normally do not include the Play Store. That is why we transfer the APK files between the two emulators.

## 1. Prerequisites

- Windows with **PowerShell 5.1**.
- **Android Studio**, Android Emulator, and Android SDK Platform-Tools (`adb.exe`).  
  [Android Studio](https://developer.android.com/studio)  
  [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools)  

- A Google account for the Play Store.
- Access to your own **Watts On** account and the relevant utility provider credentials.
- Enough free disk space for the emulators and database extraction.
- For database verification: **SQLite Command Line Shell** (`sqlite3.exe`) from [sqlite.org/download.html](https://www.sqlite.org/download.html).

This procedure was tested using Android Studio 2026.2.1, Pixel 7, and Android 13 (API 33). Other versions were not verified in this walkthrough.

Open PowerShell and locate ADB. If you downloaded Platform-Tools separately and are working in the folder containing `adb.exe`, you can instead set `$Adb = '.\adb.exe'`.

```powershell
$Adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
& $Adb version
```

## 2. Create the Google Play Emulator

1. Start **Android Studio**.
2. On the welcome screen, select **More Actions → Virtual Device Manager**.
3. Select **Create Virtual Device**.
4. Use these settings:

   | Setting | Value |
   | --- | --- |
   | Device | **Pixel 7** |
   | Android | **13** |
   | API | **33** |
   | Services / system image | **Play Store** |
   | Architecture | **x86_64** |

5. Finish creating the device and start the emulator.
6. Sign in to the **Google Play Store** using an Google account.
7. Search for **Watts On** and install it.
8. Open Watts On, sign in using your credentials, and let the app synchronize.

> In our test, a Pixel 10 running Android 17 encountered Play Store sign-in difficulties, so we used a Pixel 7 with Android 13 instead. This was an observation from our test, not a confirmed general Android 17 issue.

## 3. Extract the Watts On APK Files

Run the following commands in PowerShell. Make sure only the intended emulator is running, or select the correct device ID reported by `adb devices`.

```powershell
& $Adb devices
```

In our test, the device ID was `emulator-5554`. Change it if yours differs:

```powershell
$Device = 'emulator-5554'
$Package = 'com.seasnve.watts'
$Destination = Join-Path $env:USERPROFILE 'Downloads\WattsAPK-x86'

New-Item -ItemType Directory -Force -Path $Destination | Out-Null

$Paths = & $Adb -s $Device shell pm path $Package
if (-not $Paths) {
    throw 'Watts On was not found. Check the emulator and app installation.'
}

foreach ($Entry in $Paths) {
    $Remote = ($Entry -replace '^package:', '').Trim()
    $FileName = Split-Path $Remote -Leaf
    & $Adb -s $Device pull $Remote (Join-Path $Destination $FileName)
    if ($LASTEXITCODE -ne 0) { throw "Failed to download $Remote" }
}

Get-ChildItem -Path $Destination -Filter '*.apk' | Select-Object Name, Length
```

The download produced these four files:

```text
base.apk
split_config.en.apk
split_config.x86_64.apk
split_config.xxhdpi.apk
```

**Note:** The number and names of split APKs can change depending on the Watts On version and emulator configuration. Use the files actually returned by `pm path`, and keep them together.

## 4. Create a Root-Capable Emulator

1. Preferably shut down the first emulator to avoid selecting the wrong device.
2. Open **Android Studio → More Actions → Virtual Device Manager → Create Virtual Device**.
3. Create another **Pixel 7** with **Android 13 / API 33 / x86_64**.
4. Select the **Google APIs** system image — **not Play Store**.
5. Start the new emulator.

Verify the device ID and root access:

```powershell
& $Adb devices
$Device = 'emulator-5554'  # Change if necessary
& $Adb -s $Device root
& $Adb -s $Device shell id
```

During our test, `adb root` returned:

```text
restarting adbd as root
```

And `shell id` returned:

```text
uid=0(root) gid=0(root) groups=0(root),1004(input),1007(log),1011(adb),1015(sdcard_rw),1028(sdcard_r),1078(ext_data_rw),1079(ext_obb_rw),3001(net_bt_admin),3002(net_bt),3003(inet),3006(net_bw_stats),3009(readproc),3011(uhid),3012(readtracefs) context=u:r:su:s0
```

Do not continue until you have confirmed `uid=0(root)`. Root support depends on the selected emulator image.

## 5. Install Watts On on the Root-Capable Emulator

Use the APK files from step 3. The following command matches the four files extracted during our test:

```powershell
$ApkPath = Join-Path $env:USERPROFILE 'Downloads\WattsAPK-x86'

& $Adb -s $Device install-multiple -r `
    "$ApkPath\base.apk" `
    "$ApkPath\split_config.en.apk" `
    "$ApkPath\split_config.x86_64.apk" `
    "$ApkPath\split_config.xxhdpi.apk"
```

Expected output:

```text
Success
```

If your APK splits differ from those in step 3, adjust the installation command accordingly.

Open Watts On on **the root-capable emulator**, sign in using your own utility provider credentials, and wait until the app has downloaded the historical data you need. **The data from this second emulator is what we will export.**

## 6. Stop Watts On Before Copying the Database

Once synchronization is complete, stop the app so it does not continue writing to its SQLite database during extraction.

```powershell
& $Adb -s $Device shell am force-stop com.seasnve.watts
& $Adb -s $Device shell pidof com.seasnve.watts
```

`pidof` should return no process ID. If you reopen the app, stop it again before extracting the database.

Check which database files exist:

```powershell
& $Adb -s $Device shell ls -lh /data/user/0/com.seasnve.watts/databases/
```

In our test, the database was located at:

```text
/data/user/0/com.seasnve.watts/databases/watts-db.db
```

SQLite may also have `watts-db.db-wal` and `watts-db.db-shm` files. These may not be present after the app has been stopped.

## 7. Copy the Database to Windows

```powershell
$Source = '/data/user/0/com.seasnve.watts/databases'
$Destination = Join-Path $env:USERPROFILE 'Downloads\WattsDB'

New-Item -ItemType Directory -Force -Path $Destination | Out-Null

foreach ($File in @('watts-db.db', 'watts-db.db-wal', 'watts-db.db-shm')) {
    & $Adb -s $Device shell ls "$Source/$File" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        & $Adb -s $Device pull "$Source/$File" (Join-Path $Destination $File)
        if ($LASTEXITCODE -ne 0) { throw "Failed to copy $File" }
    }
}

Get-ChildItem -Path $Destination | Select-Object Name, Length, LastWriteTime
```

The original verified procedure attempted to copy all three files using `adb pull`. The version above skips optional files when they are absent.

**Keep the original extracted files unchanged.** Keep the files together when moving or processing the database.

## 8. Verify the Database and Checkpoint Any WAL Data

SQLite may use a **Write-Ahead Log (WAL)** to store changes before they are incorporated into the main database file. We therefore make a working copy and verify it.

Download **SQLite Command Line Shell for Windows** from [SQLite](https://www.sqlite.org/download.html), extract it, and open PowerShell in the directory containing `sqlite3.exe`.

```powershell
$Source = Join-Path $env:USERPROFILE 'Downloads\WattsDB'
$Working = Join-Path $env:USERPROFILE 'Downloads\WattsDB-Verified'

New-Item -ItemType Directory -Force -Path $Working | Out-Null
Copy-Item -Path (Join-Path $Source 'watts-db.db*') -Destination $Working -Force

$Db = Join-Path $Working 'watts-db.db'

.\sqlite3.exe $Db 'PRAGMA integrity_check;'
.\sqlite3.exe $Db 'PRAGMA wal_checkpoint(TRUNCATE);'
.\sqlite3.exe $Db 'PRAGMA integrity_check;'
```

Both integrity checks should return:

```text
ok
```

The checkpoint command returns three values: `busy`, `log`, and `checkpointed`. In our completed test, the result was:

```text
busy  log  checkpointed
0     0    0
```

This means the checkpoint was not blocked and no WAL frames needed to be moved at that point. If `busy` is not `0`, or an integrity check does not return `ok`, do not continue using that copy.

To create a standalone database that does not depend on a separate WAL file, you can also use SQLite's backup command after verification:

```powershell
$Standalone = Join-Path $Working 'watts-export.db'
.\sqlite3.exe $Db ".backup '$($Standalone -replace "'", "''")'"
.\sqlite3.exe $Standalone 'PRAGMA integrity_check;'
```

Once the final check returns `ok`, you can use `watts-export.db` for further work. Keep the original extracted files as a backup.

## 9. Use Your Data

The result is a **SQLite database**, not a ready-made CSV export. You can open it with SQLite tools and inspect its tables:

```powershell
.\sqlite3.exe $Standalone '.tables'
```

The schema and table names depend on the Watts On version. This guide does not modify the measurements or include a generic CSV exporter, since that would first require examining the tables and their meaning.

## 10. Export Electricity, Water and District Heating to CSV (Optional)

If you prefer spreadsheets or your own analysis tools, you can export consumption records **without Grafana**. Download [`Export-WattsCSV.ps1`](Export-WattsCSV.ps1) from this repository and place it in the same directory as `sqlite3.exe` (or provide the full SQLite executable path).

Run from PowerShell:

```powershell
.\Export-WattsCSV.ps1 -Database "$Standalone" -OutputPath "$env:USERPROFILE\Downloads\WattsCSV"
```

The script produces three files:

| File | Source table | Exported fields |
| --- | --- | --- |
| `electricity.csv` | `electricityConsumptions` | `deviceId`, `startDate`, `endDate`, `value`, `alwaysOnValue` |
| `water.csv` | `waterConsumptions` | `deviceId`, `startDate`, `endDate`, `value`, `measuredQuality` |
| `heating.csv` | `heatingConsumptions` | `deviceId`, `startDate`, `endDate`, `value`, `volume`, `measuredQuality` |

The export preserves the original timestamps (ISO 8601, UTC) and raw numeric values. It excludes forecast-only electricity rows where `value = -1`, and includes only water/heating rows marked `MEASURED` with nonnegative `value`. This is a **measured-consumption subset**, not a complete raw-table export. Other data quality states and forecasts are intentionally omitted. The units of `value`, `volume`, and `alwaysOnValue` have **not yet been independently confirmed** from the database schema; do not assume units without checking your provider's data. The script keeps `deviceId` to distinguish multiple meters. **CSV files may contain sensitive meter identifiers and consumption patterns; do not commit them to Git.**
  
### Optional: Use the Database in Grafana

If you already use Grafana with a SQLite data source/plugin, you can copy the verified database to a machine or container accessible to Grafana and configure the SQLite data source with the file path.

Example for **Grafana running in a Proxmox LXC container** (replace the IP address, container ID, and paths as appropriate):

From Windows PowerShell:

```powershell
scp "$Standalone" root@<PROXMOX-IP>:/var/tmp/watts-export.db
```

On the Proxmox host:

```bash
# Create the destination directory and check permissions inside the container first.
pct push <CONTAINER-ID> /var/tmp/watts-export.db /var/lib/grafana/watts/watts-export.db
```

Then configure the installed Grafana SQLite data source to use that file. **Do not overwrite an existing working database**; use a separate filename and make a backup if necessary.

## Final Notes

You now have a local copy of the historical data that Watts On synchronized into its app database. The available date range and measurements depend on your account, utility provider, and what the app has synchronized.

This is an **unofficial workaround for accessing your own data** until an official export feature may become available. Feel free to share the guide, but **never share your database or login credentials**.

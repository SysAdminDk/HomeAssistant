# Export measured Watts On consumption records to three CSV files.
# Requires Windows PowerShell 5.1+ and sqlite3.exe.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Database,

    [string]$OutputPath = (Join-Path (Get-Location).Path 'CSV'),

    [string]$SQLite = '.\sqlite3.exe'
)

$ErrorActionPreference = 'Stop'
$Database = (Resolve-Path -LiteralPath $Database).Path
$SQLiteCommand = Get-Command $SQLite -ErrorAction Stop
$SQLiteExecutable = $SQLiteCommand.Source

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
$OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path

$Exports = @(
    @{ Name = 'electricity.csv'; Query = 'SELECT deviceId, startDate, endDate, value, alwaysOnValue FROM electricityConsumptions WHERE value IS NOT NULL AND value >= 0 ORDER BY deviceId, startDate;' },
    @{ Name = 'water.csv'; Query = "SELECT deviceId, startDate, endDate, value, measuredQuality FROM waterConsumptions WHERE measuredQuality = 'MEASURED' AND value IS NOT NULL AND value >= 0 ORDER BY deviceId, startDate;" },
    @{ Name = 'heating.csv'; Query = "SELECT deviceId, startDate, endDate, value, volume, measuredQuality FROM heatingConsumptions WHERE measuredQuality = 'MEASURED' AND value IS NOT NULL AND value >= 0 ORDER BY deviceId, startDate;" }
)

foreach ($Export in $Exports) {
    $Target = Join-Path $OutputPath $Export.Name
    $Temp = "$Target.tmp"
    try {
        # The SQLite CLI formats/escapes the CSV; PowerShell writes UTF-8.
        & $SQLiteExecutable -batch -csv -header $Database $Export.Query |
            Out-File -LiteralPath $Temp -Encoding utf8
        if ($LASTEXITCODE -ne 0) {
            throw "SQLite export failed for $($Export.Name) (exit code $LASTEXITCODE)."
        }
        Move-Item -LiteralPath $Temp -Destination $Target -Force
        Write-Host "Created $Target"
    }
    finally {
        if (Test-Path -LiteralPath $Temp) { Remove-Item -LiteralPath $Temp -Force }
    }
}

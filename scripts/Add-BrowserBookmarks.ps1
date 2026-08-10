<#
.SYNOPSIS
    Directly adds bookmarks into Chrome and/or Edge's own bookmark
    storage — no manual import step required.

.DESCRIPTION
    Chrome and Edge (both Chromium-based) store bookmarks in a JSON file
    named "Bookmarks" inside each profile folder. This script:

      1. Detects installed browser profiles (Default, Profile 1, ...)
         for every local user on the machine.
      2. Skips (with a warning) any browser that's currently running,
         unless -CloseBrowser is specified — editing the file while the
         browser is open is unsafe: the running browser holds its own
         in-memory copy and will silently overwrite our changes with its
         old state the next time it closes.
      3. Backs up the existing Bookmarks file before touching it.
      4. Reads the existing JSON, finds or creates a folder (named by
         -TargetFolder) under the Bookmarks Bar.
      5. Adds each entry from $Bookmarks into that folder, skipping any
         URL that already exists anywhere in the file (duplicate check).
      6. Writes the updated JSON back, preserving every existing
         bookmark, folder, and the rest of the file structure untouched.

    Fill in the $Bookmarks array below with your company links, then run.

.PARAMETER Browser
    Chrome, Edge, or Both. Default is Both.

.PARAMETER TargetFolder
    Name of the bookmark folder the links are added into (created if it
    doesn't already exist). Default is "Company Bookmarks".

.PARAMETER CloseBrowser
    Force-closes the browser first if it's running, so the edit can be
    made safely. Without this, a running browser is skipped entirely.

.PARAMETER DryRun
    Reports what would be added/skipped without writing any changes.

.EXAMPLE
    .\Add-BrowserBookmarks.ps1 -DryRun

.EXAMPLE
    .\Add-BrowserBookmarks.ps1 -Browser Chrome -CloseBrowser

.EXAMPLE
    .\Add-BrowserBookmarks.ps1 -TargetFolder "IT Resources" -CloseBrowser
#>

[CmdletBinding()]
param(
    [ValidateSet('Chrome', 'Edge', 'Both')]
    [string]$Browser = 'Both',

    [string]$TargetFolder = 'Company Bookmarks',

    [switch]$CloseBrowser,
    [switch]$DryRun
)

$ErrorActionPreference = 'SilentlyContinue'

# Load bookmarks from configuration file
$configPath = Join-Path $PSScriptRoot "bookmarks.json"

if (-not (Test-Path $configPath)) {
    throw "Bookmarks configuration file not found: $configPath"
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$Bookmarks = $config.bookmarks
# ---------------------------------------------------------------------

if ($Bookmarks.Count -eq 0) {
    Write-Host "No bookmarks defined yet. Add entries to the `$Bookmarks array in this script, then run it again." -ForegroundColor Yellow
    return
}

function Get-ChromeTimestamp {
    $epoch = [datetime]::new(1601, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)
    $now = [datetime]::UtcNow
    return [int64](($now - $epoch).Ticks / 10)
}

function New-BookmarkGuid {
    return [guid]::NewGuid().ToString()
}

function Get-MaxBookmarkId {
    param($Node)
    $max = 0
    if ($Node.id) {
        $idVal = 0
        if ([int]::TryParse([string]$Node.id, [ref]$idVal) -and $idVal -gt $max) { $max = $idVal }
    }
    if ($Node.children) {
        foreach ($child in $Node.children) {
            $childMax = Get-MaxBookmarkId -Node $child
            if ($childMax -gt $max) { $max = $childMax }
        }
    }
    return $max
}

function Get-NormalizedUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return ""
    }

    $u = $Url.Trim().ToLowerInvariant()
    $u = $u -replace '^https?://', ''
    $u = $u -replace '^www\.', ''

    return $u.TrimEnd('/')
}

function Get-AllBookmarkUrls {
    param($Node, [System.Collections.Generic.HashSet[string]]$UrlSet)
    if ($Node.type -eq 'url' -and $Node.url) {[void]$UrlSet.Add((Get-NormalizedUrl $Node.url))}
    if ($Node.children) {
        foreach ($child in $Node.children) {
            Get-AllBookmarkUrls -Node $child -UrlSet $UrlSet
        }
    }
}

function Find-OrCreateFolder {
    param($ParentNode, [string]$FolderName, [ref]$NextId)
    $existing = $ParentNode.children | Where-Object { $_.type -eq 'folder' -and $_.name -eq $FolderName } | Select-Object -First 1
    if ($existing) { return $existing }

    $ts = Get-ChromeTimestamp
    $newFolder = [PSCustomObject]@{
        children      = @()
        date_added    = "$ts"
        date_modified = "$ts"
        guid          = (New-BookmarkGuid)
        id            = "$($NextId.Value)"
        name          = $FolderName
        type          = 'folder'
    }
    $NextId.Value++
    $ParentNode.children = @($ParentNode.children) + $newFolder
    return $newFolder
}

function Backup-BookmarksFile {
    param([string]$Path)
    $backupPath = "$Path.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -Path $Path -Destination $backupPath -Force
    return $backupPath
}

function Update-BrowserBookmarksFile {
    param([string]$BookmarksFilePath, [string]$ProfileLabel)

    if (-not (Test-Path $BookmarksFilePath)) { return $null }

    $raw = Get-Content -Path $BookmarksFilePath -Raw -Encoding UTF8
    try {
        $json = $raw | ConvertFrom-Json
    } catch {
        Write-Warning "Could not parse Bookmarks file for $ProfileLabel - skipping ($_)"
        return $null
    }

    # Find highest existing id across the whole file so new ids stay unique
    $maxId = 0
    foreach ($rootName in @('bookmark_bar', 'other', 'synced')) {
        $rootNode = $json.roots.$rootName
        if ($rootNode) {
            $m = Get-MaxBookmarkId -Node $rootNode
            if ($m -gt $maxId) { $maxId = $m }
        }
    }
    $nextIdRef = [ref]($maxId + 1)

    # Collect every existing URL in the file for duplicate checking
    $existingUrls = New-Object System.Collections.Generic.HashSet[string]
    foreach ($rootName in @('bookmark_bar', 'other', 'synced')) {
        $rootNode = $json.roots.$rootName
        if ($rootNode) { Get-AllBookmarkUrls -Node $rootNode -UrlSet $existingUrls }
    }

    $targetFolderNode = Find-OrCreateFolder -ParentNode $json.roots.bookmark_bar -FolderName $TargetFolder -NextId $nextIdRef

    $added = 0
    $skipped = 0
    $addedNames = @()
    $skippedNames = @()

    foreach ($bm in $Bookmarks) {
        if ([string]::IsNullOrWhiteSpace($bm.Url)) { continue }

        if ($existingUrls.Contains((Get-NormalizedUrl $bm.Url))) {
            $skipped++
            $skippedNames += $bm.Name
            continue
        }

        $ts = Get-ChromeTimestamp
        $newNode = [PSCustomObject]@{
            date_added = "$ts"
            guid       = (New-BookmarkGuid)
            id         = "$($nextIdRef.Value)"
            name       = $bm.Name
            type       = 'url'
            url        = $bm.Url
        }
        $nextIdRef.Value++

        $targetFolderNode.children = @($targetFolderNode.children) + $newNode
        [void]$existingUrls.Add((Get-NormalizedUrl $bm.Url))
        $added++
        $addedNames += $bm.Name
    }

    $targetFolderNode.date_modified = "$(Get-ChromeTimestamp)"

    $backupPath = $null
    if ($added -gt 0 -and -not $DryRun) {
        $backupPath = Backup-BookmarksFile -Path $BookmarksFilePath
        $newJsonString = $json | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($BookmarksFilePath, $newJsonString, (New-Object System.Text.UTF8Encoding($false)))
    }

    [PSCustomObject]@{
        Profile      = $ProfileLabel
        Added        = $added
        Skipped      = $skipped
        AddedNames   = ($addedNames -join ', ')
        SkippedNames = ($skippedNames -join ', ')
        Backup       = $backupPath
        Status       = if ($DryRun) { 'DryRun - not written' }
                        elseif ($added -eq 0) { 'No changes (all duplicates)' }
                        else { 'Updated' }
    }
}

function Close-BrowserIfRunning {
    param([string]$ProcessName)
    $running = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($running) {
        if ($CloseBrowser -and -not $DryRun) {
            Write-Host "Closing $ProcessName..." -ForegroundColor Yellow
            Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            return $true
        }
        return $false
    }
    return $true
}

$userProfiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }

$results = @()

$browserTargets = @()
if ($Browser -in @('Chrome', 'Both')) {
    $browserTargets += [PSCustomObject]@{ Name = 'Chrome'; ProcessName = 'chrome'; UserDataFolder = 'Google\Chrome\User Data' }
}
if ($Browser -in @('Edge', 'Both')) {
    $browserTargets += [PSCustomObject]@{ Name = 'Edge'; ProcessName = 'msedge'; UserDataFolder = 'Microsoft\Edge\User Data' }
}

foreach ($target in $browserTargets) {
    $canProceed = Close-BrowserIfRunning -ProcessName $target.ProcessName
    if (-not $canProceed) {
        $results += [PSCustomObject]@{
            Profile      = "$($target.Name)"
            Added        = 0
            Skipped      = 0
            AddedNames   = ""
            SkippedNames = ""
            Backup       = $null
            Status       = "Browser is running. Close the browser or enable CloseBrowser."
        }

        continue
    }

    foreach ($user in $userProfiles) {
        $userDataPath = Join-Path $user.FullName "AppData\Local\$($target.UserDataFolder)"
        if (-not (Test-Path $userDataPath)) { continue }

        $profileDirs = Get-ChildItem $userDataPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'Default' -or $_.Name -match '^Profile \d+$' }

        foreach ($p in $profileDirs) {
            $bookmarksPath = Join-Path $p.FullName 'Bookmarks'
            $label = "$($target.Name) - $($user.Name)\$($p.Name)"
            $results += Update-BrowserBookmarksFile -BookmarksFilePath $bookmarksPath -ProfileLabel $label
        }
    }
}

$results = @($results | Where-Object { $_ -ne $null })

$totalAdded = 0
$totalSkipped = 0

if ($results.Count -gt 0) {
    $totalAdded = ($results | Measure-Object -Property Added -Sum).Sum
    $totalSkipped = ($results | Measure-Object -Property Skipped -Sum).Sum
}

$result = [PSCustomObject]@{
    Browser            = $Browser
    ProfilesProcessed  = $results.Count
    BookmarksAdded     = $totalAdded
    BookmarksSkipped   = $totalSkipped
    DryRun             = [bool]$DryRun
    Status             = if ($results.Count -eq 0) { "no_profiles_found" } else { "success" }
    Message            = if ($results.Count -eq 0) {
                            "No browser profiles were updated."
                         }
                         elseif ($DryRun) {
                            "Dry run completed successfully."
                         }
                         else {
                            "Bookmarks imported successfully."
                         }
    Results            = $results
}

$result | ConvertTo-Json -Depth 5
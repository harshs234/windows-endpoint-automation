$systemDrive = $env:SystemDrive.TrimEnd(':')
$errors = @()

function Get-FolderSizeGB {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    $size = (Get-ChildItem -Path $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    if (-not $size) { return 0 }
    return [math]::Round($size / 1GB, 4)
}

function Get-RecycleBinSizeGB {
    try {
        $shell = New-Object -ComObject Shell.Application
        $bin = $shell.Namespace(0xA)
        $sizeBytes = 0
        if ($bin) {
            foreach ($item in $bin.Items()) {
                $sizeBytes += [double]($item.ExtendedProperty('Size'))
            }
        }
        return [math]::Round($sizeBytes / 1GB, 4)
    } catch {
        return 0
    }
}

# Mirror the exact same targets cleanup-api.ps1 deletes from — measure only
$userTempGB    = Get-FolderSizeGB -Path $env:TEMP
$windowsTempGB = Get-FolderSizeGB -Path (Join-Path $env:SystemRoot 'Temp')
$prefetchGB    = Get-FolderSizeGB -Path (Join-Path $env:SystemRoot 'Prefetch')
$recycleBinGB  = Get-RecycleBinSizeGB

$plannedCleanup = @(
    [PSCustomObject]@{ Location = "User Temp";     EstimatedSpaceGB = $userTempGB }
    [PSCustomObject]@{ Location = "Windows Temp";   EstimatedSpaceGB = $windowsTempGB }
    [PSCustomObject]@{ Location = "Prefetch";       EstimatedSpaceGB = $prefetchGB }
    [PSCustomObject]@{ Location = "Recycle Bin";    EstimatedSpaceGB = $recycleBinGB }
)

$totalEstimatedGB = [math]::Round(($userTempGB + $windowsTempGB + $prefetchGB + $recycleBinGB), 2)

$result = [PSCustomObject]@{
    ComputerName          = $env:COMPUTERNAME
    Timestamp             = (Get-Date).ToString("o")
    DryRun                = $true
    Status                = "Preview"
    EstimatedSpaceRecoveredGB = $totalEstimatedGB
    Message               = if ($totalEstimatedGB -gt 0) {
                                 "No files were deleted. Estimated $totalEstimatedGB GB could be recovered."
                             } else {
                                 "No files were deleted. No significant space was found to clean up."
                             }
    PlannedCleanup        = $plannedCleanup
}

Write-Output ($result | ConvertTo-Json -Depth 3)

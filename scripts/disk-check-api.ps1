$systemDrive = $env:SystemDrive

$drives = Get-CimInstance Win32_LogicalDisk |
Where-Object { $_.DriveType -eq 3 } |
ForEach-Object {

    $free = $_.FreeSpace
    $size = $_.Size

    [PSCustomObject]@{
        ComputerName  = $env:COMPUTERNAME
        Drive         = $_.DeviceID
        IsSystemDrive = ($_.DeviceID -eq $systemDrive)
        TotalGB       = [math]::Round($size / 1GB, 2)
        FreeGB        = [math]::Round($free / 1GB, 2)
        UsedGB        = [math]::Round(($size - $free) / 1GB, 2)
        FreePercent   = [math]::Round(($free / $size) * 100, 1)
    }
}
$output = @($drives) | ConvertTo-Json -Depth 3

# Return JSON directly to FastAPI
Write-Output $output
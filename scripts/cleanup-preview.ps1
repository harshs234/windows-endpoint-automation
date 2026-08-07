$result = [PSCustomObject]@{
    ComputerName = $env:COMPUTERNAME
    Timestamp = (Get-Date).ToString("o")
    DryRun = $true
    Status = "Preview"
    Message = "No files were deleted."
    PlannedCleanup = @(
        "User Temp",
        "Windows Temp",
        "Prefetch",
        "Recycle Bin",
        "Disk Cleanup"
    )
}

Write-Output ($result | ConvertTo-Json -Depth 3)
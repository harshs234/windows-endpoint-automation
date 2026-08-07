$systemDrive = $env:SystemDrive.TrimEnd(':')
$before = (Get-PSDrive $systemDrive).Free
$errors = @()

# User Temp
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +errors

# Windows Temp
Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +errors

# Prefetch
Remove-Item "$env:SystemRoot\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +errors

# Recycle Bin
Clear-RecycleBin -Force -ErrorAction SilentlyContinue -ErrorVariable +errors

# Disk Cleanup — requires 'cleanmgr /sageset:1' pre-configured once per machine/image
Start-Process cleanmgr.exe -ArgumentList "/sagerun:1" -Wait -ErrorAction SilentlyContinue

$after = (Get-PSDrive $systemDrive).Free
$recovered = [math]::Round(($after - $before) / 1GB, 2)

$result = [PSCustomObject]@{
    ComputerName = $env:COMPUTERNAME
    Timestamp    = (Get-Date).ToString("o")
    Drive        = "$systemDrive`:"
    BeforeFreeGB = [math]::Round($before / 1GB, 2)
    AfterFreeGB  = [math]::Round($after / 1GB, 2)
    RecoveredGB  = $recovered
    Status       = if ($recovered -gt 0) { "Cleanup Successful" } else { "No Space Recovered" }
    Errors       = ($errors | ForEach-Object { $_.ToString() } | Select-Object -Unique -First 5)
}

# Still emit to stdout too, in case anything reads it directly
Write-Output ($result | ConvertTo-Json -Depth 3)
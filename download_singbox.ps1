# Download sing-box for Android ARM64
# Run this in PowerShell as a regular user

$assetDir = "E:\workspace\forge-vpn-flutter\assets\binaries"
$url = "https://github.com/SagerNet/sing-box/releases/download/v1.13.14/sing-box-1.13.14-android-arm64.tar.gz"
$archive = "$assetDir\sing-box-arm64.tar.gz"

Write-Host "Downloading sing-box v1.13.14 for Android ARM64..." -ForegroundColor Cyan

# Download
Invoke-WebRequest -Uri $url -OutFile $archive

Write-Host "Extracting..." -ForegroundColor Cyan

# Extract (requires tar.exe, ships with Win10+)
tar -xzf $archive -C $assetDir
Move-Item "$assetDir\sing-box-1.13.14-android-arm64\sing-box" "$assetDir\sing-box-android-arm64" -Force

# Cleanup
Remove-Item "$assetDir\sing-box-1.13.14-android-arm64" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $archive -Force

Write-Host "Done! sing-box binary placed at:" -ForegroundColor Green
Write-Host "  $assetDir\sing-box-android-arm64" -ForegroundColor Green

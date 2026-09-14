# Wyrm Desk — Flutter Web Admin Build & Package Script
Write-Host "Compiling Flutter Web Admin..." -ForegroundColor Cyan

flutter build web -t lib/web_admin_main.dart --base-href / -o assets/web

if ($LASTEXITCODE -eq 0) {
    Write-Host "Flutter Web Admin successfully compiled and packaged into assets/web/!" -ForegroundColor Green
} else {
    Write-Host "Failed to compile Flutter Web Admin." -ForegroundColor Red
}

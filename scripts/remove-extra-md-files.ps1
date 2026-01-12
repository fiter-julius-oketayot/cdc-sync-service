# Remove all .md files except README.md
$projectRoot = Split-Path -Parent $PSScriptRoot
$allMdFiles = Get-ChildItem -Path $projectRoot -Filter "*.md" -Recurse

Write-Host "Found .md files:" -ForegroundColor Yellow
$allMdFiles | ForEach-Object { Write-Host "  $($_.FullName)" -ForegroundColor Gray }

Write-Host "`nRemoving files (keeping README.md at root)..." -ForegroundColor Yellow

$removed = 0
foreach ($file in $allMdFiles) {
    if ($file.Name -ne "README.md" -or $file.Directory.Name -ne "cdc-sync-service") {
        Remove-Item $file.FullName -Force
        Write-Host "  Removed: $($file.Name)" -ForegroundColor Red
        $removed++
    } else {
        Write-Host "  Kept: $($file.Name)" -ForegroundColor Green
    }
}

Write-Host "`nCleanup complete! Removed $removed file(s)" -ForegroundColor Green


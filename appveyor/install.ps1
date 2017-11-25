Write-Host 'Running AppVeyor install script' -ForegroundColor Yellow

Write-Host 'Installing NuGet PackageProvide'
$pkg = Install-PackageProvider -Name NuGet -Force
Write-Host "Installed NuGet version '$($pkg.version)'"

Write-Host 'Installing Pester'
Install-Module -Name Pester -Repository PSGallery -Force

Write-Host 'Installing PSScriptAnalyzer'
Install-Module PSScriptAnalyzer -Repository PSGallery -force
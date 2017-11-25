Write-Host "Running AppVeyor deploy script" -ForegroundColor Yellow

# Update manifest Version
Write-Host "Creating new module manifest"
$ModuleManifestPath = Join-Path -path "$($env:APPVEYOR_BUILD_FOLDER)\$($env:ModuleName)\" -ChildPath ("$env:ModuleName"+'.psd1')
$ModuleManifest     = Get-Content $ModuleManifestPath -Raw
[regex]::replace($ModuleManifest,'(ModuleVersion = )(.*)',"`$1'$env:APPVEYOR_BUILD_VERSION'") | Out-File -LiteralPath $ModuleManifestPath

# Pubklish to PS Gallery
if ($env:APPVEYOR_REPO_BRANCH -notmatch 'master')
{
    Write-Host "Finished testing of branch: $env:APPVEYOR_REPO_BRANCH - Exiting"
    exit;
}

Write-Host 'Publishing module to Powershell Gallery'
Update-PowerShellGallery -Path "$($env:APPVEYOR_BUILD_FOLDER)\$($env:ModuleName)\" -ApiKey $env:NuGetApiKey
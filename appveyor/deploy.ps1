Write-Host "Running AppVeyor deploy script" -ForegroundColor Yellow
Write-Host "Creating new module manifest"
$ModuleManifestPath = Join-Path -path "$($env:APPVEYOR_BUILD_FOLDER)\poshbot.veeam\" -ChildPath ("$env:ModuleName"+'.psd1')
$ModuleManifest = Get-Content $ModuleManifestPath -Raw
[regex]::replace($ModuleManifest,'(ModuleVersion = )(.*)',"`$1'$env:APPVEYOR_BUILD_VERSION'") | Out-File -LiteralPath $ModuleManifestPath
if ($env:APPVEYOR_REPO_BRANCH -notmatch 'master') {
    Write-Host "Finished testing of branch $env:APPVEYOR_REPO_BRANCH - Exiting"
    exit
}
#Update-PowerShellGallery -Path "$($env:APPVEYOR_BUILD_FOLDER)\poshbot.veeam\" -ApiKey $env:NuGetApiKey
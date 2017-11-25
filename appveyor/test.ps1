Write-Host "Running AppVeyor test script" -ForegroundColor Yellow
$res = Invoke-Pester -Path ".\tests" -OutputFormat NUnitXml -OutputFile TestsResults.xml -PassThru
(New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path .\TestsResults.xml))

if (($res.FailedCount -gt 0) -or ($res.PassedCount -eq 0)) {
    throw "$($res.FailedCount) tests failed."
} else {
  Write-Host 'All tests passed' -ForegroundColor Green
}
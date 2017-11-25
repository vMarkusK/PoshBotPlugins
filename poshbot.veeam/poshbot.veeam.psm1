#region: Start Load VEEAM Snapin (if not already loaded)
Add-PSSnapin VeeamPSSnapIn
#endregion

$CommandsToExport = @()

function Get-VeeamRepositories {
        <#
        .SYNOPSIS
        Get Veeam Repositories
        .EXAMPLE
        !Get-VeeamRepositories
        .EXAMPLE
        !Get-VeeamRepositories --brhost <your BR Host>
        .EXAMPLE
        !Repos
        .EXAMPLE
        !VeeamRepositories
        #>

        [PoshBot.BotCommand(
                Aliases = ('Repos', 'VeeamRepositories'),
                Permissions = 'read'
        )]
        [cmdletbinding()]
        param(
                [Parameter(Position=0, Mandatory=$false)]
                [string] $BRHost = "localhost"
        )

        #region: Functions
        Function Get-vPCRepoInfo {
                [CmdletBinding()]
                param (
                        [Parameter(Position=0, ValueFromPipeline=$true)]
                        [PSObject[]]$Repository
                )
                Begin {
                        $outputAry = @()
                        Function New-RepoObject {param($name, $repohost, $path, $free, $total)
                        $repoObj = New-Object -TypeName PSObject -Property @{
                                        Target = $name
                                        RepoHost = $repohost
                                        Storepath = $path
                                        StorageFree = [Math]::Round([Decimal]$free/1GB,2)
                                        StorageTotal = [Math]::Round([Decimal]$total/1GB,2)
                                        FreePercentage = [Math]::Round(($free/$total)*100)
                                }
                                Return $repoObj | Select-Object Target, RepoHost, Storepath, StorageFree, StorageTotal, FreePercentage
                        }
                }
                Process {
                        Foreach ($r in $Repository) {
                                # Refresh Repository Size Info
                                try {
                                        [Veeam.Backup.Core.CBackupRepositoryEx]::SyncSpaceInfoToDb($r, $true)
                                }
                                catch {
                                        Write-Debug "SyncSpaceInfoToDb Failed"
                                }

                                If ($r.HostId -eq "00000000-0000-0000-0000-000000000000") {
                                        $HostName = ""
                                }
                                Else {
                                        $HostName = $($r.GetHost()).Name.ToLower()
                                }
                                $outputObj = New-RepoObject $r.Name $Hostname $r.Path $r.info.CachedFreeSpace $r.Info.CachedTotalSpace
                        }
                        $outputAry += $outputObj
                }
                End {
                        $outputAry
                }
        }
        #endregion

        #region: Start BRHost Connection
        Connect-VBRServer -Server $BRHost
        #endregion

        #region: Collect and filter Repos
        [Array]$repoList = Get-VBRBackupRepository | Where-Object {$_.Type -ne "SanSnapshotOnly"}
        [Array]$scaleouts = Get-VBRBackupRepository -scaleout
        if ($scaleouts) {
                foreach ($scaleout in $scaleouts) {
                        $extents = Get-VBRRepositoryExtent -Repository $scaleout
                        foreach ($ex in $extents) {
                                $repoList = $repoList + $ex.repository
                        }
                }
        }
        #endregion

        #region: Build Report
        $RepoReport = $repoList | Get-vPCRepoInfo | Select-Object       @{Name="Repository Name"; Expression = {$_.Target}},
                                                                        @{Name="Host"; Expression = {$_.RepoHost}},
                                                                        @{Name="Path"; Expression = {$_.Storepath}},
                                                                        @{Name="Free (GB)"; Expression = {$_.StorageFree}},
                                                                        @{Name="Total (GB)"; Expression = {$_.StorageTotal}},
                                                                        @{Name="Free (%)"; Expression = {$_.FreePercentage}}
        forEach ($Repo in $RepoReport) {

                $r = [pscustomobject]@{
                        Name = $($Repo.'Repository Name')
                        'Free (%)' = $($Repo.'Free (%)')
                        'Free (GB)' = $($Repo.'Free (GB)')
                        'Total (GB)' =  $($Repo.'Total (GB)')
                        'Host' =  $($Repo.'Host')
                        'Path' =  $($Repo.'Path')
                    }

                New-PoshBotCardResponse -Title "$($Repo.'Repository Name'):" -Text ($r | Format-List -Property * | Out-String)
        }
        #endregion
}
$CommandsToExport += 'Get-VeeamRepositories'

function Get-VeeamSessions {
                <#
        .SYNOPSIS
        Get Veeam Sessions
        .EXAMPLE
        !Get-VeeamSessions
        .EXAMPLE
        !Get-VeeamSessions --reportMode Monthly
        .EXAMPLE
        !Get-VeeamSessions --brhost <your BR Host>
        .EXAMPLE
        !Sessions
        .EXAMPLE
        !VeeamSessions
        #>

        [PoshBot.BotCommand(
                Aliases = ('Sessions', 'VeeamSessions'),
                Permissions = 'read'
        )]
        [cmdletbinding()]
        param(
                [Parameter(Position=0, Mandatory=$false)]
                        [string] $BRHost = "localhost",
                [Parameter(Position=1, Mandatory=$false)]
                        $reportMode = "24" # Weekly, Monthly as String or Hour as Integer

        )

        #region: Convert mode (timeframe) to hours
        If ($reportMode -eq "Monthly") {
                $HourstoCheck = 720
        } Elseif ($reportMode -eq "Weekly") {
                $HourstoCheck = 168
        } Else {
                $HourstoCheck = $reportMode
        }
        #endregion

        #region: Start BRHost Connection
        Connect-VBRServer -Server $BRHost
        #endregion

        #region: Collect Sessions
        $allSesh = Get-VBRBackupSession         # Get all Sessions (Backup/BackupCopy/Replica)
        $seshListBk = @($allSesh | Where-Object{($_.CreationTime -ge (Get-Date).AddHours(-$HourstoCheck)) -and $_.JobType -eq "Backup"})           # Gather all Backup sessions within timeframe
        $seshListBkc = @($allSesh | Where-Object{($_.CreationTime -ge (Get-Date).AddHours(-$HourstoCheck)) -and $_.JobType -eq "BackupSync"})      # Gather all BackupCopy sessions within timeframe
        $seshListRepl = @($allSesh | Where-Object{($_.CreationTime -ge (Get-Date).AddHours(-$HourstoCheck)) -and $_.JobType -eq "Replica"})        # Gather all Replication sessions within timeframe
        #endregion

        #region: Get Backup session informations
        $TotalBackupTransfer = 0
        $TotalBackupRead = 0
        $seshListBk | ForEach-Object{$TotalBackupTransfer += $([Math]::Round([Decimal]$_.Progress.TransferedSize/1GB, 0))}
        $seshListBk | ForEach-Object{$TotalBackupRead += $([Math]::Round([Decimal]$_.Progress.ReadSize/1GB, 0))}
        #endregion

        #region: Preparing Backup Session Reports
        $successSessionsBk = @($seshListBk | Where-Object{$_.Result -eq "Success"})
        $warningSessionsBk = @($seshListBk | Where-Object{$_.Result -eq "Warning"})
        $failsSessionsBk = @($seshListBk | Where-Object{$_.Result -eq "Failed"})
        $runningSessionsBk = @($allSesh | Where-Object{$_.State -eq "Working" -and $_.JobType -eq "Backup"})
        $failedSessionsBk = @($seshListBk | Where-Object{($_.Result -eq "Failed") -and ($_.WillBeRetried -ne "True")})
        #endregion

        #region:  Preparing Backup Copy Session Reports
        $successSessionsBkC = @($seshListBkC | Where-Object{$_.Result -eq "Success"})
        $warningSessionsBkC = @($seshListBkC | Where-Object{$_.Result -eq "Warning"})
        $failsSessionsBkC = @($seshListBkC | Where-Object{$_.Result -eq "Failed"})
        $runningSessionsBkC = @($allSesh | Where-Object{$_.State -eq "Working" -and $_.JobType -eq "BackupSync"})
        $IdleSessionsBkC = @($allSesh | Where-Object{$_.State -eq "Idle" -and $_.JobType -eq "BackupSync"})
        $failedSessionsBkC = @($seshListBkC | Where-Object{($_.Result -eq "Failed") -and ($_.WillBeRetried -ne "True")})
        #endregion

        #region: Preparing Replicatiom Session Reports
        $successSessionsRepl = @($seshListRepl | Where-Object{$_.Result -eq "Success"})
        $warningSessionsRepl = @($seshListRepl | Where-Object{$_.Result -eq "Warning"})
        $failsSessionsRepl = @($seshListRepl | Where-Object{$_.Result -eq "Failed"})
        $runningSessionsRepl = @($allSesh | Where-Object{$_.State -eq "Working" -and $_.JobType -eq "Replica"})
        $failedSessionsRepl = @($seshListRepl | Where-Object{($_.Result -eq "Failed") -and ($_.WillBeRetried -ne "True")})
        #endregion

        #region: Build Report
        $SessionObject = [PSCustomObject] @{
                "Successful Backups"  = $successSessionsBk.Count
                "Warning Backups" = $warningSessionsBk.Count
                "Failes Backups" = $failsSessionsBk.Count
                "Failed Backups" = $failedSessionsBk.Count
                "Running Backups" = $runningSessionsBk.Count
                "Warning BackupCopys" = $warningSessionsBkC.Count
                "Failes BackupCopys" = $failsSessionsBkC.Count
                "Failed BackupCopys" = $failedSessionsBkC.Count
                "Running BackupCopys" = $runningSessionsBkC.Count
                "Idle BackupCopys" = $IdleSessionsBkC.Count
                "Successful Replications" = $successSessionsRepl.Count
                "Warning Replications" = $warningSessionsRepl.Count
                "Failes Replications" = $failsSessionsRepl.Count
                "Failed Replications" = $failedSessionsRepl.Count
                "Running Replications" = $RunningSessionsRepl.Count
                "Total Backup Transfer" = $TotalBackupTransfer
                "Total Backup Read" = $TotalBackupRead
        }
        $SessionResport += $SessionObject

        New-PoshBotCardResponse -Title "Session Stats for the last $HourstoCheck h:" -Text ($SessionResport | Format-List -Property * | Out-String)
        #endregion
}
$CommandsToExport += 'Get-VeeamSessions'

function Get-VeeamJobs {
        <#
        .SYNOPSIS
        Get Veeam Jobs
        .EXAMPLE
        !Get-VeeamJobs
        .EXAMPLE
        !Get-VeeamJobs --brhost <your BR Host>
        .EXAMPLE
        !Jobs
        .EXAMPLE
        !VeeamJobs
        #>

        [PoshBot.BotCommand(
                Aliases = ('Jobs', 'VeeamJobs'),
                Permissions = 'read'
        )]
        [cmdletbinding()]
        param(
                [Parameter(Position=0, Mandatory=$false)]
                [string] $BRHost = "localhost"
        )

        #region: Start BRHost Connection
        Connect-VBRServer -Server $BRHost
        #endregion

        #region: Collect Jobs
        [Array] $Jobs = Get-VBRJob
        #endregion

        #region: Build Report
        forEach ($Job in $Jobs) {

                $r = [pscustomobject]@{
                        Name = $($Job.'Name')
                        JobType = $($Job.'JobType')
                        IsRunning = $($Job.'IsRunning')
                        IsScheduleEnabled =  $($Job.'IsScheduleEnabled')
                        NextRun =  $($Job.'.ScheduleOptions.StartDateTimeLocal')
                    }

                New-PoshBotCardResponse -Title "$($Job.'Name'):" -Text ($r | Format-List -Property * | Out-String)
        }
        #endregion
}
$CommandsToExport += 'Get-VeeamJobs'

Export-ModuleMember -Function $CommandsToExport
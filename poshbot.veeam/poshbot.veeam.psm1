#region: Start Load VEEAM Snapin (if not already loaded)
Add-PSSnapin VeeamPSSnapIn
#endregion

#region: Private Functions
## Source: https://github.com/tdewin/randomsamples/tree/master/powershell-veeamallstat
class VeeamAllStatJobSessionVM {
    $name
    $status;
    $starttime;
    $endtime;
    $size;
    $read;
    $transferred;
    $duration;
    $details;
    VeeamAllStatJobSessionVM() {}
    VeeamAllStatJobSessionVM($name,$status,$starttime,$endtime,$size,$read,$transferred,$duration,$details) {
        $this.name = $name
        $this.status = $status;
        $this.starttime = $starttime;
        $this.endtime = $endtime;
        $this.size = $size;
        $this.read = $read;
        $this.transferred = $transferred;
        $this.duration  = $duration;
        $this.details = $details
    }
}

class VeeamAllStatJobSession {
    $name = "<no name>"
    $type = "<no type>";
    $description = "";
    $status = "<not run>";
    [System.DateTime]$creationTime='1970-01-01 00:00:00';
    [System.DateTime]$endTime='1970-01-01 00:00:00';
    [System.TimeSpan]$duration
    $processedObjects=0;
    $totalObjects=0
    $totalSize=0
    $backupSize=0
    $dataRead=0
    $transferredSize=0
    $dedupe=0
    $compression=0
    $details=""
    $vmstotal=0
    $vmssuccess=0
    $vmswarning=0
    $vmserror=0
    $allerrors=@{}
    [bool]$hasRan=$true
    [VeeamAllStatJobSessionVM[]]$vmsessions= @()
    VeeamAllStatJobSession() { }
    VeeamAllStatJobSession($name,$type,$description) {
        $this.name = $name
        $this.type = $type;
        $this.description =$description;
    }
    VeeamAllStatJobSession($name,$type,$description,$status,$creationTime,$endtime,$processedObjects,$totalObjects,$totalSize,$backupSize,$dataRead,$transferredSize,$dedupe,$compression,$details) {
        $this.name = $name
        $this.type = $type;
        $this.description =$description;
        $this.status = $status;
        $this.creationTime=$creationTime;
        $this.endTime=$endTime;
        $this.processedObjects=$processedObjects;
        $this.totalObjects=$totalObjects
        $this.totalSize=$totalSize
        $this.backupSize=$backupSize
        $this.dataRead=$dataRead
        $this.transferredSize=$transferredSize
        $this.dedupe=$dedupe
        $this.compression=$compression
        $this.details=$details
        $this.duration=$endTime-$creationTime
    }
}

class VeeamAllStatJobMain {
    $versionVeeam
    $server
    $serverString
    [VeeamAllStatJobSession[]]$jobsessions
    VeeamAllStatJobMain () {
        $this.jobsessions = @()
    }
}



function Get-VeeamAllStatJobSessionVMs {
    param(
        $session,
        [VeeamAllStatJobSession]$statjobsession
    )

    $tasks = $session.GetTaskSessions()

    foreach($task in $tasks) {
        $s = $task.status
        $vm = [VeeamAllStatJobSessionVM]::new(
            $task.Name,
            $s,
            $task.Progress.StartTime,
            $task.Progress.StopTime,
            $task.Progress.ProcessedSize,
            $task.Progress.ReadSize,
            $task.Progress.TransferedSize,
            $task.Progress.Duration,
            $task.GetDetails())

        if ($s -ieq "success") {
            $statjobsession.vmssuccess += 1
        } elseif ($s -ieq "warning" -or $s -ieq "pending" -or $s -ieq "none") {
            $statjobsession.vmswarning +=1
        } else {
            $statjobsession.vmserror += 1
        }
        if ($vm.details -ne "") {
            $statjobsession.allerrors[$task.Name]=$vm.details
        }
        $statjobsession.vmsessions += $vm
        $statjobsession.vmstotal+=1
    }
}

function Get-VeeamAllStatJobSession {
    param(
        $job,
        $session
    )
    $statjob = [VeeamAllStatJobSession]::new(
        $job.Name,
        $session.JobType,
        $job.Description,
        $session.Result,
        $session.CreationTime,
        $session.EndTime,
        $session.Progress.ProcessedObjects,
        $session.Progress.TotalObjects,
        $session.Progress.TotalSize,
        $session.BackupStats.BackupSize,
        $session.Progress.ReadSize,
        $Session.Progress.TransferedSize,
        $session.BackupStats.GetDedupeX(),
        $session.BackupStats.GetCompressX(),
        $session.GetDetails()
    )
    Get-VeeamAllStatJobSessionVMs -session $session -statjobsession $statjob

    if ($session.Result -eq "None" -and $session.JobType -eq "BackupSync") {
        if($session.State -eq "Idle" -and $statjob.vmserror -eq 0 -and $statjob.vmswarning -eq 0 -and $statjob.allerrors.count -eq 0 -and $statjob.details -eq ""  -and $session.EndTime -gt $session.CreationTime ) {
            if ($session.Progress.Percents -eq 100) {
                $statjob.Status="Success"
            }
        }
    }

    return $statjob
}

function Get-VeeamAllStatJobSessions {
    param(
        [VeeamAllStatJobMain]$JobMain
    )

    $allsessions = Get-VBRBackupSession
    $allorderdedsess = $allsessions | Sort-Object -Property CreationTimeUTC -Descending
    $jobs = get-vbrjob

    foreach ($Job in $Jobs) {
        $lastsession = $allorderdedsess | ? { $_.jobid -eq $Job.id } | select -First 1
        if ($lastsession -ne $null) {
           $JobMain.jobsessions += Get-VeeamAllStatJobSession -job $job -session $lastsession
        } else {
           $s = [VeeamAllStatJobSession]::new($job.Name,$job.type,$job.description)
           $s.hasRan = $false
           $JobMain.jobsessions += $s
        }
    }

}

function Get-VeeamAllStatServerVersion {
    param(
        [VeeamAllStatJobMain]$JobMain
    )
    $versionstring = "Unknown Version"

    $pssversion = (Get-PSSnapin VeeamPSSnapin -ErrorAction SilentlyContinue)
    if ($pssversion -ne $null) {
        $versionstring = ("{0}.{1}" -f $pssversion.Version.Major,$pssversion.Version.Minor)
    }

    $corePath = Get-ItemProperty -Path "HKLM:\Software\Veeam\Veeam Backup and Replication\" -Name "CorePath" -ErrorAction SilentlyContinue
    if ($corePath -ne $null) {
        $depDLLPath = Join-Path -Path $corePath.CorePath -ChildPath "Packages\VeeamDeploymentDll.dll" -Resolve -ErrorAction SilentlyContinue
        if ($depDLLPath -ne $null -and (Test-Path -Path $depDLLPath)) {
            $file = Get-Item -Path $depDLLPath -ErrorAction SilentlyContinue
            if ($file -ne $null) {
                $versionstring = $file.VersionInfo.ProductVersion
            }
        }
    }

    $servsession = Get-VBRServerSession
    $JobMain.versionVeeam = $versionstring
    $JobMain.server = $servsession.server
    $JobMain.serverString = ("Server {0} : Veeam Backup & Replication {1}" -f $servsession.server,$versionstring)
}

function Get-VeeamAllStat {
    $report = [VeeamAllStatJobMain]::new()

    Get-VeeamAllStatServerVersion -JobMain $report
    Get-VeeamAllStatJobSessions -JobMain $report
    return $report
}

function Get-HumanDataSize {
 param([double]$numc)
 $num = $numc+0
 $trailing= "","K","M","G","T","P","E"
 $i=0
 while($num -gt 1024 -and $i -lt 6) {
  $num= $num/1024
  $i++
 }
 return ("{0:f1} {1}B" -f $num,$trailing[$i])
}

function Get-HumanDate {
    param([DateTime]$t)
    return $t.toString("yyyy-MM-dd HH:mm:ss")
}

function Get-HumanDuration {
    param([System.TimeSpan]$d)
    return ("{0:D2}:{1:D2}:{2:D2}" -f ($d.Hours+($d.Days*24)),$d.Minutes,$d.Seconds)
}
#endregion

#region: Public Functions
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

function Get-VeeamJobSessions {
                <#
        .SYNOPSIS
        Get last Veeam Job Sessions
        .EXAMPLE
        !Get-VeeamJobSessions
        .EXAMPLE
        !Get-VeeamJobSessions --brhost <your BR Host>
        .EXAMPLE
        !JobSessions
        .EXAMPLE
        !VeeamJobSessions
        #>

        [PoshBot.BotCommand(
                Aliases = ('JobSessions', 'VeeamJobSessions'),
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

        #region: Collect Sessions
        $Stats = (Get-VeeamAllStat).jobsessions
        #endregion

        #region: Build Report
        forEach ($Stat in $Stats) {

                                $r = [pscustomobject]@{
                                        JobName = $Stat.name
                                        JobType = $Stat.type
                                        HasRan = $Stat.hasRan
                                        JobStatus = $Stat.status
                                        CreationTime  = $Stat.creationTime
                                        EndTime  = $Stat.endTime
                                        VMsTotal = $Stat.vmstotal
                                        VMsSuccess = $Stat.vmssuccess
                                        VMsWarning = $Stat.vmswarning
                                        VMsError  = $Stat.vmserror
                                    }

                                New-PoshBotCardResponse -Title "Job '$($Stat.name)' Stats:" -Text ($r | Format-List -Property * | Out-String)
                                }
        #endregion
}
$CommandsToExport += 'Get-VeeamJobSessions'

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
        $report = @()
        forEach ($Job in $Jobs) {

                $object = [pscustomobject]@{
                        Name = $Job.Name
                        JobType = $Job.JobType
                    }
                $report += $object

                New-PoshBotCardResponse -Title "Veeam Jobs:" -Text ($report | Format-List -Property * | Out-String)
        }
        #endregion
}
$CommandsToExport += 'Get-VeeamJobs'

Export-ModuleMember -Function $CommandsToExport
#endregsion
function Start-VeeamPoshBot ($token) {
    Import-Module -Name PoshBot
    $botParams = @{
        Name = 'veeambot'
        BotAdmins = @('vmarkus_k')
        CommandPrefix = '!'
        LogLevel = 'Verbose'
        BackendConfiguration = @{
            Name = 'SlackBackend'
            Token = $token
        }
        AlternateCommandPrefixes = 'bender', 'hal'
    }

    $myBotConfig = New-PoshBotConfiguration @botParams

    Start-PoshBot -Configuration $myBotConfig
}

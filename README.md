PoshBotPlugins PowerShell Project
=============
[![Flattr this git repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=vMarkus_K&url=https://github.com/mycloudrevolution/PoshBotPlugins&title=PoshBotPlugins&language=Powershell&tags=github&category=software)
[![Build status](https://ci.appveyor.com/api/projects/status/ne1f3ta0cri18gkn?svg=true)](https://ci.appveyor.com/project/mycloudrevolution/poshbotplugins)
# About

## Project Owner:

Markus Kraus [@vMarkus_K](https://twitter.com/vMarkus_K)

MY CLOUD-(R)EVOLUTION [mycloudrevolution.com](http://mycloudrevolution.com/)

## Project WebSite:

[Veeam Plugin for PoshBot chat bot](https://mycloudrevolution.com/2017/11/27/veeam-plugin-for-poshbot-chat-bot/)

## Project Description:

The 'PoshBotPlugins' GitHub Repository contains my Plugins for the [PoshBot](https://github.com/poshbotio/PoshBot) chat bot.

# Plugins

## poshbot.veeam

Visit this blog post for [Plugin Details](https://mycloudrevolution.com/2017/11/27/veeam-plugin-for-poshbot-chat-bot/).

**Install Plugin:**

```powershell
!install-plugin poshbot.veeam
```

**Update Plugin:**

```powershell
!update-plugin poshbot.veeam
```

**Please Note:** if you upgrade from Version 0.2.1 or older to Version 0.2.2 or newer, update will fail. Please remove plugin from PoshBot and then uninstall all Module Versions before you install the actual Plugin Version.
___
### Get-VeeamRepositories

![Get-VeeamRepositories](/media/Get-VeeamRepositories.png)

### Get-VeeamJobSessions

![Get-VeeamSessions](/media/Get-VeeamJobSessions.png)

Job details:

![Get-VeeamSessions_Detail](/media/Get-VeeamJobSessions_Detail.png)

Big thanks to [Timothy Dewin](https://twitter.com/tdewin) for his great [PowerShell-VeeamAllStats](https://github.com/tdewin/randomsamples/tree/master/powershell-veeamallstat) PowerShell Module which is used to generate the Output for this Command.
### Get-VeeamJobs

![Get-VeeamJobs](/media/Get-VeeamJobs.png)

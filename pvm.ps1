<#

.DESCRIPTION
PHP Version Manager.

.SYNOPSIS
Author: Chenmobuys
License: MIT
Version: 1.0.0

.LINK
https://github.com/chenmobuys/pvm

#>
param (
    [string]$Command
)

function Pvm-Default() {
    Pvm-Help
}

function Pvm-Help() {
    Write-Host "Usage:"
    Write-Host "  pvm help                 :  Show help."
    Write-Host "  pvm init                 :  Initialize when using for the first time."
    Write-Host "  pvm list                 :  List exists versions."
    Write-Host "  pvm installed            :  List installed versions."
    Write-Host "  pvm use <version>        :  Use specify version."
    Write-Host "  pvm install <version>    :  Install specify version. "
    Write-Host "  pvm uninstall <version>  :  Uninstall specify version."
    Write-Host ""
}

function Pvm-Init() {

    $PVM_HOME = Get-PSScriptRoot
    $PVM_SYMLINK = ((Get-PSScriptRoot),"\php") -Join ""

    $EnvironmentRegisterKey = "HKLM:\SYSTEM\ControlSet001\Control\Session Manager\Environment\"

    $Path = (Get-Item -Path $EnvironmentRegisterKey).GetValue(
        "PATH",
        "",
        [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)

    if ($Path.EndsWith(";")) {
        $Path = $Path.Remove($Path.length - 1, 1)
    }

    $Paths = $Path -Split ";"

    $NeedUpdateEnvironment = $False

    if($Paths -NotContains "%PVM_HOME%") {
        $NeedUpdateEnvironment = $True
        $Path = "$Path;%PVM_HOME%"
    }

    if($Paths -NotContains "%PVM_SYMLINK%") {
        $NeedUpdateEnvironment = $True
        $Path = "$Path;%PVM_SYMLINK%"
    }

    if($NeedUpdateEnvironment) {
        $Path = "$Path;"
        $Commands = (
            "(Set-ItemProperty -Path '$EnvironmentRegisterKey' -Name PVM_HOME -Value '$PVM_HOME')",
            "(Set-ItemProperty -Path '$EnvironmentRegisterKey' -Name PVM_SYMLINK -Value '$PVM_SYMLINK')",
            "(Set-ItemProperty -Path '$EnvironmentRegisterKey' -Name PATH -Value '$Path')"
        )
        $Command = $Commands -Join " -or "

        Start-Process -Verb RunAs -WindowStyle "Hidden" -Filepath powershell -Argument "$Command"
        
        Write-Host "Write Environment [PVM_HOME,PVM_SYMLINK,PATH] Success."
    } else {
        Write-Host "Environment Already Exists, Nothing Change."
    }
}

function Pvm-List() {

    $Html = Invoke-WebRequest -Uri "https://windows.php.net/downloads/releases/archives/"
    $M = Select-String -InputObject $Html -Pattern '(downloads/releases/archives)/php-\d+.\d+.\d+-nts-Win32-(vs|vc|VC)\d{1,2}-x86?(.zip)' -AllMatches

    $Maps = @{}

    foreach($Match in $M.Matches) {
          $Basename = $Match -Replace "downloads/releases/archives/php-",""
          $MatchSplit1 = $Basename.Split("-")
          $MatchSplit2 = $MatchSplit1[0].Split(".")
          $Version = ($MatchSplit2[0],$MatchSplit2[1]) -Join "."
          if(!$Maps.ContainsKey($MatchSplit2[0])) {
            $Maps.add($MatchSplit2[0], @())
          }
          if($Maps[$MatchSplit2[0]] -notcontains $Version) {
            $Maps[$MatchSplit2[0]]+=$Version
          }
    }

    Write-Host "Exists Versions:"
    foreach($Key in ($Maps.Keys | Sort-Object)) {
        Write-Host " "($Maps[$Key] -Join ", ")
    }
    Write-Host ""
}

function Pvm-Installed() {

    $Location = Get-PSScriptRoot
    $LocationRegex = [Regex]::Escape(($Location,"\") -Join "")
    $SymbolicLinkPath = $Location,"\php" -Join ""
    if(Test-Path -Path $SymbolicLinkPath) {
        $SymbolicLinkTarget = ( (Get-Item $SymbolicLinkPath) | Select-Object -ExpandProperty Target) -Replace $LocationRegex,""
    } else {
        $SymbolicLinkTarget = ""
    }
    
    Write-Host "Installed Versions:"
    foreach($Directory in (Get-ChildItem -Directory $Location | Sort-Object)) {
        if(Select-String -InputObject $Directory -Pattern 'php-\d+.\d+.\d+') {
            $BaseDirectory = $Directory -Replace $LocationRegex,""
            $Version = ($BaseDirectory -Replace "-Win32-.*") -Replace "php-",""
            if($SymbolicLinkTarget -eq $BaseDirectory) {
                Write-Host " * $Version"
            } else {
                 Write-Host "   $Version"
            }
        }
    }
    Write-Host ""
}

function Pvm-Use([string]$Version) {

    $VersionInfo = Get-Version $Version
    $ExistsVersion = Pvm-Install $Version -ReturnPath

    if($ExistsVersion) {
        Pvm-Link $ExistsVersion
        Write-Host "Use $Version Success."
    } else {
        Write-Error "Use Version $Version Failed."
    }
}

function Pvm-Install([string]$Version,[switch]$ReturnPath) {
    $Location = Get-PSScriptRoot
    $TempLocation = ($Location,"\tmp\") -Join ""
    $VersionInfo = Get-Version $Version
    $VersionInfoLength = ($VersionInfo[0,1,2] | Where-Object { ![String]::IsNullOrEmpty($_) }).Length
    $ExistsVersion = Get-ExistsVersion $VersionInfo

    if($ExistsVersion) {
        Write-Host "Version $Version Exists."
        if($ReturnPath) {
            return $ExistsVersion
        }
        return
    }

    if(!(Test-Path $TempLocation))
    {
        New-Item -ItemType Directory -Force -Path $TempLocation | Out-Null
    }

    $Html = Invoke-WebRequest -Uri "https://windows.php.net/downloads/releases/archives/"
    $M = Select-String -InputObject $Html -Pattern '(downloads/releases/archives)/php-\d+.\d+.\d+-nts-Win32-(vs|vc|VC)\d{1,3}-x86?(.zip)' -AllMatches
    $Maps = @{}

    $BaseDownloadUrl = Get-DownloadUrl $M $VersionInfo

    if($BaseDownloadUrl) {
        if($VersionInfo[3] -eq $False) {
            $BaseDownloadUrl = $BaseDownloadUrl -Replace "-nts",""
        }
        if($VersionInfo[4] -eq "x64") {
            $BaseDownloadUrl = $BaseDownloadUrl -Replace "x86","x64"
        }
        $DownloadUrl = ("https://windows.php.net/",$BaseDownloadUrl) -Join ""
        $SaveFilename = $BaseDownloadUrl -Replace "downloads/releases/archives/",""
        $VersionFullName = $SaveFilename -Replace ".zip",""
        $SaveDirectory = ($Location, "\", $VersionFullName) -Join ""
        $TempFilepath = ($TempLocation, $SaveFilename) -Join ""
        if(!(Test-Path -Path $TempFilepath)) {
            Write-Host "Downloading Version $VersionFullName ..."
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempFilepath
            Write-Host "Download Success."
        }
        Write-Host $TempFilepath
        Write-Host "Extracting..."

        $Error.Clear()
        Try {
            Expand-Archive -Path $TempFilepath -DestinationPath $SaveDirectory | Out-Null
            Write-Host "Extract Success."
            Write-Host "Install Version $Version Success."

            if($ReturnPath) {
                return ($SaveFilename -Replace ".zip","")
            }
            return
        } Catch {
            Remove-Item -Path $TempFilepath -Recurse -Force
            Remove-Item -Path $SaveDirectory -Recurse -Force 
            Write-Warning "Extract Failed, Please Retry."
        }
    }

    Write-Error "Install PHP Version $Version Failed."
}

function Get-DownloadUrl($M, $VersionInfo) {
     foreach($Match in ($M.Matches | Sort-Object -Descending)) {
        $Basename = $Match -Replace "downloads/releases/archives/php-",""
        $CurrentVersionInfo = Get-Version $Basename

        switch($VersionInfoLength) {
            0 {
                return $Match
            }
            1 {
                if($CurrentVersionInfo[0] -eq $VersionInfo[0]) {
                    return $Match;
                }
            }
            2 {
                if($CurrentVersionInfo[0] -eq $VersionInfo[0] -and $CurrentVersionInfo[1] -eq $VersionInfo[1]) {
                    return $Match;
                }
            }
            3 {
                if(
                    $CurrentVersionInfo[0] -eq $VersionInfo[0] -and $CurrentVersionInfo[1] -eq $VersionInfo[1] -and $CurrentVersionInfo[2] -eq $VersionInfo[2]
                ) {
                    return $Match;
                }
            }
        }
    }

    return
}

function Pvm-Version() {
    Write-Host ""
    Write-Host "PVM version 1.0.0."
    Write-Host ""
}

function Pvm-Uninstall([string]$Version) {
   $VersionInfo = Get-Version $Version
   $ExistsVersion = Get-ExistsVersion $VersionInfo
   if(Test-Path -Path $ExistsVersion) {
        Remove-Item -Path $ExistsVersion -Recurse -Force
        Write-Host "Uninstall $Version Success."
   } else {
        Write-Error "Uninstall $Version Failed."
   }
}

function Get-Version([string]$Version) {
    $NTS = $False
    $ARCH = "x86"
    $Is64BitOS = Check-Is64BitOS
    if($Version -match "-") {
        $Versions = $Version.Split("-")
        $NTS = $Versions[1] -eq "nts"
        $Version = $Versions[0]
    }
    if($Is64BitOS) {
        $ARCH = "x64"
    }
    $Versions = $Version.Split(".")
    $MajorVersion = $Versions[0]
    $MinorVersion = $Versions[1]
    $PatchVersion = $Versions[2]

    "$MajorVersion"
    "$MinorVersion"
    "$PatchVersion"
    "$NTS"
    "$ARCH"
}

function Get-ExistsVersion($VersionInfo) {
   $Location = Get-PSScriptRoot
   $LocationRegex = [Regex]::Escape(($Location,"\") -Join "")
   $VersionInfoLength = ($VersionInfo[0,1,2] | Where-Object { ![String]::IsNullOrEmpty($_) }).Length
   foreach($Directory in (Get-ChildItem -Directory $Location | Sort-Object -Descending)) {
       if(Select-String -InputObject $Directory -Pattern 'php-\d+.\d+.\d+') {
            $CurrentVersionInfo = Get-Version (($Directory -Replace $LocationRegex,"") -Replace "php-","")

            $Directory = ($Location,$Directory) -Join "\"

            if(!($CurrentVersionInfo[3] -eq $VersionInfo[3] -and $CurrentVersionInfo[4] -eq $VersionInfo[4])) {
                Continue
            }

            switch($VersionInfoLength) {
                0 {
                    return $Directory
                }
                1 {
                    if($CurrentVersionInfo[0] -eq $VersionInfo[0]) {
                        return $Directory;
                    }
                }
                2 {
                    if($CurrentVersionInfo[0] -eq $VersionInfo[0] -and $CurrentVersionInfo[1] -eq $VersionInfo[1]) {
                        return $Directory;
                    }
                }
                3 {
                    if(
                        $CurrentVersionInfo[0] -eq $VersionInfo[0] -and $CurrentVersionInfo[1] -eq $VersionInfo[1] -and $CurrentVersionInfo[2] -eq $VersionInfo[2]
                    ) {
                        
                        return $Directory;
                    }
                }
            }
       }
   }

   return $False;
}

function Check-Is64BitOS() {
    return [Environment]::Is64BitOperatingSystem
}

function Pvm-Link($Target) {

    $PVM_HOME = Get-PSScriptRoot
    $PVM_SYMLINK = ((Get-PSScriptRoot),"\php") -Join ""

    Start-Process -Verb RunAs -WindowStyle "Hidden" -Filepath powershell -Argument "New-Item -ItemType SymbolicLink -Path $PVM_SYMLINK -Target $Target -Force"

}

function Get-PSScriptRoot() {
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript")
    { 
        $PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition 
    } else { 
        $PSScriptRoot = $MyInvocation.PSScriptRoot
        if(!$PSScriptRoot) {
            $PSScriptRoot = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0]) 
        }
        if (!$PSScriptRoot){ 
            $PSScriptRoot = "." 
        }
    }

    return $PSScriptRoot
}

Pvm-Version

switch($Command) {
    help {
        Pvm-Help
    }
    list {
        Pvm-List
    }
    init {
        Pvm-Init
    }
    installed {
        Pvm-Installed
    }
    use {
        Pvm-Use $args[0]
    }
    install {
        Pvm-Install $args[0]
    }
    uninstall {
        Pvm-Uninstall $args[0]
    }   
    Default {
        Pvm-Default
    }
}

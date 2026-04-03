#Requires -Version 5.1
# Same as: .\docker-local.ps1 -Prebuilt ...
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$ScriptDir\docker-local.ps1" -Prebuilt @args

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart

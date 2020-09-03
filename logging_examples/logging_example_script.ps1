Set-StrictMode -Version 2.0
Set-StrictMode -Off

$InformationPreference = "Continue"
$VerbosePreference = "Continue"
$DebugPreference = "Continue"

. ./logging.ps1

$LogFilepath = "c:/var/log/ms_shell_logging_$(Get-Date -UFormat "%Y-%m-%d").log"

Write-Log -SeverityLevel "error" "This is an error" -LogFilepath $LogFilepath

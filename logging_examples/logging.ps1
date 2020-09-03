Set-StrictMode -Version 2.0
Set-StrictMode -Off

function Write-Log {
    [CmdletBinding()]
    Param (
        [Parameter()]
        [System.IO.FileInfo]$LogFilepath,

        [parameter()]
        [Switch]$NoEventLog,

        [Parameter()]
        [string]$LogName = "Scripts",

        [Parameter()]
        [ValidatePattern(".+\..+")]
        [string]$SourceName,

        [parameter()]
        [Int]$EventID = 1,

        [parameter(Mandatory)]
        [ValidateSet("emergency", "alert", "critical", "error", "warning", "notice", "informational", "debug")]
        [string] $SeverityLevel,

        [Parameter(Mandatory, Position=0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    ## https://en.wikipedia.org/wiki/Syslog#Severity_level
    ## https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.eventlogentrytype?view=netframework-4.8
    $SeverityLevel_to_EntryType = @{
        "emergency"     = "error"
        "alert"         = "error"
        "critical"      = "error"
        "error"         = "error"
        "warning"       = "warning"
        "notice"        = "information"
        "informational" = "information"
        "debug"         = "information"
    }
    $EntryType = $SeverityLevel_to_EntryType[$SeverityLevel]

    if (!$PSBoundParameters.ContainsKey('SourceName')) {
        function ScriptName() { return Split-Path $MyInvocation.PSCommandPath -Leaf; }
        $ScriptName = $(ScriptName)
        if ([string]::IsNullOrWhiteSpace($ScriptName)) {
            $SourceName = "Unknown"
        } else {
            $SourceName = $ScriptName
        }
    }

    $Line = $MyInvocation.ScriptLineNumber
    $ConsoleMessage = "Line: $Line, EventID: $EventID, Severity: $SeverityLevel, $Message"
    switch ($SeverityLevel) {
        { $_ -in "emergency", "alert", "critical", "error" } {
            Write-Error $ConsoleMessage
        }
        "warning" {
            Write-Warning $ConsoleMessage
        }
        { $_ -in "notice", "information" } {
            Write-Information $ConsoleMessage
        }
        "debug" {
            Write-Verbose $ConsoleMessage
        }
    }

    if ($PSBoundParameters.ContainsKey('LogFilepath')) {
        $LogTimestamp = Get-Date -Format "o"
        $CsvRowObject = New-Object PSObject
        $CsvRowObject | Add-Member -MemberType NoteProperty -Name "LogTimestamp" -Value $LogTimestamp
        $CsvRowObject | Add-Member -MemberType NoteProperty -Name "Line" -Value $Line
        $CsvRowObject | Add-Member -MemberType NoteProperty -Name "EventID" -Value $EventID
        $CsvRowObject | Add-Member -MemberType NoteProperty -Name "SeverityLevel" -Value $SeverityLevel
        $CsvRowObject | Add-Member -MemberType NoteProperty -Name "Message" -Value $Message

        $LogDirpath = Split-Path $LogFilepath.ToString() -Parent
        New-Item -ItemType Directory -Force -Path $LogDirpath | Out-Null
        $CsvRowObject | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File -Append $LogFilepath -Encoding UTF8
    }

    $RegisteredInEventLog = $false
    try {
        $RegisteredInEventLog = [System.Diagnostics.EventLog]::Exists($LogName) -and [System.Diagnostics.EventLog]::SourceExists($SourceName)
    } catch [System.Security.SecurityException] {
        Write-Host "Exception occurred: $PSItem"
        $RegisteredInEventLog = $false
    } catch {
        Write-Warning "Exception occurred: $PSItem"
        $RegisteredInEventLog = $false
    }

    if (-not $RegisteredInEventLog) {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $true){
            New-EventLog -LogName $LogName -Source $SourceName
        } else{
            Write-Warning "You don’t have administrator privileges. You might need to add the source with: New-EventLog -LogName '$LogName' -Source '$SourceName'."
            Return
        }
    }

    if ($NoEventLog -eq $false) {
        ## TODO: Include all event metadata as Eventlog event_data (XML).
        $EventLogMessage = "$Message$([Environment]::NewLine)Line: $Line"
        Write-EventLog -LogName $LogName -Source $SourceName -EventId $EventID -EntryType $EntryType -Message $EventLogMessage
    }
}

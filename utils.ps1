# 
# utils.ps1
# Utility functions for Simple Hosting Installer.
#
# Author: Jiri Skoda <jiri.skoda@upce.cz>
#         Faculty of Electrical Engineering
#         University of Pardubice
#         2024, Pardubice
#

<#
    .SYNOPSIS
        Prints text in predefined format.
    .DESCRIPTION
        Prints text with limitations defined by actual script constants
        and with predefined format.
#>
function Print-Text{
    param(

        # Type of text (aka character defining type of text; some unicode emoji recommended here)
        [Parameter(Mandatory = $true)]
        [string]$type,

        # Content of text itself.
        [Parameter(Mandatory = $true)]
        [string]$content,

        [Parameter(Mandatory = $false)]
        [ConsoleColor]$color = [ConsoleColor]::White
    )

    Write-Host -NoNewLine "$type "
    $remainingWidth = $OutWidth - $type.Length - 1
    $contentParts = $content -split '\s+'

    $printedWidth = 0
    foreach($part in $contentParts){
        if(($printedWidth + $part.Length) -lt $remainingWidth){
            Write-Host -ForegroundColor $color -NoNewLine "$part "
            $printedWidth += $part.Length + 1
        }
        else {
            Write-Host -ForegroundColor $color ""
            Write-Host -ForegroundColor $color -NoNewLine (" " * ($type.Length + 1))
            Write-Host -ForegroundColor $color -NoNewLine "$part "
            $printedWidth = $part.Length + 1
        }
    }
    Write-Host -ForegroundColor $color ""
}

<#
    .SYNOPSIS
        Prints one single process step.
    .DESCRIPTION
        Prints text of process step and leaves space for mark of progress of step.
#>
function Print-Process{
    param(

        # Text of process step.
        [Parameter(Mandatory = $true)]
        [string]$text
    )

    $end = "... "
    $width = $OutWidth - ($end.Length + 1)
    $text = "$text$end"
    $parts = $text -split '\s+'
    $curr = ""
    $lines = @()
    foreach($part in $parts){
        if(($curr + $part).Length -le $width){
            $curr += "$part "
        }
        else{
            $lines += $curr.Trim()
            $curr = "$part "
        }
    }
    $lines += $curr.Trim()

    for ($i = 0; $i -lt ($lines.Count - 2); $i++){
        Write-Host $lines[$i]
    }

    $lines[0..($lines.Count - 2)] | ForEach-Object{
        #Write-Host $_
    }
    Write-Host -NoNewLine $lines[-1]
    $spaces = ($OutWidth - 1) - $lines[-1].Length
    if ($spaces -gt 0){
        for($i = 0; $i -lt $spaces; $i++){
            Write-Host -NoNewLine " "
        }
    }
    

}

<#
    .SYNOPSIS
        Prints elapsed time.
    .DESCRIPTION
        Prints elapsed time (stored in TimeSpan) in more human readable way.
#>
function Print-Elapsed{

    param(

        # Elapsed time which will be printed.
        [Parameter(Mandatory = $true)]
        [timespan]$time
    )

    if ($time.TotalSeconds -lt 60){
        Write-Host ("{0:N2} seconds" -f $time.TotalSeconds)
    }
    elseif ($time.TotalMinutes -lt 60){
        Write-Host ("{0:N0} minutes {1:N0} seconds" -f $time.TotalMinutes, $time.Seconds)
    }
    else{
        Write-Host ("{0:N0} hours {1:N0} minutes {2:N0} seconds" -f $time.TotalHours, $time.Minutes, $time.Seconds)
    }

}

<#
    .SYNOPSIS
        Ensures user to confirm actual action.
    .DESCRIPTION
        Reads users input. If it is 'yes' in any meaning, this function returns TRUE.
        If read input is not 'yes' (or any similar input), this function returns FALSE.
#>
function Get-UserConfirmation{
    $input = Read-Host " (yes/NO)"
    $confirmation = $input.ToUpper() -eq "YES" -or $input.ToUpper() -eq "Y"
    return $confirmation
}

<#
    .SYNOPSIS
        Exits script execution.
    .DESCRIPTION
        Exits script execution with provided details. Informs user about execution time,
        exit message and exit code.
#>
function Exit-Script{
    param(

        # Date and time of start of execution of script.
        [Parameter(Mandatory=$true)]
        [datetime]$start,

        # Exit code of script.
        [Parameter(Mandatory=$true)]
        [int]$code,

        # Exit message of script.
        [Parameter(Mandatory=$true)]
        [string]$message
    )

    Write-Host ""
    Write-Host $message
    Write-Host ""

    $end = Get-Date
    $exec = $end - $start
    Write-Host -NoNewLine "Script execution finished in: "
    Print-Elapsed -time $exec
    Write-Host -NoNewLine "Script exited with code: "
    if ($code -eq 0){
        Write-Host -NoNewLine "🟢 "
    }
    else{
        Write-Host -NoNewLine "🔴 "
    }
    Write-Host $code

    Exit $code
}

<#
    .SYNOPSIS
        Executes a command.
    .DESCRIPTION
        Performs execution of command. If execution has been successfull,
        returns TRUE, otherwise returns FALSE.
#>
function Execute-Command{

    param(

        # Command which will be executed.
        [Parameter(Mandatory = $true)]
        [string]$command,

        # Session in which command will be executed.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession]$session
    )

    $reti = Invoke-Command -ErrorAction SilentlyContinue -Session $session -ScriptBlock {
        param($cmd)
        $res = Invoke-Expression -Command $cmd
        $exit = $LASTEXITCODE
        $exit
    } -ArgumentList $command

    return ($reti -eq 0)
}

<#
    .SYNOPSIS
        Requests execution of command.
    .DESCRIPTION
        Requests execution of passed command. If execution fails (eg. return value
        of commaind is not 0), program exits with passed exit code and exit message.
#>
function Request-Command{

    param(

        # Description of command.
        [Parameter(Mandatory = $true)]
        [string]$description,

        # Character displaying successfull execution of command.
        [Parameter(Mandatory = $true)]
        [string]$successStr,

        # Character displaying fail of execution of command.
        [Parameter(Mandatory = $true)]
        [string]$failStr,

        # Command which will be executed.
        [Parameter(Mandatory = $true)]
        [string]$command,

        # Session in which command will be executed.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession]$session,

        # Time of start of execution of script.
        [Parameter(Mandatory = $true)]
        [DateTime]$start,

        # Exit code if command execution fails.
        [Parameter(Mandatory = $true)]
        [int]$exitCode,

        # Exit message if command execution fails.
        [Parameter(Mandatory = $true)]
        [string]$exitMessage
    )

    Print-Process -text $description
    if (Execute-Command -command $command -session $session){
        Write-Host "$successStr"
    }
    else{
        Write-Host "$failStr"
        Remove-PSSession -Session $session
        Exit-Script -start $start -code $exitCode -message $exitMessage
    }
}

<#
    .SYNOPSIS
        Executes multiple commands.
    .DESCRIPTION
        Runs multiple commands in one batch. If execution
        fails, whole script will be exited.
#>
function Run-Batch{
    param(

        # Array of arrays with commands which will be executed.
        # Expected format: (('description 1', 'command 1', 'exit message 1'), ('description 2', 'command 2', 'exit message 2'),...)
        [Parameter(Mandatory = $true)]
        [string[][]]$batch,

        # Session in which commands will be executed.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession]$session,

        # Character displaying successfull execution of command.
        [Parameter(Mandatory = $true)]
        [string]$successStr,

        # Character displaying fail of execution of command.
        [Parameter(Mandatory = $true)]
        [string]$failStr,

        # Time of start of execution of script.
        [Parameter(Mandatory = $true)]
        [DateTime]$start,

        # Exit code of first command (if failed).
        [Parameter(Mandatory = $true)]
        [int]$exitCode
    )

    $ex = $exitCode
    foreach($entry in $batch){
        Request-Command -description $entry[0] -command $entry[1] -exitMessage $entry[2] -exitCode $ex -session $session -start $start -successStr $successStr -failStr $failStr
        $ex = $ex + 1
    }
}

<#
    .SYNOPSIS
        Check, whether input is IP address.
    .DESCRIPTION
        Checks input if it matches IP address format.
        If yes, returns TRUE, otherwise returns FALSE.
#>
function Is-IPAddress{

    param(

        # String which will be checked.
        [Parameter(Mandatory = $true)]
        [string]$str
    )
    
    $str = $str.Trim()
    $reti = $true
    try{
        [ipaddress]$str
    }
    catch{
        $reti = $false
        Write-Host $_
    }
    return $reti
}

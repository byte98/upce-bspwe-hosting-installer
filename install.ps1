#!/usr/bin/env pwsh

# 
# install.ps1
# Installer of Simple Hosting application.
#
# Author: Jiri Skoda <jiri.skoda@upce.cz>
#         Faculty of Electrical Engineering
#         University of Pardubice
#         2024, Pardubice
#

# Start timer
$startTime = Get-Date

# Print initial information
Write-Host "Simple Hosting Installer"
Write-Host "Start of execution: $startTime"
Write-Host ""



# Global configuration of installation process

# Character of successfull step of process
$success = "✅"

# Character of failed step of process
$fail = "❌"

# Width of output
New-Variable -Name OutWidth -Value 64 -Option Constant

# Import utility file
. ".\utils.ps1"

# Check if there is .NET installed
Print-Process -text "Checking, whether .NET is installed"
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if ($dotnet){
    Write-Host $success
}
else
{
    Write-Host $fail 
    Exit-Script -start $startTime -code 1 -message "❗️ ERROR: .NET installation was not found! Before continue, please, install .NET framework."
}






# Installation script itself
Print-Text -type "ℹ️ " -content "This script requires SSH service on the server installed and running."
Print-Text -type "❔" -content "Is SSH service on server running?"
if (Get-UserConfirmation){ # User declared SSH installed and running

    Print-Text -type "ℹ️ " -content "Installer requires PowerShell installed on the server. Installation can be done by following command: 'sudo dnf install https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/powershell-7.4.1-1.rh.x86_64.rpm'."
    Print-Text -type "❔" -content "Is PowerShell installed on server?"
    if (Get-UserConfirmation){ # User declared PowerShell installed

        Print-Text -type "ℹ️ " -content "This script can continue only if PowerShell is configured as subsystem of SSH."
        Print-Text -type "❔" -content "Is PowerShell configured as subsystem of SSH? Option 'NO' will display help how to achieve it."

        if (-not(Get-UserConfirmation)){ # PowerShell is not configured as subsystem of SSH
            Print-Text -type "1️⃣ " -content "Open file '/etc/ssh/sshd_config' in text editor (example: 'nano /etc/ssh/sshd_config')."
            Print-Text -type "   " -color DarkGray -content "Press enter for continue..."
            Read-Host
            Print-Text -type "2️⃣ " -content "Find section '# override default of no subsystems'. Its located near end of the file."
            Print-Text -type "   " -color DarkGray -content "Press enter for continue..."
            Read-Host
            Print-Text -type "3️⃣ " -content "Add following line at the end of section: 'Subsystem	powershell /usr/bin/pwsh -sshs -NoLogo -NoProfile'"
            Print-Text -type "   " -color DarkGray -content "Press enter for continue..."
            Read-Host
            Print-Text -type "4️⃣ " -content "Save and close file"
            Print-Text -type "   " -color DarkGray -content "Press enter for continue..."
            Read-Host
            Print-Text -type "5️⃣ " -content "Restart SSH service(for example: 'systemctl restart sshd')"
            Print-Text -type "   " -color DarkGray -content "Press enter for continue..."
            Read-Host
            Print-Text -type "6️⃣ " -content "DONE. PowerShell should be now configured as subsystem of SSH. Installer will now continue in installation process."
            Print-Text -type "   " -color DarkGray -content "Press enter for continue..."
            Read-Host
        }

        # Gather connection details
        Print-Text -type "ℹ️ " -content "Installer now needs SSH credentials for connecting to the server."
        $hostname = Read-Host -Prompt "Name or address of the server"
        $username = Read-Host -Prompt "Name of user with ROOT priviledges"

        # Create SSH connection
        Print-Process -text "Trying to connect to server"
        $session = New-PSSession -Hostname $hostname -Username $username
        if ($session){
            Write-Host $success

            # Install required packages
            Request-Command -description "Installing Apache2 web server" -command "dnf install httpd -y" -exitMessage "❗️ ERROR: Installation of Apache2 failed!" -exitCode 20 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Installing PHP processor" -command "dnf install httpd -y" -exitMessage "❗️ ERROR: Installation of PHP failed!" -exitCode 21 -session $session -start $startTime -successStr $success -failStr $fail
            Request-Command -description "Installing PostgreSQL database" -command

            # Set up firewall
            Request-Command -description "Allowing HTTP through firewall" -command "firewall-cmd --add-service=http --permanent" -exitMessage "❗️ ERROR: Cannot add serivce HTTP to the firewall!" -exitCode 30 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Allowing HTTPS through firewall" -command "firewall-cmd --add-service=https --permanent" -exitMessage "❗️ ERROR: Cannot add serivce HTTPS to the firewall!" -exitCode 31 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Restarting firewall" -command "firewall-cmd --reload" -exitMessage "❗️ ERROR: Restarting of firewall failed!" -exitCode 32 -session $session -start $startTime -successStr $success -failStr $fail 

            Exit-Script -start $startTime -code 0 -message "✅ Script successfully installed Simple Hosting on the server."
        }
        else{
            Write-Host $fail
            Exit-Script -start $startTime -code 10 -message "❗️ ERROR: SSH connection failed!"
        }
    }
}
else{
    Exit-Script -start $startTime -code 11 -message "❗️ ERROR: Installer expects SSH service running on server!"
}

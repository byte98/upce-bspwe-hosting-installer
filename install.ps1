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
            Request-Command -description "Installing DNS server" -command "dnf install bind bind-utils -y" -exitMessage "❗️ ERROR: Installation of DNS server failed!" -exitCode 21 -session $session -start $startTime -successStr $success -failStr $fail 
            
            #Request-Command -description "Installing PHP processor" -command "dnf install httpd -y" -exitMessage "❗️ ERROR: Installation of PHP failed!" -exitCode 21 -session $session -start $startTime -successStr $success -failStr $fail
            #Request-Command -description "Installing PostgreSQL database" -command

            # Set up default web page application
            Print-Text -type "ℹ️ " -content "Installer now configures web application providing user interface of Simple Hosting."
            $address = Read-Host -Prompt "Enter address of server (example: www.example.com)"
            $conffile = "/etc/httpd/conf.d/$address.conf"
            Request-Command -description "Creating directory for web application" -command "mkdir -p /www" -exitMessage "❗️ ERROR: Directory for web application couldn't be created!" -exitCode 30 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Granting web server permission to access directory" -command "chown -R apache:apache /www" -exitMessage "❗️ ERROR: Cannot grant permission to Apache to access /www!" -exitCode 31 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Downloading configuration of web application" -command "wget -O $conffile https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/root.conf.d" -exitMessage "❗️ ERROR: Configuration of web server couldn't be downloaded!" -exitCode 32 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Updating configuration" -command "sed -i 's/`${name}/$address/g' $conffile" -exitMessage "❗️ ERROR: Configuration of web server couldn't be updated!" -exitCode 33 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Downloading application" -command "wget -O /www/simple_hosting.zip https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/simple_hosting.zip" -exitMessage "❗️ ERROR: Application couldn't be downloaded!" -exitCode 34 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Unzipping content" -command "unzip -o /www/simple_hosting.zip -d /www" -exitMessage "❗️ ERROR: Unzipping application failed!" -exitCode 35 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Deleting downloaded content" -command "rm -f /www/simple_hosting.zip" -exitMessage "❗️ ERROR: Downloaded content cannot be deleted!" -exitCode 36 -session $session -start $startTime -successStr $success -failStr $fail 
            
            # Set up DNS
            Request-Command -description "Downloading configuration of web application" -command "wget -O /etc/named.conf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/named.conf.d" -exitMessage "❗️ ERROR: Configuration of DNS server couldn't be downloaded!" -exitCode 40 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Updating configuration" -command "sed -i 's/`${name}/$address/g' /etc/named/conf" -exitMessage "❗️ ERROR: Configuration of DNS server couldn't be updated!" -exitCode 41 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Granting DNS server permission to access directory" -command "chown -R named:named /etc/named" -exitMessage "❗️ ERROR: Cannot grant permission to named to access /etc/named!" -exitCode 31 -session $session -start $startTime -successStr $success -failStr $fail 
            

            # Set up firewall
            Request-Command -description "Allowing HTTP through firewall" -command "firewall-cmd --add-service=http --permanent" -exitMessage "❗️ ERROR: Cannot add serivce HTTP to the firewall!" -exitCode 50 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Allowing HTTPS through firewall" -command "firewall-cmd --add-service=https --permanent" -exitMessage "❗️ ERROR: Cannot add serivce HTTPS to the firewall!" -exitCode 51 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Allowing DNS through firewall" -command "firewall-cmd --add-service=dns --permanent" -exitMessage "❗️ ERROR: Cannot add serivce DNS to the firewall!" -exitCode 52 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Restarting firewall" -command "firewall-cmd --reload" -exitMessage "❗️ ERROR: Restarting of firewall failed!" -exitCode 53 -session $session -start $startTime -successStr $success -failStr $fail 

            # Set up services
            Request-Command -description "Starting HTTPd service" -command "systemctl start httpd.service" -exitMessage "❗️ ERROR: Starting of httpd service failed!" -exitCode 60 -session $session -start $startTime -successStr $success -failStr $fail
            Request-Command -description "Configuring auto-start of HTTPd service" -command "systemctl start httpd.service" -exitMessage "❗️ ERROR: Configuring of auto-start of httpd service failed!" -exitCode 61 -session $session -start $startTime -successStr $success -failStr $fail
            Request-Command -description "Restarting HTTPd service" -command "systemctl restart httpd.service" -exitMessage "❗️ ERROR: Restarting of httpd service failed!" -exitCode 62 -session $session -start $startTime -successStr $success -failStr $fail
            Request-Command -description "Starting DNS service" -command "systemctl start named.service" -exitMessage "❗️ ERROR: Starting of named service failed!" -exitCode 63 -session $session -start $startTime -successStr $success -failStr $fail
            Request-Command -description "Configuring auto-start of DNS service" -command "systemctl start named.service" -exitMessage "❗️ ERROR: Configuring of auto-start of named service failed!" -exitCode 64 -session $session -start $startTime -successStr $success -failStr $fail
            Request-Command -description "Restarting DNS service" -command "systemctl restart named.service" -exitMessage "❗️ ERROR: Restarting of named service failed!" -exitCode 65 -session $session -start $startTime -successStr $success -failStr $fail

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

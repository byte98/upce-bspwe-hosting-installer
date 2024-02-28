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
New-Variable -Name success -Value "✅" -Option Constant

# Character of failed step of process
New-Variable -Name fail -Value "❌" -Option Constant

# Character of unknown status of process
New-Variable -Name unknown -Value "❓" -Option Constant

# Width of output
New-Variable -Name OutWidth -Value 64 -Option Constant

# Default location of web application on server
New-Variable -Name WWWHome -Value "/var/www/html" -Option Constant

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
        ($session = New-PSSession -Hostname $hostname -Username $username) | Out-Null
        if ($session){
            Write-Host $success

            Print-Process -text "Resolving IP address of the server"
            try {
                $ip = [System.Net.Dns]::GetHostAddresses($serverName)[0].IPAddressToString
                Write-Host $success
            }
            catch {
                Write-Host $fail
                Remove-PSSession -Session $session
                Exit-Script -start $startTime -code 12 -message "❗️ ERROR: Address of '$hostname' cannot be resolved!"
            }

            # Install required packages
            Request-Command -description "Installing Apache2 web server" -command "dnf install httpd -y" -exitMessage "❗️ ERROR: Installation of Apache2 failed!" -exitCode 20 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Installing DNS server" -command "dnf install bind bind-utils -y" -exitMessage "❗️ ERROR: Installation of DNS server failed!" -exitCode 21 -session $session -start $startTime -successStr $success -failStr $fail 
            Request-Command -description "Installing application store" -command "dnf install snapd -y" -exitMessage "❗️ ERROR: Installation of Snap Store failed!" -exitCode 22 -session $session -start $startTime -successStr $success -failStr $fail 
            Print-Text -type "ℹ️ " -content "Installer now restarts server. After reboot, please press enter." 
            Print-Process -text "Restarting server"
            (Invoke-Command -Session $session -ScriptBlock {Invoke-Expression -Command "reboot"} -ErrorAction SilentlyContinue) | Out-Null
            Write-Host $unknown
            Print-Text -type "  " -content "Press enter when server is running..." -color DarkGray
            Read-Host
            Print-Process -text "Trying to reconnect to server"
            ($session = New-PSSession -Hostname $hostname -Username $username) | Out-Null
            if ($session){
                Write-Host $success
                Request-Command -description "Installing certification utility" -command "rm -r -f /snap && rm -r -f /usr/bin/certbot && ln -s /var/lib/snapd/snap /snap && snap install --classic certbot && ln -s /snap/bin/certbot /usr/bin/certbot" -exitMessage "❗️ ERROR: Installation of Let's Encrypt certbot failed!" -exitCode 24 -session $session -start $startTime -successStr $success -failStr $fail 
                #Request-Command -description "Installing SSL ceritfication utility" -command "dnf install certbot -y" -exitMessage "❗️ ERROR: Installation of Let's Encrypt certbot failed!" -exitCode 22 -session $session -start $startTime -successStr $success -failStr $fail 

                #Request-Command -description "Installing PHP processor" -command "dnf install httpd -y" -exitMessage "❗️ ERROR: Installation of PHP failed!" -exitCode 21 -session $session -start $startTime -successStr $success -failStr $fail
                #Request-Command -description "Installing PostgreSQL database" -command

                # Set up web server
                Print-Text -type "ℹ️ " -content "Installer now configures Apache2 web server."
                $address = Read-Host -Prompt "Enter name of server (example: contoso.com)"
                $admin = Read-Host -Prompt "Enter e-mail address of administrator of server (example: admin@contoso.com)"
                $conffile = "/etc/httpd/conf.d/$address.conf"
                Request-Command -description "Deleting default configuration" -command "rm -f /etc/httpd/conf/httpd.conf" -exitCode 30 -exitMessage "❗️ ERROR: Default configuration cannot be deleted!" -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Downloading configuration of web server" -command "wget -O /etc/httpd/conf/httpd.conf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/httpd.conf" -exitMessage "❗️ ERROR: Download of web server configuration failed!" -exitCode 31 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Updating configuration (1/2)" -command "sed -i 's#`${www}#$WWWHome#g' /etc/httpd/conf/httpd.conf" -exitCode 32 -exitMessage "❗️ ERROR: Configuration of web server cannot be updated!" -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Updating configuration (2/2)" -command "sed -i 's#`${admin}#$admin#g' /etc/httpd/conf/httpd.conf" -exitCode 33 -exitMessage "❗️ ERROR: Configuration of web server cannot be updated!" -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Disabling 'Welcome' page" -command "sed -i '/^[^#]/ s/^/# /' /etc/httpd/conf.d/welcome.conf" -exitCode 34 -exitMessage "❗️ ERROR: 'Welcome' page cannot be disabled!" -session $session -start $startTime -successStr $success -failStr $fail 

                # Set up web application            
                Request-Command -description "Deleting default content of direcotry for web application" -command "rm -r -f $WWWHome" -exitMessage "❗️ ERROR: Directory for web application couldn't be deleted!" -exitCode 40 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Creating directory for web application" -command "mkdir -p $WWWHome" -exitMessage "❗️ ERROR: Directory for web application couldn't be created!" -exitCode 41 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Granting web server permission to access directory" -command "chown -R apache:apache $WWWHome" -exitMessage "❗️ ERROR: Cannot grant permission to Apache to access $WWWHome!" -exitCode 42 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Downloading application" -command "wget -O $WWWHome/simple_hosting.zip https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/simple_hosting.zip" -exitMessage "❗️ ERROR: Application couldn't be downloaded!" -exitCode 43 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Unzipping content" -command "unzip -o $WWWHome/simple_hosting.zip -d $WWWHome" -exitMessage "❗️ ERROR: Unzipping application failed!" -exitCode 44 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Deleting downloaded content" -command "rm -f $WWWHome/simple_hosting.zip" -exitMessage "❗️ ERROR: Downloaded content cannot be deleted!" -exitCode 45 -session $session -start $startTime -successStr $success -failStr $fail 
                
                # Set up HTTPS
                Request-Command -description "Generating HTTPS certificates" -command "certbot --apache" -exitCode 50 -exitMessage "❗️ ERROR: Let's Encrypt certbot action failed!" -session $session -start $startTime -successStr $success -failStr $fail 
                if (-not (Execute-Command -command "crontab -l | grep ' */12 * * * certbot renew'" -session $session)){
                    # Cron job is not configured
                    Request-Command -description "Configuring auto-renewal of certificates" -command "crontab -l > tmp && echo '0 */12 * * * certbot renew' >> tmp && crontab tmp && rm -f tmp" -exitCode 51 -exitMessage "❗️ ERROR: Cannot configure Cron job for certificates auto-renewal!" -session $session -start $startTime -successStr $success -failStr $fail 
                }
                else{
                    # Cron job is already configured
                    Print-Text -type "ℹ️ " -content "Cron job for certificate renewal is already set."
                }

                # Set up DNS
                Request-Command -description "Downloading configuration of DNS server" -command "wget -O /etc/named.conf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/named.conf.d" -exitMessage "❗️ ERROR: Configuration of DNS server couldn't be downloaded!" -exitCode 60 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Updating configuration (1/3)" -command "sed -i 's/`${name}/$address/g' /etc/named.conf" -exitMessage "❗️ ERROR: Configuration of DNS server couldn't be updated!" -exitCode 61 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Updating configuration (2/3)" -command "sed -i 's/`${domain}/$address/g' /etc/named.conf" -exitMessage "❗️ ERROR: Configuration of DNS server couldn't be updated!" -exitCode 62 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Updating configuration (3/3)" -command "sed -i 's/`${ip}/$ip/g' /etc/named.conf" -exitMessage "❗️ ERROR: Configuration of DNS server couldn't be updated!" -exitCode 63 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Granting DNS server permission to access directory" -command "chown -R named:named /etc/named" -exitMessage "❗️ ERROR: Cannot grant permission to named to access /etc/named!" -exitCode 64 -session $session -start $startTime -successStr $success -failStr $fail 

                # Set up firewall
                Request-Command -description "Allowing HTTP through firewall" -command "firewall-cmd --add-service=http --permanent" -exitMessage "❗️ ERROR: Cannot add serivce HTTP to the firewall!" -exitCode 70 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Allowing HTTPS through firewall" -command "firewall-cmd --add-service=https --permanent" -exitMessage "❗️ ERROR: Cannot add serivce HTTPS to the firewall!" -exitCode 71 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Allowing DNS through firewall" -command "firewall-cmd --add-service=dns --permanent" -exitMessage "❗️ ERROR: Cannot add serivce DNS to the firewall!" -exitCode 72 -session $session -start $startTime -successStr $success -failStr $fail 
                Request-Command -description "Restarting firewall" -command "firewall-cmd --reload" -exitMessage "❗️ ERROR: Restarting of firewall failed!" -exitCode 73 -session $session -start $startTime -successStr $success -failStr $fail 

                # Set up services
                Request-Command -description "Starting HTTPd service" -command "systemctl start httpd.service" -exitMessage "❗️ ERROR: Starting of httpd service failed!" -exitCode 80 -session $session -start $startTime -successStr $success -failStr $fail
                Request-Command -description "Configuring auto-start of HTTPd service" -command "systemctl enable httpd.service" -exitMessage "❗️ ERROR: Configuring of auto-start of httpd service failed!" -exitCode 81 -session $session -start $startTime -successStr $success -failStr $fail
                Request-Command -description "Restarting HTTPd service" -command "systemctl restart httpd.service" -exitMessage "❗️ ERROR: Restarting of httpd service failed!" -exitCode 82 -session $session -start $startTime -successStr $success -failStr $fail
                Request-Command -description "Starting DNS service" -command "systemctl start named.service" -exitMessage "❗️ ERROR: Starting of named service failed!" -exitCode 83 -session $session -start $startTime -successStr $success -failStr $fail
                Request-Command -description "Configuring auto-start of DNS service" -command "systemctl enable named.service" -exitMessage "❗️ ERROR: Configuring of auto-start of named service failed!" -exitCode 84 -session $session -start $startTime -successStr $success -failStr $fail
                Request-Command -description "Restarting DNS service" -command "systemctl restart named.service" -exitMessage "❗️ ERROR: Restarting of named service failed!" -exitCode 85 -session $session -start $startTime -successStr $success -failStr $fail

                Remove-PSSession -Session $session
                Exit-Script -start $startTime -code 0 -message "✅ Script successfully installed Simple Hosting on the server."
            }
            else{
                Write-Host $fail
                Exit-Script -start $startTime -code 23 -message "❗️ ERROR: SSH reconnection failed!"
            }
        }
        else{
            Write-Host $fail
            Exit-Script -start $startTime -code 11 -message "❗️ ERROR: SSH connection failed!"
        }
    }
    else{
        Exit-Script -start $startTime -code 12 -message "❗️ ERROR: Installer expects PowerShell installed on server!"
    }
}
else{
    Exit-Script -start $startTime -code 10 -message "❗️ ERROR: Installer expects SSH service running on server!"
}

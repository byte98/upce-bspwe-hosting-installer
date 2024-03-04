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
            Print-Text -type "ℹ️ " -content "Installer requires some additional information."

            # Gather additional information
            $address =  Read-Host -Prompt "Enter name of domain (example: contoso.com)"
            $admin =    Read-Host -Prompt "Enter e-mail address of administrator of server (example: admin@contoso.com)"
            $org =      Read-Host -Prompt "Enter name of organization (example: Contoso)"
            $un =       Read-Host -Prompt "Enter name of unit of organization (example: IT department)"
            $cn =       Read-Host -Prompt "Enter code of country (example: US)"
            $st =       Read-Host -Prompt "Enter name of state or province (example: California)"
            $pl =       Read-Host -Prompt "Enter name of locality (example: Los Angeles)"
            $orgName =  $org -replace '\s', '' -replace '\W', '' 
            $orgName =  $orgName.ToLower()
            $pkiName =  "pki_$orgName"
            $caPath =   "/etc/$pkiName/CA"
            $conffile = "/etc/httpd/conf.d/$address.conf"

            # Resolve IP address of server
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
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 20 -batch @(
                @("Installing Apache web server", "dnf install httpd -y",    "❗️ ERROR: Installation of web server failed!"),
                @("Installing DNS server", "dnf install bind bind-utils -y", "❗️ ERROR: Installation of DNS server failed!")
            )

            # Set up certification authority
            Print-Text -type "ℹ️ " -content "Installer now configures certification authority."
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 30 -batch @(
                @("Creating directory for CA",                  "mkdir -p -m 0755 /etc/$pkiName",                                                                                                                                                                                   "❗️ ERROR: Directory for CA couldn't be created!"), 
                @("Creating directory tree for CA",             "mkdir -p -m 0755 $caPath $caPath/private $caPath/certs $caPath/newcerts $caPath/crl",                                                                                                                              "❗️ ERROR: Directory tree for CA couldn't be created!"), 
                @("Setting up initial configuration (1/2)",     "cp /etc/pki/tls/openssl.cnf $caPath/openssl.default.cnf && chmod 0600 $caPath/openssl.default.cnf",                                                                                                                "❗️ ERROR: Initializiation of configuration of CA failed!"), 
                @("Setting up initial configuration (2/2)",     "touch $caPath/index.txt && echo '01' > $caPath/serial",                                                                                                                                                            "❗️ ERROR: Initializiation of configuration of CA failed!"), 
                @("Creating CA certificate",                    "openssl req -config $caPath/openssl.default.cnf -new -x509 -extensions v3_ca -keyout $caPath/private/ca.key -out $caPath/certs/ca.crt -days 1825 -subj '/C=$cn/ST=$st/L=$pl/O=$org CA/OU=$un/CN=$address' -nodes", "❗️ ERROR: CA certificate couldn't be created!"), 
                @("Chaning permissions to certificates",        "chmod 0400 $caPath/private/ca.key",                                                                                                                                                                                "❗️ ERROR: Permisions of certificate file couldn't be changed!"), 
                @("Downloading certificates configuration",     "wget -O $caPath/openssl.server.cnf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/ssl.cnf",                                                                                                 "❗️ ERROR: Downloading of server certificates configuration failed!"), 
                @("Updating confiugration",                     "sed -i 's#`${caPath}#$caPath#g' /$caPath/openssl.server.cnf",                                                                                                                                                      "❗️ ERROR: Configuration of server certificates couldn't be updated."), 
                @("Creating request for SSL certificate",       "openssl req -config $caPath/openssl.server.cnf -new -nodes -keyout $caPath/private/$address.key -out $caPath/$address.csr -days 365 -subj '/C=$cn/ST=$st/L=$pl/O=$org CA/OU=$un/CN=$address'",                     "❗️ ERROR: SSL certificate couldn't be created!"), 
                @("Granting permissions to certificates (1/2)", "chown root:apache $caPath/private/$orgName.key",                                                                                                                                                                   "❗️ ERROR: Permissions couldn't be granted!"), 
                @("Granting permissions to certificates (2/2)", "chmod 0440 $caPath/private/$orgName.key",                                                                                                                                                                          "❗️ ERROR: Permissions couldn't be granted!"), 
                @("Signing SSL certificate",                    "openssl ca -batch -config $caPath/openssl.server.cnf -policy policy_anything -out $caPath/certs/$address.crt -infiles $caPath/$address.csr",                                                                       "❗️ ERROR: Certificate couldn't be signed!"),
                @("Deleting request",                           "rm -f $caPath/$orgName.csr",                                                                                                                                                                                       "❗️ ERROR: File couldn't be deleted!")
            )

            # Set up web server
            Print-Text -type "ℹ️ " -content "Installer now configures Apache web server."
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 50 -batch @(
                @("Deleting default configuration",                       "rm -f /etc/httpd/conf/httpd.conf",                                                                                        "❗️ ERROR: Default configuration cannot be deleted!" ), 
                @("Downloading configuration of web server",              "wget -O /etc/httpd/conf/httpd.conf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/httpd.conf"      "❗️ ERROR: Download of web server configuration failed!", 31 ), 
                @("Updating configuration (1/2)",                         "sed -i 's#`${www}#$WWWHome#g' /etc/httpd/conf/httpd.conf",                                                                "❗️ ERROR: Configuration of web server cannot be updated!" ), 
                @("Updating configuration (2/2)",                         "sed -i 's#`${admin}#$admin#g' /etc/httpd/conf/httpd.conf",                                                                "❗️ ERROR: Configuration of web server cannot be updated!" ), 
                @("Disabling 'Welcome' page",                             "sed -i '/^[^#]/ s/^/# /' /etc/httpd/conf.d/welcome.conf",                                                                 "❗️ ERROR: 'Welcome' page cannot be disabled!" ), 
                @("Downloading configuration of Simple Hosting web page", "wget -O /etc/httpd/conf.d/$address.conf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/root.conf", "❗️ ERROR: Downloading of configuration of main page failed!" ), 
                @("Updating configuration (1/4)",                         "sed -i 's#`${admin}#$admin#g' /etc/httpd/conf.d/$address.conf",                                                           "❗️ ERROR: Configuration of Simple Hosting web page cannot be updated!" ), 
                @("Updating configuration (2/4)",                         "sed -i 's#`${www}#$WWWHome#g' /etc/httpd/conf.d/$address.conf",                                                           "❗️ ERROR: Configuration of Simple Hosting web page cannot be updated!" ), 
                @("Updating configuration (3/4)",                         "sed -i 's#`${name}#$address#g' /etc/httpd/conf.d/$address.conf",                                                          "❗️ ERROR: Configuration of Simple Hosting web page cannot be updated!" ), 
                @("Updating configuration (4/4)",                         "sed -i 's#`${ca}#$caPath#g' /etc/httpd/conf.d/$address.conf",                                                             "❗️ ERROR: Configuration of Simple Hosting web page cannot be updated!" ), 
                @("Restarting web server",                                "systemctl restart httpd",                                                                                                 "❗️ ERROR: Apache2 web server cannot be restarted!" ), 
                @("Installing SSL module for web server",                 "dnf install mod_ssl -y",                                                                                                  "❗️ ERROR: Installation of 'mod_ssl' for Apache web server failed!" ) 
            )

            # Set up web application
            Print-Text -type "ℹ️ " -content "Installer now installs Simple Hosting web application."
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 70 -batch @(
                @("Deleting default content of directory for web application", "rm -r -f $WWWHome",                                                                                                            "❗️ ERROR: Directory for web application couldn't be deleted!"), 
                @("Creating directory for web application",                    "mkdir -p $WWWHome",                                                                                                            "❗️ ERROR: Directory for web application couldn't be created!"), 
                @("Granting web server permission to access directory",        "chown -R apache:apache $WWWHome",                                                                                              "❗️ ERROR: Cannot grant permission to Apache to access $WWWHome!"), 
                @("Downloading application",                                   "wget -O $WWWHome/simple_hosting.zip https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/simple_hosting.zip", "❗️ ERROR: Application couldn't be downloaded!"), 
                @("Unzipping content",                                         "unzip -o $WWWHome/simple_hosting.zip -d $WWWHome",                                                                             "❗️ ERROR: Unzipping application failed!"), 
                @("Deleting downloaded content",                               "rm -f $WWWHome/simple_hosting.zip",                                                                                            "❗️ ERROR: Downloaded content cannot be deleted!") 
            )

            # Set up DNS
            Print-Text -type "ℹ️ " -content "Installer now configures DNS server"
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 80 -batch @(
                @("Downloading configuration of DNS server", "wget -O /etc/named.conf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/named.conf.d", "❗️ ERROR: Configuration of DNS server couldn't be downloaded!"), 
                @("Updating configuration (1/3)",                       "sed -i 's/`${name}/$address/g' /etc/named.conf",                                                  "❗️ ERROR: Configuration of DNS server couldn't be updated!"), 
                @("Updating configuration (2/3)",                       "sed -i 's/`${domain}/$address/g' /etc/named.conf",                                                "❗️ ERROR: Configuration of DNS server couldn't be updated!"), 
                @("Updating configuration (3/3)",                       "sed -i 's/`${ip}/$ip/g' /etc/named.conf",                                                         "❗️ ERROR: Configuration of DNS server couldn't be updated!"), 
                @("Granting DNS server permission to access directory", "chown -R named:named /etc/named",                                                                 "❗️ ERROR: Cannot grant permission to named to access /etc/named!")
            )

            # Set up firewall
            Print-Text -type "ℹ️ " -content "Installer now configures firewall rules"
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 90 -batch @(
                @("Allowing HTTP through firewall",  "firewall-cmd --add-service=http --permanent",  "❗️ ERROR: Cannot add serivce HTTP to the firewall!"), 
                @("Allowing HTTPS through firewall", "firewall-cmd --add-service=https --permanent", "❗️ ERROR: Cannot add serivce HTTPS to the firewall!"), 
                @("Allowing DNS through firewall",   "firewall-cmd --add-service=dns --permanent",   "❗️ ERROR: Cannot add serivce DNS to the firewall!"), 
                @("Restarting firewall",             "firewall-cmd --reload",                        "❗️ ERROR: Restarting of firewall failed!") 
            )

            # Restart services
            Print-Text -type "ℹ️ " -content "Installer now restarts services"
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 100 -batch @(
                @("Starting HTTPd service", "systemctl start httpd.service", "❗️ ERROR: Starting of httpd service failed!"),
                @("Configuring auto-start of HTTPd service", "systemctl enable httpd.service", "❗️ ERROR: Configuring of auto-start of httpd service failed!"),
                @("Restarting HTTPd service", "systemctl restart httpd.service", "❗️ ERROR: Restarting of httpd service failed!"),
                @("Starting DNS service", "systemctl start named.service", "❗️ ERROR: Starting of named service failed!"),
                @("Configuring auto-start of DNS service", "systemctl enable named.service", "❗️ ERROR: Configuring of auto-start of named service failed!"),
                @("Restarting DNS service", "systemctl restart named.service", "❗️ ERROR: Restarting of named service failed!")    
            )
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

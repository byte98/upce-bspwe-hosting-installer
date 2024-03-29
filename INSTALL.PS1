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

# Default location of web ftp application on server
New-Variable -Name WFTPHome -Value "/var/www/webftp" -Option Constant

# Import utility file
. ".\UTILS.PS1"

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
        $hostname = Read-Host -Prompt "Name or address of the server     "
        $username = Read-Host -Prompt "Name of user with ROOT priviledges"

        # Create SSH connection
        Print-Process -text "Trying to connect to server"
        ($session = New-PSSession -Hostname $hostname -Username $username) | Out-Null
        if ($session){
            Write-Host $success
            Print-Text -type "ℹ️ " -content "Installer requires some additional information."

            # Gather additional information
            $address =  Read-Host -Prompt "Name of domain (example: contoso.com)                                 "
            $admin =    Read-Host -Prompt "E-mail address of administrator of server (example: admin@contoso.com)"
            $org =      Read-Host -Prompt "Name of organization (example: Contoso)                               "
            $un =       Read-Host -Prompt "Name of unit of organization (example: IT department)                 "
            $cn =       Read-Host -Prompt "Code of country (example: US)                                         "
            $st =       Read-Host -Prompt "Name of state or province (example: California)                       "
            $pl =       Read-Host -Prompt "Name of locality (example: Los Angeles)                               "
            $dbuser =   Read-Host -Prompt "Name of user with administrator rights to the database                "
            $dbpwd =    Get-Password -prompt "Password of user with administrator rights to the database            " -again "Password of user with administrator rights to the database again      "
            $dbname =   $address -replace '[^a-zA-Z0-9]', '_'
            $orgName =  $org -replace '\s', '' -replace '\W', '' 
            $orgName =  $orgName.ToLower()
            $pkiName =  "pki_$orgName"
            $caPath =   "/etc/$pkiName/CA"
            $conffile = "/etc/httpd/conf.d/$address.conf"
            $adminNS =  $admin -replace '@', '.'

            # Resolve IP address of server
            Print-Process -text "Resolving IP address of the server"
            $check = [string]$hostname
            if (Is-IPAddress -str $check){
                $ip = $check
                Write-Host $success
            }
            else{
                try {
                    $ip = [System.Net.Dns]::GetHostAddresses($serverName)[0].IPAddressToString
                    Write-Host $success
                }
                catch {
                    Write-Host $fail
                    Remove-PSSession -Session $session
                    Exit-Script -start $startTime -code 12 -message "❗️ ERROR: Address of '$hostname' cannot be resolved!"
                }
            }
            

            # Install required packages
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 20 -batch @(
                @("Installing Apache web server", "dnf install httpd -y",                 "❗️ ERROR: Installation of web server failed!"),
                @("Installing DNS server",        "dnf install bind bind-utils -y",       "❗️ ERROR: Installation of DNS server failed!")
                #@("Installing Docker",            "dnf install docker docker-compose -y", "❗️ ERROR: Installation of Docker failed!"),
                #@("Starting Docker service",      "systemctl start docker",               "❗️ ERROR: Docker service couldn't be started!")
            )

            # Set up certification authority
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 30 -batch @(
                @("Creating directory for CA",                  "mkdir -p -m 0755 /etc/$pkiName",                                                                                                                                                                                   "❗️ ERROR: Directory for CA couldn't be created!"), 
                @("Creating directory tree for CA",             "mkdir -p -m 0755 $caPath $caPath/private $caPath/certs $caPath/newcerts $caPath/crl",                                                                                                                              "❗️ ERROR: Directory tree for CA couldn't be created!"), 
                @("Setting up initial configuration (1/2)",     "cp /etc/pki/tls/openssl.cnf $caPath/openssl.default.cnf && chmod 0600 $caPath/openssl.default.cnf",                                                                                                                "❗️ ERROR: Initializiation of configuration of CA failed!"), 
                @("Setting up initial configuration (2/2)",     "touch $caPath/index.txt && echo '01' > $caPath/serial",                                                                                                                                                            "❗️ ERROR: Initializiation of configuration of CA failed!"), 
                @("Creating CA certificate",                    "openssl req -config $caPath/openssl.default.cnf -new -x509 -extensions v3_ca -keyout $caPath/private/CA.key -out $caPath/certs/CA.crt -days 1825 -subj '/C=$cn/ST=$st/L=$pl/O=$org CA/OU=$un/CN=$address' -nodes", "❗️ ERROR: CA certificate couldn't be created!"), 
                @("Chaning permissions to certificates",        "chmod 0400 $caPath/private/CA.key",                                                                                                                                                                                "❗️ ERROR: Permisions of certificate file couldn't be changed!"), 
                @("Downloading certificates configuration",     "wget -O $caPath/openssl.server.cnf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/ssl.cnf",                                                                                                 "❗️ ERROR: Downloading of server certificates configuration failed!"), 
                @("Updating confiugration",                     "sed -i 's#`${caPath}#$caPath#g' /$caPath/openssl.server.cnf",                                                                                                                                                      "❗️ ERROR: Configuration of server certificates couldn't be updated."), 
                @("Creating request for SSL certificate",       "openssl req -config $caPath/openssl.server.cnf -new -nodes -keyout $caPath/private/$address.key -out $caPath/$address.csr -days 365 -subj '/C=$cn/ST=$st/L=$pl/O=$org/OU=$un/CN=$address'",                     "❗️ ERROR: SSL certificate couldn't be created!"), 
                @("Granting permissions to certificates (1/2)", "chown root:apache $caPath/private/$address.key",                                                                                                                                                                   "❗️ ERROR: Permissions couldn't be granted!"), 
                @("Granting permissions to certificates (2/2)", "chmod 0440 $caPath/private/$address.key",                                                                                                                                                                          "❗️ ERROR: Permissions couldn't be granted!"), 
                @("Signing SSL certificate",                    "openssl ca -batch -config $caPath/openssl.server.cnf -policy policy_anything -out $caPath/certs/$address.crt -infiles $caPath/$address.csr",                                                                       "❗️ ERROR: Certificate couldn't be signed!"),
                @("Deleting request",                           "rm -f $caPath/$orgName.csr",                                                                                                                                                                                       "❗️ ERROR: File couldn't be deleted!")
            )

            # Set up web server
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 50 -batch @(
                @("Deleting default configuration",                       "rm -f /etc/httpd/conf/httpd.conf",                                                                                        "❗️ ERROR: Default configuration cannot be deleted!" ), 
                @("Installing SSL module for web server",                 "dnf install mod_ssl -y",                                                                                                  "❗️ ERROR: Installation of 'mod_ssl' for Apache web server failed!" ),
                @("Downloading configuration of web server",              "wget -O /etc/httpd/conf/httpd.conf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/httpd.conf",     "❗️ ERROR: Download of web server configuration failed!"), 
                @("Updating configuration (1/3)",                         "sed -i 's#`${www}#$WWWHome#g' /etc/httpd/conf/httpd.conf",                                                                "❗️ ERROR: Configuration of web server cannot be updated!" ), 
                @("Updating configuration (2/3)",                         "sed -i 's#`${admin}#$admin#g' /etc/httpd/conf/httpd.conf",                                                                "❗️ ERROR: Configuration of web server cannot be updated!" ), 
                @("Updating configuration (2/3)",                         "sed -i 's#`${name}#$address#g' /etc/httpd/conf/httpd.conf",                                                               "❗️ ERROR: Configuration of web server cannot be updated!" ), 
                @("Disabling 'Welcome' page",                             "sed -i '/^[^#]/ s/^/# /' /etc/httpd/conf.d/welcome.conf",                                                                 "❗️ ERROR: 'Welcome' page cannot be disabled!" ), 
                @("Downloading configuration of Simple Hosting web page", "wget -O /etc/httpd/conf.d/$address.conf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/root.conf", "❗️ ERROR: Downloading of configuration of main page failed!" ), 
                @("Updating configuration (1/4)",                         "sed -i 's#`${admin}#$admin#g' /etc/httpd/conf.d/$address.conf",                                                           "❗️ ERROR: Configuration of Simple Hosting web page cannot be updated!" ), 
                @("Updating configuration (2/4)",                         "sed -i 's#`${www}#$WWWHome#g' /etc/httpd/conf.d/$address.conf",                                                           "❗️ ERROR: Configuration of Simple Hosting web page cannot be updated!" ), 
                @("Updating configuration (3/4)",                         "sed -i 's#`${name}#$address#g' /etc/httpd/conf.d/$address.conf",                                                          "❗️ ERROR: Configuration of Simple Hosting web page cannot be updated!" ), 
                @("Updating configuration (4/4)",                         "sed -i 's#`${ca}#$caPath#g' /etc/httpd/conf.d/$address.conf",                                                             "❗️ ERROR: Configuration of Simple Hosting web page cannot be updated!" )
            )

            # Set up web application
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 70 -batch @(
                @("Deleting default content of web application",               "rm -r -f $WWWHome",                                                                                                            "❗️ ERROR: Directory for web application couldn't be deleted!"), 
                @("Creating directory for web application",                    "mkdir -p $WWWHome",                                                                                                            "❗️ ERROR: Directory for web application couldn't be created!"), 
                @("Downloading application",                                   "wget -O $WWWHome/simple_hosting.zip https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/simple_hosting.zip", "❗️ ERROR: Application couldn't be downloaded!"), 
                @("Unzipping content",                                         "unzip -o $WWWHome/simple_hosting.zip -d $WWWHome",                                                                             "❗️ ERROR: Unzipping application failed!"), 
                @("Deleting downloaded content",                               "rm -f $WWWHome/simple_hosting.zip",                                                                                            "❗️ ERROR: Downloaded content cannot be deleted!"), 
                @("Granting permissions to web server (1/3)",                  "chown -R apache:apache $WWWHome",                                                                                              "❗️ ERROR: Cannot grant permission to Apache to access $WWWHome!"), 
                @("Granting permissions to web server (2/3)",                  "chmod +rx $WWWHome",                                                                                                           "❗️ ERROR: Cannot grant permission to Apache to access $WWWHome!"), 
                @("Granting permissions to web server (3/3)",                  "chcon -R -t httpd_sys_content_t $WWWHome",                                                                                     "❗️ ERROR: Cannot grant permission to Apache to access $WWWHome!"),
                @("Starting HTTPd service",                                    "systemctl start httpd.service",                                                                                                "❗️ ERROR: Starting of httpd service failed!")
            )

            # Set up DNS
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 80 -batch @(
                @("Downloading configuration of DNS server",            "wget -O /etc/named.conf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/named.conf",           "❗️ ERROR: Configuration of DNS server couldn't be downloaded!"),  
                @("Updating configuration",                             "sed -i 's#`${domain}#$address#g' /etc/named.conf",                                                                   "❗️ ERROR: DNS configuration cannot be updated!"),
                @("Granting DNS server permission to access directory", "chown -R named:named /etc/named",                                                                                    "❗️ ERROR: Cannot grant permission to named to access /etc/named!"),
                @("Downloading configuration of DNS name zone",         "wget -O /etc/named/$address.zone https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/named.zone",  "❗️ ERROR: Downloading of DNS zone file failed!"),
                @("Updating configuration (1/3)",                       "sed -i 's#`${domain}#$address#g' /etc/named/$address.zone",                                                          "❗️ ERROR: DNS zone file cannot be updated!"),
                @("Updating configuration (2/3)",                       "sed -i 's#`${admin}#$adminNS#g' /etc/named/$address.zone",                                                           "❗️ ERROR: DNS zone file cannot be updated!"),
                @("Updating configuration (3/3)",                       "sed -i 's#`${ip}#$ip#g' /etc/named/$address.zone",                                                                   "❗️ ERROR: DNS zone file cannot be updated!")
            )

            # Set up database
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 90 -batch @(
                @("Installing database (1/2)",                          "dnf install postgresql-server -y",                                                                                   "❗️ ERROR: Installation of database failed!"),
                @("Installing database (2/2)",                          "dnf install postgresql-contrib -y",                                                                                  "❗️ ERROR: Installation of database failed!"),
                @("Creating database cluster",                          "postgresql-setup --initdb",                                                                                          "❗️ ERROR: Database cluster initialization failed!"),
                @("Starting database service",                          "systemctl start postgresql",                                                                                         "❗️ ERROR: Database service couldn't be started!"),
                @("Creating administrator ",                            "sudo -u postgres psql -c `"CREATE ROLE $dbuser SUPERUSER LOGIN PASSWORD '$dbpwd';`"",                                "❗️ ERROR: Administrator of database couldn't be created!"),
                @("Creating database",                                  "sudo -u postgres psql -c `"CREATE DATABASE $dbname OWNER $dbuser;`"",                                                "❗️ ERROR: Database couldn't be created!"),
                @("Downloading structure of database",                  "wget -O /var/database.sql https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/database.sql",       "❗️ ERROR: Database structure couldn't be downloaded!"),
                @("Creating structure of database",                     "sudo -u postgres psql -d $dbname -a -f /var/database.sql",                                                           "❗️ ERROR: Database structure creation failed!"),
                @("Deleting file with structure of database",           "rm -f /var/database.sql",                                                                                            "❗️ ERROR: File couldn't be deleted!")
            )

            # Install PHP
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 100 -batch @(
                @("Installing PHP (1/2)",         "dnf install php -y",                                 "❗️ ERROR: Installation of PHP failed!"),
                @("Installing PHP (2/2)",         "dnf install php-devel -y",                           "❗️ ERROR: Installation of PHP failed!"),
                @("Installing PHP modules (1/4)", "dnf install php-pgsql -y",                           "❗️ ERROR: Installation of PHP modules failed!"),
                @("Installing PHP modules (2/4)", "dnf install php-pear -y",                            "❗️ ERROR: Installation of PHP modules failed!"),
                @("Installing PHP modules (3/4)", "dnf install libyaml-devel -y",                       "❗️ ERROR: Installation of PHP modules failed!"),
                @("Installing PHP modules (4/4)", "printf `"\n`" | pecl install yaml",                  "❗️ ERROR: Installation of PHP modules failed!"),
                @("Updating configuration",       "echo `"\n`"extension=yaml.so`"\n`" >> /etc/php.ini", "❗️ ERROR: Configuration of PHP couldn't be updated!")
            )
            # Set up Web FTP
            <#
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 110 -batch @(
                @("Creating directory for web ftp",             "mkdir $WFTPHome",                                                                                                                                                                                                "❗️ ERROR: Directory for web ftp couldn't be created!"),
                @("Downloading web ftp application",            "wget -O $WFTPHome/docker-compose.yml https://downloads.filestash.app/latest/docker-compose.yml",                                                                                                                 "❗️ ERROR: Web ftp application couldn't be downloaded!"),
                @("Building web ftp application",               "docker-compose -f $WFTPHome/docker-compose.yml up -d",                                                                                                                                                           "❗️ ERROR: Web ftp application couldn't be built!"),
                @("Downloading configuration of web ftp",       "wget -O /etc/httpd/conf.d/webftp.$address.conf https://github.com/byte98/upce-bspwe-hosting/releases/latest/download/webftp.conf",                                                                               "❗️ ERROR: Configuration of web ftp couldn't be downloaded!"),
                @("Updating configuration (1/4)",               "sed -i 's#`${admin}#$admin#g' /etc/httpd/conf.d/webftp.$address.conf",                                                                                                                                           "❗️ ERROR: Configuration of web ftp cannot be updated!" ), 
                @("Updating configuration (2/4)",               "sed -i 's#`${www}#$WFTPHome#g' /etc/httpd/conf.d/webftp.$address.conf",                                                                                                                                          "❗️ ERROR: Configuration of web ftp cannot be updated!" ), 
                @("Updating configuration (3/4)",               "sed -i 's#`${name}#$address#g' /etc/httpd/conf.d/webftp.$address.conf",                                                                                                                                          "❗️ ERROR: Configuration of web ftp cannot be updated!" ), 
                @("Updating configuration (4/4)",               "sed -i 's#`${ca}#$caPath#g' /etc/httpd/conf.d/webftp.$address.conf",                                                                                                                                             "❗️ ERROR: Configuration of web ftp cannot be updated!" ),
                @("Creating request for SSL certificate",       "openssl req -config $caPath/openssl.server.cnf -new -nodes -keyout $caPath/private/webftp.$address.key -out $caPath/webftp.$address.csr -days 365 -subj '/C=$cn/ST=$st/L=$pl/O=$org/OU=$un/CN=webftp.$address'", "❗️ ERROR: SSL certificate couldn't be created!"), 
                @("Granting permissions to certificates (1/2)", "chown root:apache $caPath/private/webftp.$address.key",                                                                                                                                                          "❗️ ERROR: Permissions couldn't be granted!"), 
                @("Granting permissions to certificates (2/2)", "chmod 0440 $caPath/private/webftp.$address.key",                                                                                                                                                                 "❗️ ERROR: Permissions couldn't be granted!"), 
                @("Signing SSL certificate",                    "openssl ca -batch -config $caPath/openssl.server.cnf -policy policy_anything -out $caPath/certs/webftp.$address.crt -infiles $caPath/webftp.$address.csr",                                                       "❗️ ERROR: Certificate couldn't be signed!"),
                @("Deleting request",                           "rm -f $caPath/webftp.$orgName.csr",                                                                                                                                                                              "❗️ ERROR: File couldn't be deleted!"),
                @("Granting permissions to web server (1/3)",   "chown -R apache:apache $WFTPHome",                                                                                                                                                                               "❗️ ERROR: Cannot grant permission to Apache to access web ftp!"), 
                @("Granting permissions to web server (2/3)",   "chmod +rx $WFTPHome",                                                                                                                                                                                            "❗️ ERROR: Cannot grant permission to Apache to access web ftp!"), 
                @("Granting permissions to web server (3/3)",   "chcon -R -t httpd_sys_content_t $WFTPHome",                                                                                                                                                                      "❗️ ERROR: Cannot grant permission to Apache to access web ftp!"),
                @("Deleting downloaded archive",                "rm -f $WFTPHome/webftp.zip",                                                                                                                                                                                     "❗️ ERROR: Downloaded archive couldn't be deleted!")
            )#>

            # Set up firewall
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 120 -batch @(
                @("Allowing HTTP through firewall",  "firewall-cmd --add-service=http --permanent",  "❗️ ERROR: Cannot add serivce HTTP to the firewall!"), 
                @("Allowing HTTPS through firewall", "firewall-cmd --add-service=https --permanent", "❗️ ERROR: Cannot add serivce HTTPS to the firewall!"), 
                @("Allowing DNS through firewall",   "firewall-cmd --add-service=dns --permanent",   "❗️ ERROR: Cannot add serivce DNS to the firewall!"), 
                @("Restarting firewall",             "firewall-cmd --reload",                        "❗️ ERROR: Restarting of firewall failed!") 
            )

            # Restart services
            Run-Batch -session $session -start $startTime -successStr $success -failStr $fail -exitCode 130 -batch @(
                @("Configuring auto-start of HTTPd service",    "systemctl enable httpd.service",  "❗️ ERROR: Configuring of auto-start of httpd service failed!"),
                @("Restarting HTTPd service",                   "systemctl restart httpd.service", "❗️ ERROR: Restarting of httpd service failed!"),
                @("Starting DNS service",                       "systemctl start named.service",   "❗️ ERROR: Starting of named service failed!"),
                @("Configuring auto-start of DNS service",      "systemctl enable named.service",  "❗️ ERROR: Configuring of auto-start of named service failed!"),
                @("Restarting DNS service",                     "systemctl restart named.service", "❗️ ERROR: Restarting of named service failed!"),
                @("Configuring auto-start of database service", "systemctl enable postgresql",     "❗️ ERROR: Configuring of auto-start of database service failed!"),
                @("Restarting database service",                "systemctl restart postgresql",    "❗️ ERROR: Restarting of database service failed!")
            )

            # FIN
            Remove-PSSession -Session $session
            Exit-Script -start $startTime -code 0 -message "✅ Script successfully installed Simple Hosting on the server!" 
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

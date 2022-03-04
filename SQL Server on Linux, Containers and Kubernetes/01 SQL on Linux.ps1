# SQL on Linux
$VMName="SQLonLinux"
# Function to reliably get VM IPs
function GetIP {
    param (
        $VMName
    )
    $MacAddr=(Get-VMNetworkAdapter -VMName $VMName | Select -ExpandProperty MacAddress).Insert(2,"-").Insert(5,"-").Insert(8,"-").Insert(11,"-").Insert(14,"-")
    $IP=(Get-NetNeighbor | where LinkLayerAddress -eq $MacAddr | Select -ExpandProperty IPAddress)
    $IP
}

$SSHTarget=("demo@" + (GetIP($VMName)))

# Connect to VM
ssh $SSHTarget

# Download and install SQL Server (adjust path for different versions of Ubuntu etc.)
sudo wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2019.list)"
sudo apt update
sudo apt install mssql-server -y

# Configure SQL Server
sudo /opt/mssql/bin/mssql-conf setup

# Install SQLCMD and add to PATH
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt update 
sudo ACCEPT_EULA=Y apt install mssql-tools -y
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
source ~/.bash_profile

# Try connection
sqlcmd -S 127.0.0.1 -U SA -P P@ssw0rd -Q "SELECT @@Version"

# ERRORLOG
journalctl | grep sqlserver

exit

# We can also connect from our other machine
sqlcmd -S (GetIP($VMName)) -U SA -P P@ssw0rd -Q "SELECT @@Version"

# Or use another tool... like SSMS
GetIP($VMName)
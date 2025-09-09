# Let's login to azure and create a resource group
$Sub="Azure Data Demos"
$tenant="XXX"
$RG="Precon2025"
$Region="northeurope"
$dbname="PreconDB"
$dbserver="BWPreconSQLDBSRV"
# This should live in a key vault!
$password="MyVeryS3cureP@ssw0rd"

az login --tenant XXX

az account set -s $Sub
$Subid = (az account show --output json | ConvertFrom-Json).id
az group create --location $region --name $rg
$RG_URL="https://portal.azure.com/#@" + $tenant + "/resource/subscriptions/" + $SubID + "/resourceGroups/" + $RG + "/overview"
# How about the Azure Portal? Let's deploy a sql db!
Start-Process $RG_URL
# Start-Process https://portal.azure.com/#create/hub

# This is OK, but... what about big deployments with many resources? This doesn't scale well, it doesn't do dependencies etc. etc.
# I can also not provide any restricted options etc. etc. 
az sql server create -l $Region -g $RG -n $dbserver -u myadminuser -p $password

az sql server ad-admin create -g $RG -s $dbserver `
  --display-name "ben Admin" `
  --object-id "$(az ad signed-in-user show --query id -o tsv)"

sqlcmd -S "$dbserver.database.windows.net" -U myadminuser -P $password -Q "SELECT 1"

$myIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip

az sql server firewall-rule create -g $RG -s $dbserver `
  --name "ClientIP" --start-ip-address $myIP --end-ip-address $myIP

sqlcmd -S "$dbserver.database.windows.net" -U myadminuser -P $password -Q "SELECT 1"

az sql server ad-only-auth enable -g $RG -n $dbserver

sqlcmd -S "$dbserver.database.windows.net" -U myadminuser -P $password -Q "SELECT 1"

# if this errors:
# choco install sqlcmd
sqlcmd -S "$dbserver.database.windows.net" -Q "SELECT 1" --authentication-method ActiveDirectoryAzCli
# Could also use: 
# ActiveDirectoryApplication ActiveDirectoryServicePrincipal ActiveDirectoryDefault ActiveDirectoryIntegrated ActiveDirectoryInteractive
# ActiveDirectoryManagedIdentity ActiveDirectoryMSI ActiveDirectoryPassword ActiveDirectoryAzCli ActiveDirectoryDeviceCode


Start-Process $RG_URL

az sql db create -g $RG -s $dbserver -n $dbname --service-objective S0

# Az PS Module... same same but different...
# Connect to Azure (interactive login)
# Connect-AzAccount 

# Create resource group
# New-AzResourceGroup -Name $RG -Location $Region
# Create SQL Server with Entra-only authentication
# New-AzSqlServer -ResourceGroupName $RG `
#                -ServerName ($DbServer + '-PS').ToLower() `
#                -Location $Region `
#                -EnableActiveDirectoryOnlyAuthentication `
#                -ExternalAdminName 'user@domain.com'            

# Create SQL database
# New-AzSqlDatabase -ResourceGroupName $RG `
#                  -ServerName ($DbServer + '-PS').ToLower() `
#                  -DatabaseName $DbName `
#                  -RequestedServiceObjectiveName "S0"

# az bicep install
# az bicep upgrade

code C:\Users\Administrator\Desktop\Code\m02\sqldb.bicep
# $adminSid = (Get-AzADUser -UserPrincipalName 'user@domain.com').Id
# az deployment group create --resource-group $rg --template-file sqldb.bicep `
#            --parameters externalAdminName='user@domain.com' externalAdminSid=$adminSid sqlDbSize='S1'

sqlcmd -Q "CREATE DATABASE TestDB"
sqlcmd -d TestDB -Q "CREATE TABLE Users (Id INT PRIMARY KEY, Name NVARCHAR(50))"
sqlcmd -d TestDB -Q "INSERT INTO Users VALUES (1, 'Black Widow')"

# choco install SqlPackage
sqlpackage `
  /Action:Export `
  /SourceServerName:127.0.0.1 `
  /SourceDatabaseName:TestDB `
  /TargetFile:C:\temp\TestDB.bacpac `
  /SourceEncryptConnection:true `
  /SourceTrustServerCertificate:true

sqlcmd -S "$dbserver.database.windows.net" -Q "SELECT * FROM [Users]"  -d $dbname --authentication-method ActiveDirectoryAzCli

$token = az account get-access-token --resource https://database.windows.net --query accessToken -o tsv
  sqlpackage `
  /Action:Import `
  /TargetServerName:"$dbserver.database.windows.net" `
  /TargetDatabaseName:$dbname `
  /AccessToken:$token `
  /SourceFile:"C:\temp\TestDB.bacpac"

sqlcmd -S "$dbserver.database.windows.net" -Q "SELECT * FROM [Users]"  -d $dbname --authentication-method ActiveDirectoryAzCli

# Could also have used the Wizard in SSMS!
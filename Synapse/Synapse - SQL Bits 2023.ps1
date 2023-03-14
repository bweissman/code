# Set all the variables :)
$Subscription=""
$Region = "eastus"
$RG = ""
$SynapseName = ""
$StorageAccountName = ""
$ContainerName = ""
$username = "sqladmin"
$password = "SuperSecretP@ssw0rd!"
$poolname = "linkpool"
$poolsize = "DW100c"
$WinUser="Administrator"
cmdkey /generic:Winserver.bwdemo.io /user:$WinUser /pass:$password

#  Set correct Subscription
az account set -s $Subscription

# Deploy all the things (takes ~ 10 minutes)
# create an RG
az group create -n $RG -l $Region

# create a storage account
az storage account create --name $StorageAccountName `
    --resource-group $RG --location $Region `
    --sku Standard_LRS --kind StorageV2

# Add a container to our storage account
az storage container create -n $ContainerName --account-name $StorageAccountName  

# Create a Synapse Workspace
az synapse workspace create --file-system $ContainerName `
    --name $SynapseName `
    --resource-group $RG `
    --sql-admin-login-password $password `
    --sql-admin-login-user $username `
    --storage-account $SynapseName

# Add the dedicated SQL Pool
az synapse sql pool create --name $poolname `
    --performance-level $poolsize `
    --resource-group $RG `
    --workspace-name $SynapseName

# Create a firewall rule (maybe make this a bit more restrictive :))
az synapse workspace firewall-rule create --name allowAll --workspace-name $SynapseName `
    --resource-group $RG --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255

# Pause the pool (if you don't want to use it immediately)
az synapse sql pool pause --name $poolname --workspace-name $SynapseName --resource-group $RG

# Resume the pool
az synapse sql pool resume --name $poolname --workspace-name $SynapseName --resource-group $RG

# Let's install the IR Runtime on our Windows Box...
# https://www.microsoft.com/en-us/download/details.aspx?id=39717
mstsc /v:Winserver.bwdemo.io /w:1280 /h:720

# Let us also grab the new sqlcmd
$URL=(((Invoke-WebRequest https://api.github.com/repos/microsoft/go-sqlcmd/releases/latest).Content | ConvertFrom-Json).assets `
            | Where-Object {$_.content_type -eq 'application/zip'} |Where-Object { $_.name -like '*windows-x64*'}).browser_download_url
$URL
curl.exe -o sqlcmd.zip $URL -L
Expand-Archive .\sqlcmd.zip -Force

# Which has configs (and a modern interface)
.\sqlcmd\sqlcmd config view

# Make sure your source DB has a valid owner and Master key!
.\sqlcmd\sqlcmd query "ALTER AUTHORIZATION ON DATABASE:: AdventureWorks2019 TO [demo]" --database master
.\sqlcmd\sqlcmd query "CREATE MASTER KEY ENCRYPTION BY PASSWORD ='R@M@l@m@D!nD0ng'" --database AdventureWorks2019

# we can also create a new config for synapse
$env:sqlcmdpassword = $password
.\sqlcmd\sqlcmd config add-user --username $username --name synapse --password-encryption none
.\sqlcmd\sqlcmd config add-endpoint --address (($SynapseName) + ".sql.azuresynapse.net") --name synapse
.\sqlcmd\sqlcmd config add-context --endpoint synapse --user synapse --name synapse

# We have a second context
.\sqlcmd\sqlcmd config get-contexts

# The new one is our current context
.\sqlcmd\sqlcmd query "SELECT @@ServerName"

# While we're at it... Create a Master Key on our synapse pool
.\sqlcmd\sqlcmd query "CREATE MASTER KEY" --database $poolname

# And we can even simply add it to ADS
.\sqlcmd\sqlcmd open ads

# Jump between contexts
.\sqlcmd\sqlcmd config use-context Winserver
.\sqlcmd\sqlcmd query "SELECT @@ServerName"

# If lost, get help...
.\sqlcmd\sqlcmd --help
.\sqlcmd\sqlcmd config --help

# We still need an...
# - Linked Service to Storage
# - Integration Runtime
# - Linked Service to SQL
# - Synapse Link

# And prepare the rest in the Portal...
Start-Process ("https://portal.azure.com/#@" + (az account show --query tenantId -o tsv) + "/resource" + (az group show -n $RG --query id -o tsv))


# When done, tidy up...
az group delete -n $RG --yes
.\sqlcmd\sqlcmd config delete-context synapse
# Let's check out our environment
# We run a few VMs on Hyper-V
Get-VM

# What does that look like in k8s?
kubectl get nodes
kubectl get nodes -o wide

kubectl delete ns squil
kubectl get pods

# A big time factor is image download - so we've pre-pulled them
kubectl get nodes (kubectl get nodes -o jsonpath="{.items[1].metadata.name}" ) -o jsonpath="{range .status.images[*]}{.names[1]}{'\n'}{end}" | grep arcdata 

# It's ~ 30 GB (for current and previous version) - PER WORKER!
$TotalSize = 0
((kubectl get nodes  (kubectl get nodes -o jsonpath="{.items[1].metadata.name}" )  -o jsonpath="{range .status.images[*]}{.sizeBytes}{'\t'}{.names[1]}{'\n'}{end}" | grep arcdata).Split("`t") | grep -v mcr).Split("`n") | ForEach-Object { $TotalSize += $_}
[Math]::Round(($TotalSize/1024/1024),2)

# OK, let's login to Azure
$subscriptionName = "Azure Data Demos"
# az login --only-show-errors -o table --query Dummy
az account set -s $SubscriptionName

# Set some variables
$RG="ArcDataRG"
$Region="eastus"
$Subscription=(az account show --query id -o tsv)
$k8sNamespace="arc"

# And credentials
$admincredentials = New-Object System.Management.Automation.PSCredential ('arcadmin', (ConvertTo-SecureString -String 'P@ssw0rd' -AsPlainText -Force))
$ENV:AZDATA_USERNAME="$($admincredentials.UserName)"
$ENV:AZDATA_PASSWORD="$($admincredentials.GetNetworkCredential().Password)"
$ENV:SQLCMDPASSWORD="$($admincredentials.GetNetworkCredential().Password)"
$ENV:ACCEPT_EULA='yes'
$ENV:SQLCMDPASSWORD=$ENV:AZDATA_PASSWORD

# Create an RG
az group create -l $Region -n $RG

# We could deploy direct from Portal (requires arc connected k8s!) - Jes
Start-Process https://portal.azure.com/#create/Microsoft.DataController

# Let's stick to indirect for today
# Deploy DC from Command Line - Ben
az arcdata dc create --connectivity-mode Indirect --name arc-dc-kubeadm --k8s-namespace $k8sNamespace `
    --subscription $Subscription `
    -g $RG -l eastus --storage-class local-storage `
    --profile-name azure-arc-kubeadm --infrastructure onpremises --use-k8s

# Check ADS while running

# This created a new Namespace for us
kubectl get namespace

# Check the pods that got created
kubectl get pods -n $k8sNamespace 

# Check Status of the DC
az arcdata dc status show --k8s-namespace arc --use-k8s

# Add Controller in ADS

# Create MIs
$gpinstance = "mi-gp"
# $bcinstance = "mi-bc"

# General Purpose 
az sql mi-arc create -n $gpinstance --k8s-namespace $k8sNamespace  --use-k8s `
--storage-class-data local-storage `
--storage-class-datalogs local-storage `
--storage-class-logs local-storage `
--cores-limit 4 --cores-request 2 `
--memory-limit 8Gi --memory-request 4Gi `
--tier GeneralPurpose --dev

# Everything in Arc-enabled Data Services is also Kubernetes native!
kubectl edit sqlmi $gpinstance -n $k8sNamespace

# Business Critical 
#az sql mi-arc create --name $bcinstance --k8s-namespace $k8sNamespace `
#--tier BusinessCritical --dev --replicas 3 `
#--cores-limit 8 --cores-request 2 --memory-limit 32Gi --memory-request 8Gi `
#--volume-size-data 20Gi --volume-size-logs 5Gi --volume-size-backups 20Gi `
#--collation Turkish_CI_AS --agent-enabled true --use-k8s

# We can scale our Instances
# az sql mi-arc update --name $gpinstance --cores-limit 8 --cores-request 4 `
#                --memory-limit 16Gi --memory-request 8Gi --k8s-namespace $k8sNamespace --use-k8s

# Let's restore AdventureWorks to our GP Instance - Ben
copy-item e:\Backup\AdventureWorks2019.bak .
kubectl cp AdventureWorks2019.bak mi-gp-0:/var/opt/mssql/data/AdventureWorks2019.bak -n $k8sNamespace -c arc-sqlmi
Remove-Item AdventureWorks2019.bak

# We can see the file
kubectl exec mi-gp-0 -n $k8sNamespace -c arc-sqlmi -- ls -l /var/opt/mssql/data/AdventureWorks2019.bak

# We could restore in the Pod - or using the Instance's Endpoint
kubectl get sqlmi $gpinstance -n $k8sNamespace
$SQLEndpoint=(kubectl get sqlmi $gpinstance -n $k8sNamespace -o jsonpath='{ .status.primaryEndpoint }')

# No AdventureWorks
sqlcmd -S $SQLEndpoint -U $ENV:AZDATA_USERNAME  -Q "SELECT Name FROM sys.Databases"

# Restore
sqlcmd -S $SQLEndpoint -U $ENV:AZDATA_USERNAME  -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'"

# Tadaaaaaa
sqlcmd -S $SQLEndpoint -U $ENV:AZDATA_USERNAME  -Q "SELECT Name FROM sys.Databases"

# We can add, managed, monitor and query those from ADS!

# All this has full built-in HA through k8s and also MI when in BC tier

# Upgrades
# Check versions
az arcdata dc list-upgrades -k $k8sNamespace

$SQLEndpoint=(kubectl get sqlmi $gpinstance -n $k8sNamespace -o jsonpath='{ .status.primaryEndpoint }')
sqlcmd -S $SQLEndpoint -U $ENV:AZDATA_USERNAME -Q "SELECT @@version"

az sql mi-arc show -n $gpinstance --use-k8s --k8s-namespace $k8sNamespace | ConvertFrom-Json
# az sql mi-arc upgrade -n $gpinstance --use-k8s --k8s-namespace $k8sNamespace

# Backup / Restore

$PointInTime=(Get-Date).AddSeconds(-120).ToString("yyyy-MM-ddTHH:mm:ssZ") 
$PointInTime

az sql midb-arc restore --managed-instance $gpinstance --name AdventureWorks2019 --dest-name AdventureWorks2019_Restore `
     --k8s-namespace arc --time $PointInTime --use-k8s

kubectl get SqlManagedInstanceRestoreTask -n $k8sNamespace

sqlcmd -S $SQLEndpoint -U $ENV:AZDATA_USERNAME  -Q "SELECT Name FROM sys.Databases"

# Connect to Azure Monitor:
# Create Service Principal
$SP=(az ad sp create-for-rbac --name http://ArcDemoSP --role Contributor --scope subscriptions/$Subscription| ConvertFrom-Json)

# Add Role
az role assignment create --assignee $SP.appId --role "Monitoring Metrics Publisher" --scope subscriptions/$Subscription

# Create Log Analytics Workspace and retrieve it's credentials
$LAWS=(az monitor log-analytics workspace create -g $RG -n ArcLAWS| ConvertFrom-Json)
$LAWSKEYS=(az monitor log-analytics workspace get-shared-keys -g $RG -n ArcLAWS | ConvertFrom-Json)

# For Direct connected mode:
# Connect the Kubernetes Cluster to Azure (Arc-enabled Kubernetes)
# Enable the Cluster for Custom Locations
# Deploy Custom Location and DC from Portal

# In indirect connected mode:

# Store keys
$Env:SPN_AUTHORITY='https://login.microsoftonline.com'
$Env:WORKSPACE_ID=$LAWS.customerId
$Env:WORKSPACE_SHARED_KEY=$LAWSKEYS.primarySharedKey
$Env:SPN_CLIENT_ID=$SP.appId
$Env:SPN_CLIENT_SECRET=$SP.password
$Env:SPN_TENANT_ID=$SP.tenant
$Env:AZDATA_VERIFY_SSL='no'

# Export our logs and metrics (and usage)
# az arcdata dc export -t usage --path usage.json -k $k8sNamespace --force --use-k8s
az arcdata dc export -t metrics --path metrics.json -k $k8sNamespace --force --use-k8s
az arcdata dc export -t logs --path logs.json -k $k8sNamespace --force --use-k8s

# Upload the data to Azure - this should be a scheduled job.
# az arcdata dc upload --path usage.json
az arcdata dc upload --path metrics.json
az arcdata dc upload --path logs.json

remove-item *.json

# Check in portal
Start-Process ("https://portal.azure.com/#@"+ (az account show --query tenantId -o tsv) + "/resource" + (az group show -n $RG --query id -o tsv))

# Cleanup when done
kubectl delete namespace arc
az group delete -g $RG --yes
az ad sp delete --id $SP.appId
# az logout
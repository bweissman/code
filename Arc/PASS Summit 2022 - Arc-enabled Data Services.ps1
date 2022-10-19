# Making sure we're on the correct cluster
kubectl config use-context kubeadm

# Set some variables
$Subscription=(az account show --query id -o tsv)
$k8sNamespace="arc"
kubectl config set-context --current --namespace=$k8sNamespace

# And credentials
$admincredentials = New-Object System.Management.Automation.PSCredential ('arcadmin', (ConvertTo-SecureString -String 'P@ssw0rd' -AsPlainText -Force))
$ENV:AZDATA_USERNAME="$($admincredentials.UserName)"
$ENV:AZDATA_PASSWORD="$($admincredentials.GetNetworkCredential().Password)"
$ENV:SQLCMDPASSWORD="$($admincredentials.GetNetworkCredential().Password)"
$ENV:ACCEPT_EULA='yes'
$ENV:SQLCMDPASSWORD=$ENV:AZDATA_PASSWORD

# Pre-Pulling images saves time!
# It's almost 40 GB (for current and previous version) - PER WORKER!
code C:\demo\pre-deploy\pre-pull.ps1

# We could deploy direct from Portal (requires arc connected k8s!)
# https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli
Start-Process https://portal.azure.com/#create/Microsoft.DataController

# Let's stick to indirect for today
# Deploy DC from Command Line
az arcdata dc create --connectivity-mode Indirect --name arc-dc-kubeadm --k8s-namespace $k8sNamespace `
    --subscription $Subscription `
    -g PASSPreconRG -l eastus --storage-class nfs-storage `
    --profile-name azure-arc-kubeadm --infrastructure onpremises --use-k8s
  
# Check ADS while running

# This created a new Namespace for us
kubectl get namespace

# Check the pods that got created
kubectl get pods -n $k8sNamespace 

# Check Status of the DC
az arcdata dc status show --k8s-namespace $k8sNamespace  --use-k8s

# We can also use kubectl
kubectl get datacontroller -n arc

# Or edit the controller's settings
kubectl edit datacontroller -n arc

# Or pre-create our own config before deployment (LoadBalancer, Ports etc.):
az arcdata dc config init --path customarc --force --source azure-arc-kubeadm
code customarc/control.json

# Add Controller in ADS

# Create MIs
$gpinstance = "mi-gp"
$bcinstance = "mi-bc"

# General Purpose 
az sql mi-arc create -n $gpinstance --k8s-namespace $k8sNamespace  --use-k8s `
--storage-class-data nfs-storage `
--storage-class-datalogs nfs-storage `
--storage-class-logs nfs-storage `
--storage-class-backups nfs-storage `
--cores-limit 4 --cores-request 2 `
--memory-limit 8Gi --memory-request 4Gi `
--tier GeneralPurpose --dev

# Check the pods that got created
kubectl get pods -n $k8sNamespace 

# This also provisioned all our PVCs etc
ssh -t "demo@storage" 'ls /srv/exports/volumes/dynamic/'

# Everything in Arc-enabled Data Services is also Kubernetes native!
kubectl edit sqlmi $gpinstance -n $k8sNamespace

# Business Critical 
az sql mi-arc create --name $bcinstance --k8s-namespace $k8sNamespace `
--tier BusinessCritical --dev --replicas 3 `
--cores-limit 8 --cores-request 2 --memory-limit 32Gi --memory-request 8Gi `
--volume-size-data 20Gi --volume-size-logs 5Gi --volume-size-backups 20Gi `
--storage-class-data nfs-storage --storage-class-datalogs nfs-storage --storage-class-logs nfs-storage --storage-class-backups nfs-storage `
--collation Turkish_CI_AS --agent-enabled true --use-k8s

# We could have added (local!) AD Auth 
# https://learn.microsoft.com/en-us/azure/azure-arc/data/deploy-active-directory-sql-managed-instance

# We now have 2 MIs!
az sql mi-arc list --k8s-namespace $k8sNamespace  --use-k8s -o table

# We can scale our Instances - here or in ADS
# az sql mi-arc update --name $gpinstance --cores-limit 8 --cores-request 4 `
#                --memory-limit 16Gi --memory-request 8Gi --k8s-namespace $k8sNamespace --use-k8s

# Let's restore AdventureWorks to our GP Instance 
kubectl cp AdventureWorks2019.bak mi-gp-0:/var/opt/mssql/data/AdventureWorks2019.bak -n $k8sNamespace -c arc-sqlmi

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

# We can add, managed, monitor and query those from ADS or through Grafana/Kibana

# Or we use a TelemetryRouter
# https://learn.microsoft.com/en-us/azure/azure-arc/data/deploy-telemetry-router

# All this has full built-in HA through k8s and also MI when in BC tier
# General purpose - HA is provided by k8s 
# Verify HA 
kubectl get pods --namespace $k8sNamespace -l app.kubernetes.io/instance=mi-gp
# Delete primary 
kubectl delete pod mi-gp-0 --namespace $k8sNamespace
kubectl get pods --namespace $k8sNamespace -l app.kubernetes.io/instance=mi-gp -w
sqlcmd -S $SQLEndpoint -U $ENV:AZDATA_USERNAME  -Q "SELECT Name FROM sys.Databases"

# Business criticial - HA is an AG
# Determine which Pod is primary 
for ($i=0; $i -le 2; $i++){
kubectl get pod ("$($bcinstance)-$i") -n $k8sNamespace -o jsonpath="{.metadata.labels}" | ConvertFrom-Json | grep -v controller | grep -v app | grep -v arc-resource | grep -v -e '^$'
}

# Delete a Pod
kubectl delete pod mi-bc-0 -n $k8sNamespace
kubectl get pods -n $k8sNamespace -l app.kubernetes.io/instance=mi-bc

# Determine which is primary now
for ($i=0; $i -le 2; $i++){
    kubectl get pod ("$($bcinstance)-$i") -n $k8sNamespace -o jsonpath="{.metadata.labels}" | ConvertFrom-Json | grep -v controller | grep -v app | grep -v arc-resource | grep -v -e '^$'
    }

# And we can query this immediately!
$SQLEndpoint_BC=(kubectl get sqlmi $bcinstance -n $k8sNamespace -o jsonpath='{ .status.primaryEndpoint }')
sqlcmd -S $SQLEndpoint_BC -U $ENV:AZDATA_USERNAME  -Q "SELECT Name FROM sys.Databases"

# If things go wrong, you can re-provision individual replicas:
# az sql mi-arc reprovision-replica -n <instance_name-replica_number> -k <namespace> --use-k8s

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

# Lets modify some data...
sqlcmd -S $SQLEndpoint -U $ENV:AZDATA_USERNAME -Q "Update adventureworks2019.person.person set Lastname = 'Weissman',Firstname='Ben'"

# ooops - that was dumb
# Let's fix it
$PointInTime=(Get-Date).AddSeconds(-120).ToString("yyyy-MM-ddTHH:mm:ssZ") 
$PointInTime
az sql midb-arc restore --managed-instance $gpinstance --name AdventureWorks2019 --dest-name AdventureWorks2019_Restore `
     --k8s-namespace arc --time $PointInTime --use-k8s 
 
# And:
sqlcmd -S $SQLEndpoint -U $ENV:AZDATA_USERNAME -Q "SELECT  TOP 3 Firstname,lastname from adventureworks2019.person.person"
sqlcmd -S $SQLEndpoint -U $ENV:AZDATA_USERNAME -Q "SELECT  TOP 3 Firstname,lastname from adventureworks2019_restore.person.person"

# No Differential, Log or any other manual backups


# Connect to Azure Monitor:
# Create Service Principal
$SP=(az ad sp create-for-rbac --name http://PASSArcDemoSP --role Contributor --scope subscriptions/$Subscription| ConvertFrom-Json)

# Add Role
az role assignment create --assignee $SP.appId --role "Monitoring Metrics Publisher" --scope subscriptions/$Subscription

# Grab our LAWS ID and credentials again
$LAWS=(az monitor log-analytics workspace create -g PASSPreconRG -n ArcLAWS| ConvertFrom-Json)
$LAWSKEYS=(az monitor log-analytics workspace get-shared-keys -g PASSPreconRG -n ArcLAWS | ConvertFrom-Json)

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
Start-Process ("https://portal.azure.com/#@"+ (az account show --query tenantId -o tsv) + "/resource" + (az group show -n PASSPreconRG --query id -o tsv))

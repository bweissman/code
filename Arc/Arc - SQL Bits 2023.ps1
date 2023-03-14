# Making sure we're on the correct cluster
kubectl config use-context kubeadm

# Set some variables
$Region = "eastus"
$RG = "BitsArc"
az account set -s "Azure Data Demos"
$Subscription=(az account show --query id -o tsv)
$k8sNamespace="arc"
kubectl config set-context --current --namespace=$k8sNamespace

# And credentials
$admincredentials = New-Object System.Management.Automation.PSCredential ('arcadmin', (ConvertTo-SecureString -String 'P@ssw0rd' -AsPlainText -Force))
$ENV:AZDATA_USERNAME="$($admincredentials.UserName)"
$ENV:AZDATA_PASSWORD="$($admincredentials.GetNetworkCredential().Password)"
$ENV:ACCEPT_EULA='yes'

# We could deploy direct from Portal (requires arc connected k8s!)
# https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli
Start-Process https://portal.azure.com/#create/Microsoft.DataController

# Let's stick to indirect for today
# Deploy DC from Command Line
az arcdata dc create --connectivity-mode Indirect --name arc-dc-kubeadm --k8s-namespace $k8sNamespace `
    --subscription $Subscription `
    -g $RG -l $Region --storage-class nfs-storage `
    --profile-name azure-arc-kubeadm --infrastructure onpremises --use-k8s
  
# Check Status of the DC
az arcdata dc status show --k8s-namespace $k8sNamespace  --use-k8s

kubectl edit arcdc

kubectl get pods -l plane=control

# We could also do this in ADS... 


# We could deploy Postgres...
# But we'll deploy a Managed Instance

# Business Critical 
$bcinstance="mi-bc"
az sql mi-arc create --name $bcinstance --k8s-namespace $k8sNamespace `
--tier BusinessCritical --dev --replicas 3 `
--cores-limit 8 --cores-request 2 --memory-limit 32Gi --memory-request 8Gi `
--volume-size-data 20Gi --volume-size-logs 5Gi --volume-size-backups 20Gi `
--storage-class-data local-storage --storage-class-datalogs local-storage --storage-class-logs local-storage --storage-class-backups nfs-storage `
--collation Turkish_CI_AS --agent-enabled true --use-k8s

# To delete (takes ~ 2 seconds):
# az sql mi-arc delete --name $bcinstance --use-k8s

# Check the pods that got created
kubectl get pods -l app.kubernetes.io/instance=mi-bc

# Everything in Arc-enabled Data Services is also Kubernetes native!
kubectl edit sqlmi $bcinstance

# Let's have AdventureWorks restored quickly...
copy-item E:\backup\AdventureWorks2019.bak . -Force
kubectl cp AdventureWorks2019.bak mi-bc-0:/var/opt/mssql/data/AdventureWorks2019.bak -c arc-sqlmi


# Let us also grab the new sqlcmd
$URL=(((Invoke-WebRequest https://api.github.com/repos/microsoft/go-sqlcmd/releases/latest).Content | ConvertFrom-Json).assets `
            | Where-Object {$_.content_type -eq 'application/zip'} |Where-Object { $_.name -like '*windows-x64*'}).browser_download_url
$URL
curl.exe -o sqlcmd.zip $URL -L
Expand-Archive .\sqlcmd.zip -Force

# Grab endpoint
$Endpoint=(kubectl get sqlmi $bcinstance -o jsonpath='{ .status.endpoints.primary }').split(',')
$env:sqlcmdpassword = $ENV:AZDATA_PASSWORD

# Create a new context for sqlcmd
.\sqlcmd\sqlcmd config add-user --username $ENV:AZDATA_USERNAME --name arcmi --password-encryption none
.\sqlcmd\sqlcmd config add-endpoint --address $Endpoint[0] --port $Endpoint[1] --name arcmi
.\sqlcmd\sqlcmd config add-context --endpoint arcmi --user arcmi --name arcmi

# We have a new context (which is the current)
.\sqlcmd\sqlcmd config get-contexts

# We can run a restore
.\sqlcmd\sqlcmd query "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'"
.\sqlcmd\sqlcmd query "SELECT name from sys.databases"

# We can also check that in ADS
.\sqlcmd\sqlcmd open ads

# We could have added (local!) AD Auth 
# https://learn.microsoft.com/en-us/azure/azure-arc/data/deploy-active-directory-sql-managed-instance

# We can see our endpoint and state
az sql mi-arc list --k8s-namespace $k8sNamespace  --use-k8s -o table

# We can scale our Instances - here or in ADS
# az sql mi-arc update --name $gpinstance --cores-limit 8 --cores-request 4 `
#                --memory-limit 16Gi --memory-request 8Gi --k8s-namespace $k8sNamespace --use-k8s

# All this has full built-in HA through k8s and also MI when in BC tier
# General purpose - HA is provided by k8s 
# Business criticial - HA is an AG
# Determine which Pod is primary 
for ($i=0; $i -le 2; $i++){
kubectl get pod ("$($bcinstance)-$i")  -o jsonpath="{.metadata.labels}" | ConvertFrom-Json | grep -v controller | grep -v app | grep -v arc-resource | grep -v -e '^$'
}

# Delete a Pod
kubectl delete pod mi-bc-0 
kubectl get pods -l app.kubernetes.io/instance=mi-bc

# Determine which is primary now
for ($i=0; $i -le 2; $i++){
    kubectl get pod ("$($bcinstance)-$i") -o jsonpath="{.metadata.labels}" | ConvertFrom-Json | grep -v controller | grep -v app | grep -v arc-resource | grep -v -e '^$'
    }

# And we can query this immediately!
.\sqlcmd\sqlcmd query "SELECT Name FROM sys.Databases"

# If things go wrong, you can re-provision individual replicas:
# az sql mi-arc reprovision-replica -n <instance_name-replica_number> -k <namespace> --use-k8s

# Upgrades
# Check versions
az arcdata dc list-upgrades -k $k8sNamespace
# az arcdata dc upgrade -k $k8sNamespace --use-k8s --desired-version "v1.17.0_2023-03-14"
# Or check ADS! 
$ENV:AZDATA_PASSWORD | Set-Clipboard
# where:
# We can add, managed, monitor and query those through Grafana/Kibana
# We could also stream to Kafka
# Or we use a TelemetryRouter
# https://learn.microsoft.com/en-us/azure/azure-arc/data/deploy-telemetry-router

# Backup / Restore
# Lets modify some data...
.\sqlcmd\sqlcmd query "Update adventureworks2019.person.person set Lastname = 'Weissman',Firstname='Ben'"

# ooops - that was dumb
# Let's fix it
$PointInTime=(Get-Date).AddSeconds(-120).ToString("yyyy-MM-ddTHH:mm:ssZ") 
$PointInTime
az sql midb-arc restore --managed-instance $bcinstance --name AdventureWorks2019 --dest-name AdventureWorks2019_Restore `
     --k8s-namespace arc --time $PointInTime --use-k8s 
 
# And:
.\sqlcmd\sqlcmd query "SELECT TOP 3 Firstname,lastname from adventureworks2019.person.person"
.\sqlcmd\sqlcmd query "SELECT TOP 3 Firstname,lastname from adventureworks2019_restore.person.person"

# No Differential, Log or any other manual backups


# Connect to Azure Monitor:
az group create --name $RG --location $Region
# Create Service Principal
$SP=(az ad sp create-for-rbac --name http://BitsArcDemoSP --role Contributor --scope subscriptions/$Subscription| ConvertFrom-Json)

# Add Role
az role assignment create --assignee $SP.appId --role "Monitoring Metrics Publisher" --scope subscriptions/$Subscription

# Grab our LAWS ID and credentials again
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
az group delete -g $RG --yes
az ad sp delete --id $SP.appId
kubectl delete namespace $k8sNamespace
.\sqlcmd\sqlcmd config delete-context --name arcmi
# az logout
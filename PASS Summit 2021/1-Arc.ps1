Clear-Host
cd 'C:\ArcDataServices'
$RG="ArcDataRG"
$Subscription=(az account show --query id -o tsv)
$ENV:ACCEPT_EULA='yes'
$ENV:AZDATA_USERNAME='admin'
$ENV:AZDATA_PASSWORD='P@ssw0rdP@ssw0rd'

az group create -l eastus -n $RG

kubectl get nodes -o wide

kubectl get nodes worker-3  -o jsonpath="{range .status.images[*]}{.names[1]}{'\n'}{end}" | grep arcdata 

$TotalSize = 0
((kubectl get nodes worker-3  -o jsonpath="{range .status.images[*]}{.sizeBytes}{'\t'}{.names[1]}{'\n'}{end}" | grep arcdata).Split("`t") | grep -v mcr).Split("`n") | Foreach { $TotalSize += $_}
[Math]::Round(($TotalSize/1024/1024),2)


# We could deploy direct from Portal (requires arc connected k8s!)
Start-Process https://portal.azure.com/#create/Microsoft.DataController

# Deploy DC from Command Line
az arcdata dc create --connectivity-mode Indirect --name arc-dc-kubeadm --k8s-namespace arc `
    --subscription $Subscription `
    -g $RG -l eastus --storage-class local-storage `
    --profile-name azure-arc-kubeadm --infrastructure onpremises --use-k8s

# Check ADS while running

# Check the pods that got created
kubectl get pods -n arc

# Check Status
az arcdata dc status show --k8s-namespace arc --use-k8s

# Add Controller in ADS

# Create MI
az sql mi-arc create -n mi-1 --k8s-namespace arc --use-k8s `
        --storage-class-backups local-storage `
        --storage-class-data local-storage `
        --storage-class-datalogs local-storage `
        --storage-class-logs local-storage `
        --cores-limit 1 --cores-request 1 `
        --memory-limit 2Gi --memory-request 2Gi --dev

az sql mi-arc list --k8s-namespace arc --use-k8s -o table

kubectl get sqlmi -n arc

kubectl get pods -n arc -o wide

kubectl describe pod mi-1-0 -n arc

# Could deploy as AG using --replicas 2/3
# az sql mi-arc create -n mi-2 --k8s-namespace arc --use-k8s --replicas 3
az sql mi-arc create -n mi-2 --k8s-namespace arc --use-k8s --replicas 2 --dev

# Could also deploy / resize from ADS and access Grafana/Kibana
$ENV:AZDATA_PASSWORD | Set-Clipboard

# Backups
kubectl edit sqlmi mi-1 -n arc

# Updates: 
az arcdata dc list-upgrades -k arc

# az arcdata dc update
# az arcdata sql mi-arc update

# Connect to Azure Monitor:
# Create Service Principal
$SP=(az ad sp create-for-rbac --name http://ArcDemoSP | ConvertFrom-Json)
$SP | Out-String | grep -v password

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
# az arcdata dc export -t usage --path usage.json -k arc --force --use-k8s
az arcdata dc export -t metrics --path metrics.json -k arc --force --use-k8s
az arcdata dc export -t logs --path logs.json -k arc --force --use-k8s

# Upload the data to Azure - this should be a scheduled job.
az arcdata dc upload --path metrics.json
az arcdata dc upload --path logs.json

remove-item *.json

# Check in portal
Start-Process ("https://portal.azure.com/#@"+ (az account show --query tenantId -o tsv) + "/resource" + (az group show -n $RG --query id -o tsv))

# Cleanup when done
kubectl delete namespace arc
az group delete -g $RG --yes
az ad sp delete --id $SP.appId

# az group delete -g ArcDemoRG --yes
# az vm deallocate -g PS --name PSDemoV3
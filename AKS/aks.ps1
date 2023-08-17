Set-Location ~/desktop/AKS
#choco upgrade kubernetes-cli -y
#az bicep upgrade
Clear-Host
# Parameters
$RG="AKSRG"
$Region="eastus"
$ClusterName=""
$tenant=""
$winpw=""

# Login and create RG
az login --tenant $Tenant
az account set -s "Azure Data Demos"
az group create -l $Region -n $RG

# Azure CLI - I ran this before
az aks create -g $RG -n $ClusterName --generate-ssh-keys `
        --network-plugin azure `
        --windows-admin-username azure --windows-admin-password $winpw

# Add a Windows Node
az aks nodepool add  --resource-group $RG --cluster-name $ClusterName `
                     --os-type Windows --name npwind --node-count 1

#az aks create -g $RG -n AKS-AZCLI-SMALL --node-count 2

#az aks create --generate-ssh-keys -g $RG -n AKS-AZCLI-LARGE `
#             --node-count 4 --node-vm-size Standard_d16_v4

az aks list -o table

# And look in Portal
Start-Process https://portal.azure.com/#view/HubsExtension/BrowseResource/resourceType/Microsoft.ContainerService%2FmanagedClusters

# PowerShell and az module
# Connect-AzAccount -Subscription (az account show --query id -o tsv) -Tenant $tenant

Get-AzAksVersion -Location $Region | Select-Object OrchestratorVersion

#New-AzAksCluster -ResourceGroupName $RG `
#                    -Name AKS-PS `
#                    -NodeCount 4 `
#                    -NodeVmSize Standard_d16_v4 `
#                    -KubernetesVersion 1.26.6 

Get-AzAksCluster -ResourceGroupName $RG | Select-Object Name

# ARM Templates
code aks-arm.json

az bicep decompile --file aks-arm.json --force
code aks-arm.bicep

#az Deployment group create -f aks-arm.bicep `
#                -g $RG `
#                --parameters sshRSAPublicKey=$SSH clusterName=AKS-ARM-BICEP agentCount=1

# Communicating with our cluster
az aks get-credentials -g $RG -n $ClusterName

kubectl cluster-info
kubectl get nodes -o wide

kubectl create deployment nginx --image=nginx

code nginx.yaml
kubectl apply -f nginx.yaml

kubectl get service nginx -w
$SERVICEIP=(kubectl get service nginx -o jsonpath='{ .status.loadBalancer.ingress[0].ip }')
kubectl get pods
Start-Process http://$SERVICEIP

code windows-app.yaml
kubectl apply -f windows-app.yaml

kubectl get pods -o wide

# Move imperative nginx to linux node:
#       nodeSelector:
#            "kubernetes.io/os": linux
kubectl edit deployment nginx 

kubectl get pods -o wide -w

kubectl describe pod -l app=sample

# az group delete --resource-group $RG --yes
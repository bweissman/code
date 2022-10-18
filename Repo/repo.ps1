# Login 
# az login
# az account set -s "Azure Data Demos"

# Parameters
$RG="AKS-Repo"
$Region="eastus"
$AKSName="AKSRepo"
$k8sNamespace="arcdata"
$ENV:AZDATA_USERNAME="arcadmin"
$ENV:AZDATA_PASSWORD="P@ssw0rd"
$ENV:ACCEPT_EULA='yes'
$Subscription=(az account show --query id -o tsv)

# Create RG & AKS
az group create -l $Region -n $RG
az aks create -g $RG -n $AKSName --generate-ssh-keys --node-count 1 --node-vm-size Standard_d4s_v4
az aks get-credentials -g $RG -n $AKSName

# Deploy Arc
az arcdata dc create --connectivity-mode Indirect --name arc-dc --k8s-namespace $k8sNamespace `
    --subscription $Subscription `
    -g $RG -l $Region --storage-class azurefile `
    --profile-name azure-arc-aks-default-storage --infrastructure azure --use-k8s

# This will fail (only controller and controldb get deployed, then waits indefinitely)
kubectl logs controldb-0 -n arcdata -c fluentbit
#2022/10/18 08:13:39.341278 Waiting for CA certificates...
#2022/10/18 08:13:40.341514 Waiting for CA certificates...
#2022/10/18 08:13:41.341700 Waiting for CA certificates...

# Same when using different storage classes (azurefile-premium, azurefile-csi-premium, default)
# Same when using different VM Size (Standard_d16s_v4)
# Same when using 2 nodes using Standard_d2s_v4 size
# Same when using 3 nodes using Standard_d2s_v4 size
# Same when using Kubernetes 1.24.6

# Cleanup
az group delete -g $RG --yes
remove-item ~/.kube/config
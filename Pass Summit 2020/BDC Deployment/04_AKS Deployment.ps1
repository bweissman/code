az login
az account set -s <YourSubscription>
az aks create --name bdcaks --resource-group <YourRG> --generate-ssh-keys --node-vm-size Standard_D8s_v3 --node-count 2
az aks get-credentials --overwrite-existing --name bdcaks --resource-group <YourRG> --admin
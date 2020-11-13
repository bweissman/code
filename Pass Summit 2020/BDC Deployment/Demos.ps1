Set-Location C:\users\bdc\Desktop

# Let's start by taking a look at the preconfigured AKS Cluster
kubectl config use-context bdcaks-admin
kubectl cluster-info
kubectl get nodes -o wide

# What about the kubeadm?
kubectl config use-context kubernetes-admin@kubernetes
kubectl cluster-info
kubectl get nodes -o wide

# kubectl (just like azdata and ADS!) is cross platform!
ssh bdc@bdclinux
# kubectl get nodes -o wide

# Usually, we would now join additional nodes to the cluster
# but today we stick to a single node and local storage
# kubeadm token create --print-join-command 
# Still: Storage and compute capacity of your k8s cluster are the first thing to consider!

# exit

# Let's take a quick look at our deployment scripts
Start-Process https://bookmark.ws/BDCDeploy

# While we're at it... Install the Data Virt Extension!

# Just like k8s, BDC can be deployed through code!
azdata bdc config init --source kubeadm-dev-test --path kubeadm-custom -f

# Let's take a look at control.json and bdc.json
# this is where we modify EVERYTHING (some settings like root containers or AD auth would need to be added)
# Choose wisely - there is no resize!
notepad++.exe .\kubeadm-custom\bdc.json .\kubeadm-custom\control.json

# Want a wizard?
# One that even creates the k8s for you? 
azuredatastudio.cmd

# How's that progressing?
kubectl config use-context bdcaks-admin
kubectl get namespace
kubectl get pods -n mssql-cluster # --watch
# This will take quite a bit longer without pre-pulled images!

# While this is running...
# Didn't we say this is cross platform?
# Let's kick of another one on our Linux machine!
# Open a putty session as well so we can watch the progress...
putty
# then ssh into the machine
ssh bdc@bdclinux

# azdata bdc config init --source kubeadm-dev-test --path kubeadm-custom -f
# vi kubeadm-custom/control.json 
# set CU6
# azdata bdc config replace -p kubeadm-custom/control.json -j spec.storage.data.className=local-storage
# azdata bdc config replace -p kubeadm-custom/control.json -j spec.storage.logs.className=local-storage
# azdata bdc create -c kubeadm-custom
# exit

# Let's connect to our controller (could also be done in ADS...)
kubectl config use-context kubernetes-admin@kubernetes
azdata login --namespace mssql-cluster -u admin

# What are our endpoints?
azdata bdc endpoint list
azdata bdc endpoint list -o table

# Which Version are we running?
sqlcmd -S 192.168.1.4,31433 -U admin -Q "SELECT @@VERSION" -P <pw>

# How about an upgrade to CU8...
# We can even do that from here!
azdata bdc upgrade -n mssql-cluster -t 2019-CU8-ubuntu-16.04 -r mcr.microsoft.com/mssql/bdc
# Spoiler: This will take about 30 minutes so we may not get to see the end of it :)

# Which Version are we running now?
sqlcmd -S 192.168.1.4,31433 -U admin -Q "SELECT @@VERSION" -P <pw>
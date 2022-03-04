# SQL on Containers (Here: Docker on Linux)
ssh $SSHTarget

sudo apt install docker docker.io -y
sudo docker pull mcr.microsoft.com/mssql/server:2019-latest

sudo docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=P@ssw0rd" \
   -p 31433:1433 --name sql1 -h sql1 \
   -d mcr.microsoft.com/mssql/server:2019-latest

sudo docker ps -a

sqlcmd -S 127.0.0.1,31433 -U SA -P P@ssw0rd -Q "SELECT @@servername"

# Let's also add a volume to persist our data in another container!
sudo docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=P@ssw0rd" \
   -p 31434:1433 --name sql2 -h sql2 -v sqldata2:/var/opt/mssql \
   -d mcr.microsoft.com/mssql/server:2019-latest
   

sudo docker ps -a

sqlcmd -S 127.0.0.1,31434 -U SA -P P@ssw0rd -Q "SELECT @@servername"

sqlcmd -S 127.0.0.1,31434 -U SA -P P@ssw0rd -Q "CREATE DATABASE VB6isTheBest"

sudo ls -al /var/lib/docker/volumes/sqldata2/_data/data

exit

# We can again access this from external
sqlcmd -S (GetIP($VMName)),31433 -U SA -P P@ssw0rd -Q "SELECT @@servername"
sqlcmd -S (GetIP($VMName)),31434 -U SA -P P@ssw0rd -Q "SELECT @@servername"

cd "C:\Users\bits\Desktop\Code\SQL on Linux, Containers and Kubernetes"



# SQL on Kubernetes
# I have two clusters
kubectl config view -o jsonpath='{range .contexts[*]}{.name}{''\n''}{end}'

# Let's use the small one...
kubectl config use-context kubeadm-small
kubectl get nodes

# We'll create a Namespace
kubectl create namespace mssql
kubectl get namespace
kubectl config set-context --current --namespace=mssql

# It's empty
kubectl get pods

# Let's define storage first
code PVC.yaml
kubectl apply -f .\PVC.yaml
kubectl get pvc

# We'll also need an SA Password
$PASSWORD='P@ssw0rd'
kubectl create secret generic mssql --from-literal=SA_PASSWORD=$PASSWORD

# We can then define our SQL Server
code SQL.yaml
kubectl apply -f SQL.yaml

# Our storage is now bound
kubectl get pvc

# And SQL is coming up
kubectl get deployment
kubectl get pod

# We can also check out the logs of the Pod which is the SQL Log
kubectl logs (kubectl get pods -o jsonpath="{.items[0].metadata.name}" )

# But we can't access it yet...
# Instead of YAML we can also use imperative commands
kubectl expose deployment mssql-deployment --target-port=1433 --type=NodePort

# We now have a service
kubectl get service

$Endpoint= ("$(GetIP("k8s-small-worker-1")),$(kubectl get service mssql-deployment -o jsonpath='{ .spec.ports[*].nodePort }')")
$Endpoint
sqlcmd -S $Endpoint -U SA -P ($PASSWORD) -Q "SELECT @@VERSION"

# Let's restore some data
if ([System.IO.File]::Exists("C:\Users\bits\Desktop\Code\SQL on Linux, Containers and Kubernetes\AdventureWorks2019.bak") -eq $false) {
curl.exe -L -o AdventureWorks2019.bak https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak
}

dir *.bak
kubectl get pods
$Pod=(kubectl get pods -o jsonpath="{.items[0].metadata.name}" )
$Pod
kubectl cp AdventureWorks2019.bak "$($Pod):/var/opt/mssql/data/AdventureWorks2019.bak"

# Our bak is now on the server
kubectl exec -i -t "$($Pod)" -- ls -al /var/opt/mssql/data/AdventureWorks2019.bak

# And we can restore
sqlcmd -S $Endpoint -U SA -P ($PASSWORD)  -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'"

# and woohoooo:
sqlcmd -S $Endpoint -U SA -P ($PASSWORD)  -Q "SELECT Name FROM sys.databases"

# Of course, this is also accessible from any client
$Endpoint | Set-Clipboard
azuredatastudio.cmd

# And we could also just upgrade...
kubectl set image deployment mssql-deployment mssql=mcr.microsoft.com/mssql/server:2019-CU15-ubuntu-20.04
kubectl get pods -w
sqlcmd -S $Endpoint -U SA -P ($PASSWORD) -Q "SELECT @@VERSION"
kubectl logs (kubectl get pods -o jsonpath="{.items[0].metadata.name}" )
sqlcmd -S $Endpoint -U SA -P ($PASSWORD) -Q "SELECT @@VERSION"

# And when we're done...
kubectl delete namespace mssql
kubectl config set-context --current --namespace=default
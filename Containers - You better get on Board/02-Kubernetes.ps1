# Check out my k8s cluster
kubectl get nodes

# We'll create a Namespace
kubectl create namespace mssql
kubectl get namespace
kubectl config set-context --current --namespace=mssql

# It's empty
kubectl get secret,pods,pvc,svc

# Let's deploy SQL Server
kubectl apply -f SQL.yaml

# It's all here
kubectl get secret,pods,pvc,svc

# Can we access it?
$SQL_IP=(kubectl get svc mssql -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sqlcmd -S $SQL_IP -Q "SELECT @@Version"

# Let's check out that password first:
kubectl get secret mssql -o yaml
kubectl get secret mssql -o jsonpath='{.data}'
$EncodedPassword=(kubectl get secret mssql -o jsonpath='{.data}' | convertfrom-json)[0].MSSQL_SA_PASSWORD
$Env:SQLCMDPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($EncodedPassword))

# Let's try again:
sqlcmd -S $SQL_IP -Q "SELECT @@Version"

# This only works if the password hasn't been changed after deployment!

# What else have we got besides a secret (all from the single Yaml)?
code .\SQL.yaml

# We got:
kubectl get statefulset
kubectl get pod
kubectl get pvc
kubectl get configmap
kubectl get svc

# The order doesn't matter!

# Restore data
kubectl cp .\TestDB1.bak mssql-0:/var/opt/mssql/data/TestDB1.bak
sqlcmd -S $SQL_IP -i restore_testdb1.sql

sqlcmd -S $SQL_IP -Q "SELECT name from sys.databases"

# Delete everything
kubectl delete namespace mssql

# So why k8s?
# Persistent endpoints, external storage, scalability, security...
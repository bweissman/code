set-location C:\Users\demo\Desktop\Code\Arc

kubectl get nodes -o wide

kubectl get sc

kubectl get ns

kubectl get crd

kubectl get crd | grep -v metallb

grep ^kind: bootstrapper-unified.yaml
code -d bootstrapper-unified.yaml bootstrapper-unified.dist.yaml

kubectl config set-context --current --namespace=arc

kubectl apply -f bootstrapper-unified.yaml

kubectl get pod -l app=bootstrapper -w

kubectl get crd | grep -v metallb

code controller.yaml

kubectl create secret generic metricsui-admin-secret --from-literal=username=arcadmin --from-literal=password=SuperSecretP@ssw0rd
kubectl create secret generic logsui-admin-secret --from-literal=username=arcadmin --from-literal=password=SuperSecretP@ssw0rd

kubectl get secret logsui-admin-secret -o jsonpath='{ .data }' | ConvertFrom-Json

kubectl apply -f controller.yaml

kubectl get datacontroller

kubectl get pods

kubectl get pvc

kubectl get pods -w

kubectl get datacontroller

kubectl describe datacontroller

kubectl get svc

Start-Process ("https://" + (kubectl get svc metricsui-external-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}') + ":3000")

code sql-mi.yaml

kubectl create secret generic mi-login-secret --from-literal=username=arcadmin --from-literal=password=SuperSecretP@ssw0rd

kubectl apply -f sql-mi.yaml

kubectl get sqlmi

kubectl get pvc -l controller=sql-mi-1

kubectl get pods -w

kubectl get sqlmi

kubectl get svc -l controller=sql-mi-1

$Env:SQLCMDSERVER=(kubectl get svc sql-mi-1-external-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
$env:sqlcmduser='arcadmin'
$env:sqlcmdpassword='SuperSecretP@ssw0rd'
sqlcmd  -Q "SELECT @@Version"

kubectl get sqlmi -o jsonpath='{.items[0].spec.settings}' | ConvertFrom-Json
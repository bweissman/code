[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install azure-data-studio -y
choco install azure-cli -y
choco install kubernetes-cli -y
choco install curl -y
choco install putty -y
choco install notepadplusplus -y
choco install 7zip -y
choco install sqlserver-cmdlineutils -y
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
curl -o azdata.msi https://aka.ms/azdata-msi
msiexec /i azdata.msi /passive
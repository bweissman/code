# I already installed SQL 2025 (from https://www.microsoft.com/en-us/evalcenter/sql-server-2025-download) 
# I used ISO download and ran an unattended install:
# D:\setup.exe /Q /INDICATEPROGRESS /IACCEPTSQLSERVERLICENSETERMS /ACTION=Install /FEATURES=SQLENGINE /INSTANCENAME=MSSQLSERVER /TCPENABLED=1 /SQLSYSADMINACCOUNTS=".\ben"
# I also installed SSMS 21 (from https://aka.ms/ssms/21/release/vs_SSMS.exe)

# Now the rest. 

# Install Choco
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Tools
choco install ollama -y
choco install openssl -y
choco install nginx -y --params '"/installLocation:C:\nginx"'

# Refresh Path
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Let's generate some config files
mkdir C:\Config

@'
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    upstream ollama {
        server 127.0.0.1:11434; 
    }

    server {
        listen 443 ssl;
        server_name model.example.com;

        ssl_certificate "C:/certs/nginx.crt";
        ssl_certificate_key "C:/certs/nginx.key";
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers HIGH:!aNULL:!MD5;

        location / {
            proxy_pass http://ollama;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Origin '';
            proxy_set_header Referer '';
            proxy_connect_timeout 300;
            proxy_send_timeout 300;
            proxy_read_timeout 300;
            send_timeout 300;
        }
    }
}
'@ | Set-Content C:\config\nginx.conf 

@'
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = MS
L = Somewhere
O = IT
OU = DBATeam
CN = my-ai.demo

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = 127.0.0.1
DNS.1 = localhost
'@ | Set-Content C:\config\openssl.cnf

# Certs
mkdir C:\Certs
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout C:\certs\nginx.key -out C:\certs\nginx.crt -config C:\config\openssl.cnf
$certPath = "C:\Certs\nginx.crt"
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
$store.Open("ReadWrite")
$certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $certPath
$store.Add($certificate)
$store.Close()

# nginx
$nginxDir = (Get-ChildItem -Path "C:\nginx" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
copy-item C:\config\nginx.conf $nginxDir\conf\nginx.conf
nssm restart nginx

# Add models to Ollama
ollama pull nomic-embed-text


# Test
$body = @{
    model = "nomic-embed-text"
    prompt = "test"
}  | ConvertTo-Json -Compress
# Ollama through reverse SSL
(Invoke-WebRequest -Uri "https://localhost/api/embeddings" -Method POST -Body $body).Content
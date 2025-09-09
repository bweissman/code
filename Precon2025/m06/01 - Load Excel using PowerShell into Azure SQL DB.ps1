# Install-Module ImportExcel
# Install-Module SQLServer
$dbname="PreconDB"
$sqldbserver="BWPreconSQLDBSRV.database.windows.net"

# az login
$token = az account get-access-token --resource https://database.windows.net --query accessToken -o tsv

$items =Import-Excel -Path C:\Users\Administrator\Desktop\Code\m06\dummy_items.xlsx 
$items | Select-Object -First 3
$ProgressPreference='SilentlyContinue'
$items | Write-SqlTableData -ServerInstance $sqldbserver -DatabaseName $dbname -AccessToken $token -TableName Items -SchemaName dbo -Force
Invoke-DbaQuery -SqlInstance $azuresqldb -Query "SELECT Count(*) FROM [Items]"

# Could also/should use dbatools - especially for larger data! (the SQLServer module is... not fast)
$azuresqldb=Connect-DbaInstance -SqlInstance $sqldbserver -Accesstoken $token -Database $dbname
Invoke-DbaQuery -SqlInstance $azuresqldb -Query "SELECT TOP 3 * FROM [Items]"

Invoke-Sqlcmd -ServerInstance $sqldbserver -Database $dbname -AccessToken $token -Query "TRUNCATE TABLE [Items]"
Invoke-DbaQuery -SqlInstance $azuresqldb -Query "SELECT Count(*) FROM [Items]"
$items | Write-DbaDbTableData -SqlInstance $azuresqldb -Table Items -Schema dbo -Truncate
Invoke-DbaQuery -SqlInstance $azuresqldb -Query "SELECT Count(*) FROM [Items]"

Invoke-Sqlcmd -ServerInstance $sqldbserver -Database $dbname -AccessToken $token -Query "DROP TABLE [Items]"
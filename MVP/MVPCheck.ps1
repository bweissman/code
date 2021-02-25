# Install-module -Name MVP -Scope CurrentUser -Repository PSGallery
# More Details on the module and how to get a subscription key: https://github.com/lazywinadmin/MVP
Import-Module MVP
$SubscriptionKey = ''
$StartDate = "2020-04-01"
$MVPName="Weissman"
Set-MVPConfiguration -SubscriptionKey $SubscriptionKey
$Contributions=Get-MVPContribution -Limit 1000 | Select StartDate,Title,ReferenceUrl,Description | Where  {$_.ReferenceUrl -like "http*"} | where {$_.StartDate -gt $StartDate } 
foreach ($cont in $Contributions) {
$ContainsName = 0
try   { 
        $res=curl($cont.ReferenceUrl) 
        $cont.Description = "Name missing"
        if ($cont.ReferenceUrl -like "*.sessionize.com*") { $cont.Description = "Name missing (Sessionize)" }
        if ($cont.ReferenceUrl -like "*.pdf") { $cont.Description = "Name missing (PDF)" }
        if ($res -like "*Looking for PASS or SQLSaturday?*") { $cont.Description = "URL Invalid" }
        if ($res -like "*$MVPName*") { $cont.Description = "OK" }}
catch { 
        $res="" 
        $cont.Description = "URL Invalid" 
        }
}
$Contributions | Where {$_.Description -ne "OK"} | Sort-Object Description, StartDate | Format-Table StartDate,Title,ReferenceUrl,Description 
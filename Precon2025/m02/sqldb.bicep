@description('SQL Server name')
param sqlServerName string = 'BWPreconSQLDBSRV-Bicep'

@description('SQL Database name')
param sqlDbName string = 'PreconDB'

@description('SQL DB SKU (service objective)')
@allowed([
  'Basic'
  'S0'
  'S1'
])
param sqlDbSize string = 'S0'

@description('Entra ID admin UPN')
param externalAdminName string

@description('Entra ID admin Object ID')
param externalAdminSid string

var sku = {
  Basic: {
    name: 'Basic'
    tier: 'Basic'
    family: ''
    capacity: 5
  }
  S0: {
    name: 'Standard'
    tier: 'Standard'
    family: ''
    capacity: 10
  }
  S1: {
    name: 'Standard'
    tier: 'Standard'
    family: ''
    capacity: 20
  }
}
var selectedSku = sku[sqlDbSize]

resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = {
  name: toLower(sqlServerName)
  location: resourceGroup().location
  properties: {
    version: '12.0'
    publicNetworkAccess: 'Enabled'
    minimalTlsVersion: '1.2'
    administrators: {
      administratorType: 'ActiveDirectory'
      login: externalAdminName
      sid: externalAdminSid
      azureADOnlyAuthentication: true
    }
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01' = {
  name: sqlDbName
  location: resourceGroup().location
  parent: sqlServer
  properties: {
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    isLedgerOn: false
    licenseType: 'LicenseIncluded'
    requestedBackupStorageRedundancy: 'Geo'
    zoneRedundant: false
  }
  sku: selectedSku
}


param containerAppsEnvName string
param containerRegistryName string
param location string
param logAnalyticsWorkspaceName string
param applicationInsightsName string = ''
param storageAccountName string
param blobContainerName string
param managedIdentity object
param daprEnabled bool = false

// Container apps host (including container registry)
module containerApps '../core/host/container-apps.bicep' = {
  name: 'container-apps'
  params: {
    name: 'apps'
    containerAppsEnvironmentName: containerAppsEnvName
    containerRegistryName: containerRegistryName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    applicationInsightsName: applicationInsightsName
    daprEnabled: daprEnabled
  }
}

// Get cApps Env resource instance to parent Dapr component config under it
resource caEnvironment 'Microsoft.App/managedEnvironments@2022-06-01-preview' existing = {
  name: containerAppsEnvName
}

// Dapr state store component 
resource daprComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-03-01' = {
  name: 'statestore'
  parent: caEnvironment
  properties: {
    componentType: 'state.azure.blobstorage'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '5s'
    metadata: [
      {
        name: 'accountName'
        value: storageAccountName
      }
      {
        name: 'containerName'
        value: blobContainerName
      }
      {
        name: 'azureClientId'
        value: managedIdentity.properties.clientId
      }
    ]
    scopes: [
      'backendapp'
    ]
  }
}

output environmentName string = containerApps.outputs.environmentName
output environmentId string = containerApps.outputs.environmentId
output registryLoginServer string = containerApps.outputs.registryLoginServer
output registryName string = containerApps.outputs.registryName

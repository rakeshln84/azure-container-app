@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param logAnalyticsName string = ''

param storageAccountName string = 'containerappdemo'
param blobContainerName string = 'counter'
param managedIdentityName string = 'containerapp-identity'

param containerAppsEnvironmentName string = ''
param containerRegistryName string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

// Storage Account to act as state store 
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  parent: blobService
  name: blobContainerName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: managedIdentityName
  location: location
}

// Shared App Env with Dapr configuration for db
module appEnv './app/app-env.bicep' = {
  name: 'app-env'
  params: {
    containerAppsEnvName: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}'
    containerRegistryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    managedIdentity: managedIdentity
    storageAccountName: storageAccountName
    blobContainerName: blobContainerName
    daprEnabled: true
  }
}

@description('This is the built-in Storage Blob Data Contributor role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor')
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: storageAccount
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, contributorRoleDefinition.id)
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

module backendapp 'core/host/container-app-upsert.bicep' = {
  name: 'backendapp-container-app-module'
  params: {
    name: 'backendapp'
    location: location
    tags: union(tags, { 'azd-service-name': 'backendapp' })
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    imageName: 'myregistry081020.azurecr.io/containerappdemo-backend-app:v1'
    // containerCpuCoreCount: '0.25'
    targetPort: 80
    // containerMemory: '0.5Gi'
    daprEnabled: true
    containerName: 'backendapp'
    daprAppId: 'backendapp'
    ingressEnabled: true
    identityType: 'UserAssigned'
    identityName: managedIdentityName
    // exists: exists
  }
}

module frontendapp 'core/host/container-app-upsert.bicep' = {
  name: 'frontendapp-container-app-module'
  params: {
    name: 'frontendapp'
    location: location
    tags: union(tags, { 'azd-service-name': 'frontendapp' })
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    imageName: 'myregistry081020.azurecr.io/containerappdemo-frontend-app:v1'
    // containerCpuCoreCount: '0.25'
    targetPort: 80
    // containerMemory: '0.5Gi'
    daprEnabled: true
    containerName: 'frontendapp'
    daprAppId: 'frontendapp'
    ingressEnabled: true
    identityType: 'UserAssigned'
    identityName: managedIdentityName
    // exists: exists
  }
}

// resource backendapp 'Microsoft.App/containerApps@2022-03-01' = {
//   name: 'backendapp'
//   location: location
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${managedIdentity.id}': {}
//     }
//   }
//   properties: {
//     managedEnvironmentId: appEnv.outputs.environmentId
//     configuration: {
//       ingress: {
//         external: false
//         targetPort: 80
//       }
//       dapr: {
//         enabled: true
//         appId: 'backendapp'
//         appProtocol: 'http'
//         appPort: 80
//       }
//     }
//     template: {
//       containers: [
//         {
//           image: 'myregistry081020.azurecr.io/containerappdemo-backend-app:v1'
//           name: 'containerappdemo-backend-app'
//           env: [
//             {
//               name: 'APP_PORT'
//               value: '80'
//             }
//           ]
//           resources: {
//             cpu: json('0.5')
//             memory: '1.0Gi'
//           }
//         }
//       ]
//       scale: {
//         minReplicas: 1
//         maxReplicas: 1
//       }
//     }
//   }
// }

// resource frontendapp 'Microsoft.App/containerApps@2022-03-01' = {
//   name: 'frontendapp'
//   location: location
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${managedIdentity.id}': {}
//     }
//   }
//   properties: {
//     managedEnvironmentId: appEnv.outputs.environmentId
//     configuration: {
//       ingress: {
//         external: false
//         targetPort: 80
//       }
//       dapr: {
//         enabled: true
//         appId: 'frontendapp'
//         appProtocol: 'http'
//         appPort: 80
//       }
//     }
//     template: {
//       containers: [
//         {
//           image: 'myregistry081020.azurecr.io/containerappdemo-frontend-app:v1'
//           name: 'containerappdemo-frontend-app'
//           env: [
//             {
//               name: 'APP_PORT'
//               value: '80'
//             }
//           ]
//           resources: {
//             cpu: json('0.5')
//             memory: '1.0Gi'
//           }
//         }
//       ]
//       scale: {
//         minReplicas: 1
//         maxReplicas: 1
//       }
//     }
//   }
// }

output APPINSIGHTS_INSTRUMENTATIONKEY string = monitoring.outputs.applicationInsightsInstrumentationKey
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.applicationInsightsName
output AZURE_CONTAINER_ENVIRONMENT_NAME string = appEnv.outputs.environmentName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = appEnv.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = appEnv.outputs.registryName

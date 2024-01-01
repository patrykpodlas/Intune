Import-Module -Name IntuneBackup

$VerbosePreference = 'Continue'
$ErrorActionPreference = "Stop"

Write-Verbose "--- Connecting to Microsoft Graph"
Connect-MgGraph -Identity

$deviceCompliancePolicesDataArray = Get-DeviceCompliancePolicies
$deviceConfigurationDataArray = Get-DeviceConfigurations
$configurationPoliciesDataArray = Get-ConfigurationPolicies
$devicePowerShellScriptsDataArray = Get-DevicePowerShellScripts
$deviceShellScriptsDataArray = Get-DeviceShellScripts
$endpointSecurityTemplatesDataArray = Get-EndpointSecurityTemplates
$roleDefinitionsDataArray = Get-RoleDefinitions

$IDs = ($roleDefinitionsDataArray | ForEach-Object { $_.Content | ConvertFrom-Json | Select-Object -ExpandProperty ID })
$roleAssignmentsDataArray = Get-RoleAssignments -IDs $IDs

$IDs = $roleAssignmentsDataArray | ForEach-Object { $_.Content | ConvertFrom-Json | Select-Object -ExpandProperty roleAssignments | Select-Object -ExpandProperty ID }
$roleScopeTagsDataArray = Get-RoleScopeTags -IDs $IDs

$managedAppConfigurationPoliciesDataArray = Get-ManagedAppConfigurationPolicies
$managedDeviceConfigurationPoliciesDataArray = Get-ManagedDeviceConfigurationPolicies
$managedAppProtectionPoliciesDataArray = Get-ManagedAppProtectionPolicies
$appleVPPTokensDataArray = Get-AppleVPPTokens
$depOnboardingSettingsDataArray = Get-DEPOnboardingSettings

$combinedFileDataArray = $deviceCompliancePolicesDataArray + `
    $deviceConfigurationDataArray + `
    $configurationPoliciesDataArray + `
    $devicePowerShellScriptsDataArray + `
    $deviceShellScriptsDataArray + `
    $endpointSecurityTemplatesDataArray + `
    $roleDefinitionsDataArray + `
    $roleAssignmentsDataArray + `
    $roleScopeTagsDataArray + `
    $managedAppConfigurationPoliciesDataArray + `
    $managedDeviceConfigurationPoliciesDataArray + `
    $managedAppProtectionPoliciesDataArray + `
    $appleVPPTokensDataArray + `
    $depOnboardingSettingsDataArray

Import-Module -Name Az.Accounts -RequiredVersion 2.12.1
$bearerToken = Get-AzureDevOpsAccessToken -AsManagedIdentity
$latestCommitId = Get-AzureDevOpsRepoLatestCommit -BearerToken $bearerToken -RepositoryId "<repositoryID>"
$fileList = Get-AzureDevOpsRepoFiles -List -BearerToken $bearerToken -Org "<org>" -Project "<project>" -RepositoryId "<repositoryID>"

$fileHashTable = @{}
foreach ($file in $fileList.Value) {
    $fileHashTable[$file.path] = $true
}

$changesArray = @()
foreach ($FileData in $CombinedFileDataArray) {

    $folderPath = switch -Wildcard ($FileData.ExportPath) {
        # Device configurations
        '*deviceManagement\deviceCompliancePolicies*' { "/deviceManagement/deviceCompliancePolicies/" }
        '*deviceManagement\deviceConfigurations*' { "/deviceManagement/deviceConfigurations/" }
        '*deviceManagement\configurationPolicies*' { "/deviceManagement/configurationPolicies/" }
        '*deviceManagement\depOnboardingSettings*' { "/deviceManagement/depOnboardingSettings/" }
        # Device scripts
        '*deviceManagement\devicePowerShellScripts*' { "/deviceManagement/devicePowerShellScripts/" }
        '*deviceManagement\deviceShellScripts*' { "/deviceManagement/deviceShellScripts/" }
        # Security
        '*deviceManagement\endpointSecurity\templates*' { "/deviceManagement/endpointSecurity/templates/" }
        # RBAC
        '*deviceManagement\rbac\roleDefinitions*' { "/deviceManagement/rbac/roleDefinitions/" }
        '*deviceManagement\rbac\roleAssignments*' { "/deviceManagement/rbac/roleAssignments/" }
        '*deviceManagement\rbac\roleScopeTags*' { "/deviceManagement/rbac/roleScopeTags/" }
        # Applications
        '*deviceAppManagement\targetedManagedAppConfigurations*' { "/deviceAppManagement/targetedManagedAppConfigurations/" }
        '*deviceAppManagement\mobileAppConfigurations*' { "/deviceAppManagement/mobileAppConfigurations/" }
        '*deviceAppManagement\managedAppPolicies*' { "/deviceAppManagement/managedAppPolicies/" }
        '*deviceAppManagement\appleVPPTokens*' { "/deviceAppManagement/appleVPPTokens/" }

        Default { "/unknown/" }
    }

    $filePath = "$folderPath$($FileData.FileName)"

    $fileExists = $fileHashTable.ContainsKey($filePath)

    $changesArray += @{
        changeType = if ($fileExists) { "edit" } else { "add" }
        item       = @{
            path = $filePath
        }
        newContent = @{
            content     = $FileData.Content
            contentType = "rawtext"
        }
    }
}

$body = @{
    refUpdates = @(
        @{
            name        = "refs/heads/main"
            oldObjectId = "$($latestCommitId)"
        }
    )
    commits    = @(
        @{
            comment = "Backing up Intune configurations"
            changes = $ChangesArray
        }
    )
} | ConvertTo-Json -Depth 99

$headers = @{
    'Content-Type'  = 'application/json'
    'Authorization' = 'Bearer ' + $bearerToken
}

Write-Verbose "--- Pushing commit"
$URI = "https://dev.azure.com/<org>/<project>/_apis/git/repositories/<repositoryID>/pushes?api-version=7.1"
Invoke-RestMethod -Uri $URI -Headers $headers -Method POST -Body $body
<#
.SYNOPSIS
Gets a report of what's applying to the device specified.

.DESCRIPTION
Long description

.PARAMETER DeviceID
Intune MDM device ID

.PARAMETER Configuration
Get the configuration profiles applied to the device.

.PARAMETER Compliance
Get the compliance policies applied to the device.

.PARAMETER SecurityIntents
Get the endpoint security configurations applied to the device.

.EXAMPLE
Get-IntuneDeviceReport -analyseConflicts -SecurityIntents -Configuration -Compliance -DeviceID "<deviceId" | Format-Table

--- Global conflict report:

--- Conflict ID: <id>
  --- Conflicting setting: Windows10GeneralConfiguration.DefenderScanArchiveFiles
      --- From configuration(s):
          --- NA Security Baseline | ID: <id>

--- Conflict ID: <id>_<id>
  --- Conflicting setting: Windows10CustomConfiguration
      --- From configuration(s):
          --- NA Set Timezone | ID: <id>
          --- EU Set Timezone | ID: <id>


--- Report for device: <deviceId>

displayName                                     state     platformType      id                                   type                 conflictingSetting
-----------                                     -----     ------------      --                                   ----                 ------------------
EU Disable Internet Explorer                    compliant windows10AndLater xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx configurationProfile
EU Compliance Policy                            compliant windows10AndLater xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx compliancePolicy
EU Antivirus Policy                             unknown                     xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx securityIntent
EU Account Protection                           compliant                   xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx securityIntent

.NOTES
Requires Get-MgGraphAllPages custom function to work with Security Intents.
#>

function Get-MgGraphAllPages {
    [CmdletBinding(
        ConfirmImpact = 'Medium',
        DefaultParameterSetName = 'SearchResult'
    )]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'NextLink', ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('@odata.nextLink')]
        [string]$NextLink
        ,
        [Parameter(Mandatory = $true, ParameterSetName = 'SearchResult', ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSObject]$SearchResult
        ,
        [Parameter(Mandatory = $false)]
        [switch]$ToPSCustomObject
    )

    begin {}

    process {
        if ($PSCmdlet.ParameterSetName -eq 'SearchResult') {
            # Set the current page to the search result provided
            $page = $SearchResult

            # Extract the NextLink
            $currentNextLink = $page.'@odata.nextLink'

            # We know this is a wrapper object if it has an "@odata.context" property
            #if (Get-Member -InputObject $page -Name '@odata.context' -Membertype Properties) {
            # MgGraph update - MgGraph returns hashtables, and almost always includes .context
            # instead, let's check for nextlinks specifically as a hashtable key
            if ($page.ContainsKey('@odata.count')) {
                Write-Verbose "First page value count: $($Page.'@odata.count')"
            }

            if ($page.ContainsKey('@odata.nextLink') -or $page.ContainsKey('value')) {
                $values = $page.value
            } else {
                # this will probably never fire anymore, but maybe.
                $values = $page
            }

            # Output the values
            # Default returned objects are hashtables, so this makes for easy pscustomobject conversion on demand
            if ($values) {
                if ($ToPSCustomObject) {
                    $values | ForEach-Object { [pscustomobject]$_ }
                } else {
                    $values | Write-Output
                }
            }
        }

        while (-Not ([string]::IsNullOrWhiteSpace($currentNextLink))) {
            # Make the call to get the next page
            try {
                $page = Invoke-MgGraphRequest -Uri $currentNextLink -Method GET
            } catch {
                throw $_
            }

            # Extract the NextLink
            $currentNextLink = $page.'@odata.nextLink'

            # Output the items in the page
            $values = $page.value

            if ($page.ContainsKey('@odata.count')) {
                Write-Verbose "Current page value count: $($Page.'@odata.count')"
            }

            # Default returned objects are hashtables, so this makes for easy pscustomobject conversion on demand
            if ($ToPSCustomObject) {
                $values | ForEach-Object { [pscustomobject]$_ }
            } else {
                $values | Write-Output
            }
        }
    }

    end {}
}

# This is the new API as outlined in: https://techcommunity.microsoft.com/t5/intune-customer-success/endpoint-security-policies-migrating-to-the-unified-settings/ba-p/3890989
# https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceconfigv2-devicemanagementconfigurationpolicy?view=graph-rest-beta

Function Get-DeviceConfigurationPolicies {
    [CmdletBinding()]
    param (
        $URI = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies",
        $ExportPath = "$env:TEMP\deviceManagement\deviceConfigurationPolicies"
    )

    $exportPath = $exportPath.replace('"', '')

    try {
        # Get
        $request = (Invoke-MgGraphRequest -Uri $URI -Method GET | Get-MgGraphAllPages)

        # Get assignments
        foreach ($item in $request) {
            $assignmentsUri = "$URI('$($item.id)')/assignments"
            $itemAssignments = (Invoke-MgGraphRequest -Uri $assignmentsUri -Method GET)
            $item.assignments = $itemAssignments
        }

        # Sort
        $sortedRequest = foreach ($item in $request) {
            Format-HashtableRecursively -Hashtable $item
        }

        # Initialize the array to hold data for export
        $dataArray = @()

        # Process
        foreach ($item in $sortedRequest) {
            Write-Verbose "Item: $($item.name)"
            $jsonContent = $item | ConvertTo-Json -Depth 99
            $fileName = $item.name -replace '[\<\>\:"/\\\|\?\*]', "_"

            $fileData = @{
                FileName   = "$fileName.json"
                Content    = $jsonContent
                ExportPath = $exportPath
            }
            # Add the object to the array
            $dataArray += $fileData
        }

        return $dataArray

    } catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
        return
    }
}

# The below script retrieves the group names and IDs for the assignments inside another policy (Get-DeviceConfigurationPolicies, Get-DeviceCompliancePolicies, Get-EndpointSecurityIntents), this then creates a table showing the policy and it's assignments including the ID and displayName
# Error action preference is mandatory because the -ErrorAction does not work (haven't troubleshooted yet)
# Simply pass the entire output of the cmdlet that supports retrieval of assignments to this one
# Example:
# 1. $securityIntents = Get-EndpointSecurityIntents
# 2. Get-PolicyGroupAssignments -Policies $securityIntents

$ErrorActionPreference = 'Stop'
function Get-PolicyGroupAssignments {
    param (
        $Policies
    )
    $table = @()
    foreach ($item in $Policies) {
        # include check to make sure that if the policy doesn't have an assignment, then skip it
        $policyName = ($item.FileName).trim(".json")
        $policyID = ($item.Content | ConvertFrom-Json | Select-Object -ExpandProperty Id)
        # Try-catch block necessary because of Get-MgGraphAllPages set on some of the API calls where it adds "Value" which isn't present for API calls that don't need it.
        try {
            $groups = $item.content | ConvertFrom-Json | Select-Object -ExpandProperty assignments | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty target | Select-Object -Property "@odata.type", groupId
        } catch {
            $groups = $item.content | ConvertFrom-Json | Select-Object -ExpandProperty assignments | Select-Object -ExpandProperty target | Select-Object -Property "@odata.type", groupId
        }

        if ($groups) {
            $groupsObject = @()
            foreach ($item in $groups) {
                $groupID = $($item.groupID)
                $groupTargetType = $($item."@odata.type")
                $groupDisplayName = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$groupID" -Method GET).displayName

                $object = [PSCustomObject]@{
                    groupID          = $groupID
                    groupDisplayName = $groupDisplayName
                    groupTargetType  = $groupTargetType
                }

                $groupsObject += $object
            }

            $object = [PSCustomObject]@{
                policyName = $policyName
                policyID   = $policyID
                groups     = $groupsObject
            }

            $table += $object
        }
    }

    return $table

}

function Get-IntuneDeviceReport {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = "Default", Mandatory)]
        [string]$DeviceID,
        [Parameter(ParameterSetName = "Default")]
        [switch]$Configuration,
        [Parameter(ParameterSetName = "Default")]
        [switch]$Compliance,
        [Parameter(ParameterSetName = "Default")]
        [switch]$SecurityIntents,
        [Parameter(ParameterSetName = "Default")]
        [switch]$NewPolicies,
        [Parameter(ParameterSetName = "Default")]
        [switch]$analyseConflicts
    )

    $results = @()

    if ($Configuration) {
        # Get device configuration state
        # For whatever reason, this API return ALL the devices that belong to the user, not just the device targeted, but you can filter through when running the command function.
        # https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-deviceconfigurationsettingstate?view=graph-rest-beta
        $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/deviceConfigurationStates" -Method GET | Select-Object -ExpandProperty Value
        $objects = foreach ($item in $response | Where-Object { $_.userPrincipalName -ne "System account" -and $_.userPrincipalName -notlike "*autopilot*" }) {
            # Convert each hashtable entry into a PSCustomObject
            [PSCustomObject]$item
        }

        $objects | Add-Member -NotePropertyName "type" -NotePropertyValue "configurationProfile" -Force

        $results += $objects | Select-Object displayName, state, platformType, id, type

    }


    if ($Compliance) {
        # Get device compliance policy state
        # For whatever reason, this API return ALL the devices that belong to the user, not just the device targeted, but you can filter through when running the command function.
        # https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-devicecompliancepolicysettingstate?view=graph-rest-beta
        $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/deviceCompliancePolicyStates" -Method GET | Select-Object -ExpandProperty Value
        $objects = foreach ($item in $response | Where-Object { $_.userPrincipalName -ne "System account" -and $_.userPrincipalName -notlike "*autopilot*" }) {
            # Convert each hashtable entry into a PSCustomObject
            [PSCustomObject]$item
        }

        $objects | Add-Member -NotePropertyName "type" -NotePropertyValue "compliancePolicy" -Force

        $results += $objects | Select-Object displayName, state, platformType, id, type

    }

    if ($NewPolicies) {
        #$newPolicies[34].content
        $policies = Get-DeviceConfigurationPolicies
        $policyGroupAssignments = Get-PolicyGroupAssignments -Policies $policies
        # Show what groups the device is a member of
        $intuneDeviceGroupMemberships = Get-IntuneDeviceGroupMemberships -DeviceID $DeviceID
        $deviceGroupIDs = $intuneDeviceGroupMemberships.id
        foreach ($item in $policyGroupAssignments) {

            $policyname = $item.policyName
            $groups = $item.groups
            $policyID = $item.policyID

            foreach ($item in $groups) {
                $matchFound = $deviceGroupIDs | Where-Object { $item.groupID -like "$_" }
                if ($matchFound) {
                    $groupTargetType = $item.groupTargetType
                    if ($groupTargetType -eq "#microsoft.graph.groupAssignmentTarget") {
                        $groupTargetType = "assigned"
                    } elseif ($groupTargetType -eq "#microsoft.graph.exclusionGroupAssignmentTarget") {
                        $groupTargetType = "excluded"
                    }
                    $object = [PSCustomObject]@{
                        displayName        = $policyname
                        state              = "uknown"
                        platformType       = "unknown"
                        id                 = $policyID
                        type               = "newAPI"
                        conflictingSetting = ""
                        groupTargetType    = $groupTargetType
                    }
                    $results += $object
                }
            }
        }
    }

    if ($SecurityIntents) {
        $intents = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/intents?`$select=id,displayName" | Select-Object -ExpandProperty Value

        $allResponses = @()
        foreach ($item in $intents) {
            $intentDisplayName = $item.displayName
            $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/intents/$($item.id)/deviceStates?`$filter=deviceId eq '$deviceID'" -Method GET | Get-MgGraphAllPages

            <#
            # The reponse properties are
            deviceDisplayName
            userPrincipalName
            state
            id - this only refers to the "ID" in the documentation, so no idea what the entire string represents, but the [1] seems to represent the actual intentId#
            userName
            lastReportedDateTime
            deviceId
            #>

            # Add the intentDisplayName to each response item
            foreach ($item in $response) {
                $item | Add-Member -NotePropertyName "intentDisplayName" -NotePropertyValue $intentDisplayName -Force
                $item | Add-Member -NotePropertyName "type" -NotePropertyValue "securityIntent" -Force
            }

            $allResponses += $($response | Where-Object { $_.userPrincipalName -ne "System account" -and $_.userPrincipalName -notlike "*autopilot*" } )
        }

        # Get device intents state
        $objects = foreach ($item in $allResponses) {
            # Convert each hashtable entry into a PSCustomObject
            [PSCustomObject]@{
                displayName = $item.intentDisplayName
                id          = $item.id.split("_")[1]
                type        = $item.type
                state       = $item.state
            }
        }

        $results += $objects | Select-Object displayName, state, platformType, id, type
    }

    if ($analyseConflicts) {
        function Get-IntuneConflicts {
            [CmdletBinding()]
            param (

            )
            $conflicts = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurationConflictSummary" -Method GET).Value

            $configurationProfiles = @()
            $compliancePolicies = @()
            $securityIntents = @()

            $conflicts | ForEach-Object {
                Write-Host "--- Conflict ID: $($_.id)" -ForegroundColor Yellow
                Write-Host "  --- Conflicting setting: " -ForegroundColor Yellow -NoNewline ; Write-Host "$($_.contributingSettings)" -ForegroundColor Red
                Write-Host "      --- From configuration(s): " -ForegroundColor Yellow
                if ($_.contributingSettings -like "*Windows10CustomConfiguration*") {
                    foreach ($item in $($_.conflictingDeviceConfigurations)) {
                        $displayName = $($item.displayName)
                        $id = $item.id
                        Write-Host "          --- $displayName | ID: $id"
                        $object = [PSCustomObject]@{
                            displayName        = $displayName
                            id                 = $id
                            type               = "configurationProfile"
                            conflictingSetting = $($_.contributingSettings)
                        }
                        $configurationProfiles += $object
                    }
                } elseif ($_.contributingSettings -like "*Windows10EndpointProtectionConfiguration*" -or $_.contributingSettings -like "*Windows10GeneralConfiguration*") {
                    foreach ($item in $($_.conflictingDeviceConfigurations)) {
                        $displayName = $item.displayName.Substring(0, $($item.displayName.LastIndexOf(" - "))).Trim()
                        $id = $item.displayName.Substring($($item.displayName.LastIndexOf(" - "))).split("_")[0].TrimStart("-  ")
                        Write-Host "          --- $displayName | ID: $id"
                        $object = [PSCustomObject]@{
                            displayName        = $displayName
                            id                 = $id
                            type               = "securityIntent"
                            conflictingSetting = $($_.contributingSettings)
                        }
                        $securityIntents += $object
                    }
                } else {
                    foreach ($item in $($_.conflictingDeviceConfigurations)) {
                        $displayName = $($item.displayName)
                        $id = $item.id
                        Write-Host "          --- $displayName | ID: $id"
                        $object = [PSCustomObject]@{
                            displayName        = $displayName
                            id                 = $id
                            type               = "unknown"
                            conflictingSetting = $($_.contributingSettings)
                        }
                        $compliancePolicies += $object
                    }
                }
                Write-Host ""
            }

            $everything = $configurationProfiles + $compliancePolicies + $securityIntents
            return $everything

        }

        Write-Host ""
        Write-Host "--- Global conflict report:" -ForegroundColor Yellow
        Write-Host ""
        $conflicts = Get-IntuneConflicts

        # Compare results to the conflicts to highlight what's important for the device targeted
        foreach ($item in $results | Where-Object state -eq "conflict") {
            $conflictId = $($($conflicts | Where-Object { $_.id -eq $item.id }).id)
            $conflictSetting = $conflicts | Where-Object { $_.id -eq $conflictId } | Select-Object -ExpandProperty conflictingSetting
            Write-Host ""
            Write-Host "Found conflict: $($item.displayName) with ID: $conflictId for $conflictSetting"
            Write-Host ""
            $item | Add-Member -NotePropertyName "conflictingSetting" -NotePropertyValue $conflictSetting -Force
        }

    }

    Write-Host ""
    Write-Host "--- Report for device: $deviceId" -ForegroundColor Yellow
    return $results | Select-Object displayName, state, platformType, id, type, conflictingSetting, groupTargetType

}

function Get-IntuneDeviceGroupMemberships {
    param (
        $DeviceID
    )
    # This is the Intune Device ID, but we can't use it because we need the Object ID of the device, which we can't get because none of the Intune API's get the ID.
    # Get the device displayName from the Intune Device ID
    $deviceName = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($deviceId)?`$select=deviceName" | Select-Object -ExpandProperty deviceName
    # Get the Intune ObjectID from the device displayName
    $azureADdeviceID = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$($deviceName)'" | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty Id
    # Requires ObjectID (this is the Azure AD ID)
    $request = Invoke-MgGraphRequest -URI "https://graph.microsoft.com/v1.0/devices/$azureADdeviceID/memberOf" | Select-Object -ExpandProperty Value | Select-Object id, displayName
    # The reutned request contains all the groups the device is a member of.
    return $request
}
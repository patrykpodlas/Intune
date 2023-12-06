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

function Get-IntuneDeviceReport {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName="Default", Mandatory)]
        [string]$DeviceID,
        [Parameter(ParameterSetName="Default")]
        [switch]$Configuration,
        [Parameter(ParameterSetName="Default")]
        [switch]$Compliance,
        [Parameter(ParameterSetName="Default")]
        [switch]$SecurityIntents,
        [Parameter(ParameterSetName="Default")]
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
    return $results | Select-Object displayName, state, platformType, id, type, conflictingSetting

}

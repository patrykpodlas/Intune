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
Get-IntuneDeviceReport -SecurityIntents -Configuration -Compliance -DeviceID 0fb6bcde-b0d9-4d4a-8bff-d8416e43a46a

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
        [string]$DeviceID,
        [switch]$Configuration,
        [switch]$Compliance,
        [switch]$SecurityIntents
    )

    if ($Configuration) {
        # Get device configuration state
        $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/deviceConfigurationStates" -Method GET | Select-Object -ExpandProperty Value
        $objects = foreach ($item in $response) {
            # Convert each hashtable entry into a PSCustomObject
            [PSCustomObject]$item
        }

        $objects | Select-Object displayName, id, platformType, state, version, settingCount, userPrincipalName, userId | Sort-Object -Property platformType | Format-Table

    }


    if ($Compliance) {
        # Get device compliance policy state
        $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/deviceCompliancePolicyStates" -Method GET | Select-Object -ExpandProperty Value
        $objects = foreach ($item in $response) {
            # Convert each hashtable entry into a PSCustomObject
            [PSCustomObject]$item
        }

        $objects | Select-Object displayName, id, platformType, state, version, settingCount, userPrincipalName, userId | Sort-Object -Property platformType | Format-Table

    }

    if ($SecurityIntents) {
        $intents = (Get-EndpointSecurityIntents).Content | ConvertFrom-Json | Select-Object displayName, id

        $allResponses = @()
        foreach ($item in $intents) {
            $intentDisplayName = $item.displayName
            $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/intents/$($item.id)/deviceStates?`$filter=deviceId eq '$deviceID'" -Method GET | Get-MgGraphAllPages

            # Add the intentDisplayName to each response item
            foreach ($respItem in $response) {
                $respItem | Add-Member -NotePropertyName "intentDisplayName" -NotePropertyValue $intentDisplayName -Force
            }

            $allResponses += $response
        }

        # Get device intents state
        $objects = foreach ($item in $allResponses) {
            # Convert each hashtable entry into a PSCustomObject
            [PSCustomObject]@{
                IntentName  = $item.intentDisplayName
                IntentId    = $item.id.split("_")[1]
                DeviceState = $item.state
                # Add other relevant properties here
            }
        }

        $objects | Sort-Object -Property platformType | Format-Table

    }
}
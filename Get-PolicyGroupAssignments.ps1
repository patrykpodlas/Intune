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
            $groupIDs = $item.content | ConvertFrom-Json | Select-Object -ExpandProperty assignments | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty target | Select-Object -ExpandProperty groupId
        } catch {
            $groupIDs = $item.content | ConvertFrom-Json | Select-Object -ExpandProperty assignments | Select-Object -ExpandProperty target | Select-Object -ExpandProperty groupId
        }

        if ($groupIDs) {
            $groups = @()
            foreach ($item in $groupIDs) {
                $groupID = $item
                $groupDisplayName = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$item" -Method GET | Select-Object -ExpandProperty displayName

                $object = [PSCustomObject]@{
                    groupID          = $groupID
                    groupDisplayName = $groupDisplayName
                }

                $groups += $object
            }

            $object = [PSCustomObject]@{
                policyName = $policyName
                policyID   = $policyID
                groups     = $groups
            }

            $table += $object
        }
    }

    return $table

}
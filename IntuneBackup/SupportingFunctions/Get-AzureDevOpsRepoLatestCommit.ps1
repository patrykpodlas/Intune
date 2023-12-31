<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Detailed description
.PARAMETER <name>
    Parameter explanation
.EXAMPLE
    PS C:\> $latestCommitId = Get-AzureDevOpsRepoLatestCommit -BearerToken $bearerToken -RepositoryId "<RepositoryId>"
    Get the latest commit ID from a Git repository (AzureDevOps in this case), uses a bearer token captured using Get-AzureDevOpsAccessToken.

    Change the ORG and PROJECT to your own
.NOTES
    Author: Patryk Podlas
    Created: 31/12/2023
#>

function Get-AzureDevOpsRepoLatestCommit {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'PAT')]
        [string]$PAT,

        [Parameter(Mandatory, ParameterSetName = 'BearerToken')]
        [string]$BearerToken,

        [Parameter(Mandatory)]
        [string]$RepositoryId
    )

    if ($PAT) {
        $headers = @{
            'Content-Type'  = 'application/json'
            'Authorization' = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":${PAT}"))
        }
    } elseif ($BearerToken) {
        $headers = @{
            'Content-Type'  = 'application/json'
            'Authorization' = 'Bearer ' + $bearerToken
        }
    }

    $uri = "https://dev.azure.com/<org>/<project>/_apis/git/repositories/$RepositoryId/refs?filter=heads/main&api-version=7.1"

    $response = Invoke-RetryRestMethod -Uri $uri -Headers $headers -Method 'GET'

    if ($response) {
        # Extract the latest commit ID
        $latestCommitId = $response.value[0].objectId
        # Return the latest commit ID
        Write-Verbose "Latest commit ID: $latestCommitId"
        return $latestCommitId
    } else {
        Write-Verbose "Failed to retrieve the latest commit ID."
    }
}

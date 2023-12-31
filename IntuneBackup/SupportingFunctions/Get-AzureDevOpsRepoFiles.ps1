<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Detailed description
.PARAMETER <name>
    Parameter explanation
.EXAMPLE
    PS C:\> $fileList = Get-AzureDevOpsRepoFiles -List -BearerToken $bearerToken -Org "<Org>" -Project "<Project>" -RepositoryId "<RepositoryID>"
    Gets a list of files present in the Git repository, uses BearerToken captured using Get-AzureDevOpsAccessToken
.NOTES
    Author: Patryk Podlas
    Created: 31/12/2023
#>
function Get-AzureDevOpsRepoFiles {
    [CmdletBinding()]
    param (
        [string]$Org,
        [string]$Project,
        [string]$RepositoryId,
        [string]$FilePath,
        [string]$BearerToken,
        [switch]$List
    )

    $headers = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Bearer ' + [string]$BearerToken
    }

    if ($FilePath) {
        $uri = "https://dev.azure.com/$Org/$Project/_apis/git/repositories/$RepositoryId/items?path=$FilePath&api-version=7.1"
        try {
            Invoke-RetryRestMethod -Uri $uri -Headers $headers -Method 'GET'
            Write-Verbose "File found at path: $FilePath"
            return $true
        } catch {
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 'NotFound') {
                Write-Verbose "File not found: $FilePath"
                return $false
            } else {
                throw $_.Exception
            }
        }
    } elseif ($List) {
        $uri = "https://dev.azure.com/$Org/$Project/_apis/git/repositories/$RepositoryId/items?recursionLevel=Full&api-version=7.1"
        try {
            Invoke-RetryRestMethod -Uri $uri -Headers $headers -Method 'GET'
            Write-Verbose "List of files retrieved successfully."
            return $true
        } catch {
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 'NotFound') {
                Write-Verbose "No files present in the repository."
                return $false
            } else {
                throw $_.Exception
            }
        }
    }
}
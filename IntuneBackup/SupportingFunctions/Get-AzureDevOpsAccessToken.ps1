<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Detailed description
.PARAMETER <name>
    Parameter explanation
.EXAMPLE
    PS C:\> $bearerToken = Get-AzureDevOpsAccessToken -AsManagedIdentity
    Get an Azure DevOps access token as managed identity
.NOTES
    Author: Patryk Podlas
    Created: 31/12/2023

    Requires Az.Accounts -Version 2.12.1
#>

#Requires -Module Az.Accounts -Version 2.12.1

function Get-AzureDevOpsAccessToken {
    [CmdletBinding()]
    param (
        [switch]$AsManagedIdentity,
        [switch]$ConstructHeaders
    )
    try {
        Import-Module Az.Accounts -RequiredVersion 2.12.1 -ErrorAction Stop
    } catch {
        Write-Error "The required version of Az.Accounts is not installed."
        return
    }

    if ($AsManagedIdentity) {
        Connect-AzAccount -Identity | Out-Null
        Write-Verbose "Connected as managed identity."
    } else {
        Connect-AzAccount | Out-Null
        Write-Verbose "Connected as a user."
    }

    Write-Verbose "Getting an access token."
    [string]$bearerToken = (Get-AzAccessToken).Token

    if ($ConstructHeaders) {
        $headers = @{
            'Content-Type'  = 'application/json'
            'Authorization' = 'Bearer ' + $bearerToken
        }
        return $headers
    } else {
        return $bearerToken
    }
}

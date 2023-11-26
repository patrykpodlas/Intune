function Invoke-RetryRestMethod {
    [CmdletBinding()]
    param (
        [string]$Uri,

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [string]$Method = 'GET', # Default to GET

        [string]$Body,

        [int]$RetryCount = 10,

        [int]$RetryInterval = 1  # seconds
    )

    for ($i = 0; $i -lt $RetryCount; $i++) {
        try {
            if ($Body) {
                $response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method $Method -Body $Body
            } else {
                $response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method $Method
            }

            Write-Verbose "API call successful."
            return $response
        } catch {
            if ($_.Exception.Response.StatusCode -eq 'NotFound') {
                Write-Verbose "API call successful, but file was not found."
                return $null
            } else {
                Write-Error "An error occurred: $($_.Exception.Message)"
                Write-Verbose "Attempt $($i + 1) failed. Retrying in $retryInterval seconds..."
                Start-Sleep -Seconds $retryInterval
            }
        }
    }

    Write-Verbose "Failed to complete the request after $retryCount attempts."
    return $null
}
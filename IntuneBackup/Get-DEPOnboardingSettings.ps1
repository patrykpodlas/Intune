Function Get-DEPOnboardingSettings {
    [CmdletBinding()]
    param (
        $URI = "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings",
        $ExportPath = "$env:TEMP\deviceManagement\depOnboardingSettings"
    )

    $exportPath = $exportPath.replace('"', '')

    try {
        # Get
        $request = (Invoke-MgGraphRequest -Uri $URI -Method GET).Value

        # Sort
        $sortedRequest = foreach ($item in $request) {
            Format-HashtableRecursively -Hashtable $item
        }
        # Convert Date and Time to string to prevent serialisation
        foreach ($item in $sortedRequest) {
            $item.lastModifiedDateTime = $item.lastModifiedDateTime.ToString('MM/dd/yyyy HH:mm:ss')
            $item.tokenExpirationDateTime = $item.tokenExpirationDateTime.ToString('MM/dd/yyyy HH:mm:ss')
            # Exclude lastSuccessfulSyncDateTime amd lastSyncTriggeredDateTime
            $item.lastSuccessfulSyncDateTime = $null
            $item.lastSyncTriggeredDateTime = $null
        }

        # Initialize the array
        $dataArray = @()

        # Process
        foreach ($item in $sortedRequest) {
            Write-Verbose "Item: $($item.tokenName)"
            $jsonContent = $item | ConvertTo-Json -Depth 99
            $fileName = $item.tokenName -replace '[\<\>\:"/\\\|\?\*]', "_"

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

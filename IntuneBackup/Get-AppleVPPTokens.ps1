Function Get-AppleVPPTokens {
    [CmdletBinding()]
    param (
        $URI = "https://graph.microsoft.com/beta/deviceAppManagement/vppTokens",
        $ExportPath = "$env:TEMP\deviceAppManagement\deviceEnrollment\appleVPPTokens"
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
            $item.expirationDateTime = $item.expirationDateTime.ToString('MM/dd/yyyy HH:mm:ss')
            $item.lastModifiedDateTime = $item.lastModifiedDateTime.ToString('MM/dd/yyyy HH:mm:ss')
            # Exclude lastSyncDateTime
            $item.lastSyncDateTime = $null
        }

        # Initialize the array
        $dataArray = @()

        # Process
        foreach ($item in $sortedRequest) {
            Write-Verbose "Item: $($item.displayName)"
            $jsonContent = $item | ConvertTo-Json -Depth 99
            $fileName = $item.displayName -replace '[\<\>\:"/\\\|\?\*]', "_"

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

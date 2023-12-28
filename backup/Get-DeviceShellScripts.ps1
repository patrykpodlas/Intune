Function Get-DeviceShellScripts {
    [CmdletBinding()]
    param (
        $URI = "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts?`$expand=assignments",
        $ExportPath = "$env:TEMP\deviceManagement\deviceShellScripts"
    )

    $exportPath = $exportPath.replace('"', '')

    try {
        # Get
        $request = (Invoke-MgGraphRequest -Uri $URI -Method GET).Value

        # Get script content
        foreach ($item in $request) {
            $scriptContentUri = "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts/$($item.id)?`$select=scriptContent"
            $itemScriptContent = (Invoke-MgGraphRequest -Uri $scriptContentUri -Method GET).scriptContent
            #[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("$itemScriptContent")) | Out-File -FilePath ".\$($item.fileName).txt" -Encoding utf8
            $item.scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("$itemScriptContent"))
        }

        # Sort
        $sortedRequest = foreach ($item in $request) {
            Format-HashtableRecursively -Hashtable $item
        }

        # Convert Date and Time to string to prevent serialisation
        foreach ($item in $sortedRequest) {
            $item.createdDateTime = $item.createdDateTime.ToString('MM/dd/yyyy HH:mm:ss')
            $item.lastModifiedDateTime = $item.lastModifiedDateTime.ToString('MM/dd/yyyy HH:mm:ss')
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

    }
    catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
        return
    }
}
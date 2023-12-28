function Format-HashtableRecursively {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Hashtable
    )

    $sortedHashtable = [ordered]@{}

    foreach ($key in $Hashtable.Keys | Sort-Object) {
        $value = $Hashtable[$key]

        if ($value -is [hashtable]) {
            # If the value is a hashtable, sort it recursively
            $sortedHashtable[$key] = Format-HashtableRecursively -Hashtable $value
        } elseif ($value -is [System.Collections.ArrayList] -or $value -is [object[]]) {
            # If the value is an array, sort each hashtable within it recursively
            $sortedArray = @()
            foreach ($item in $value) {
                if ($item -is [hashtable]) {
                    $sortedArray += Format-HashtableRecursively -Hashtable $item
                } else {
                    $sortedArray += $item
                }
            }
            $sortedHashtable[$key] = $sortedArray
        } else {
            # If the value is not a hashtable or array, just add it
            $sortedHashtable[$key] = $value
        }
    }

    return $sortedHashtable
}
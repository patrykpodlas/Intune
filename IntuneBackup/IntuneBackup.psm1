$functions = Get-ChildItem -Path ".\" -Filter '*.ps1' -Recurse

foreach ($item in $functions) {
    try {
        . $item.fullname
    } catch {
        Write-Error "Unable to import function $($item.fullname)"
    }
}
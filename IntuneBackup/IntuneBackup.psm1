$functions = Get-ChildItem -File -Recurse -LiteralPath $PSScriptRoot -Filter *.ps1

foreach ($item in $functions) {
    try {
        . $item.fullname
    } catch {
        Write-Error "Unable to import function $($item.fullname)"
    }
}
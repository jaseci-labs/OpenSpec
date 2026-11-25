glob POWERSHELL_DYNAMIC_HELPERS: str = """# Dynamic completion helpers

function Get-OpenSpecChanges {
    $output = openspec __complete changes 2>$null
    if ($output) {
        $output | ForEach-Object {
            ($_ -split "\\t")[0]
        }
    }
}

function Get-OpenSpecSpecs {
    $output = openspec __complete specs 2>$null
    if ($output) {
        $output | ForEach-Object {
            ($_ -split "\\t")[0]
        }
    }
}

function Get-OpenSpecSchemas {
    $output = openspec __complete schemas 2>$null
    if ($output) {
        $output | ForEach-Object {
            ($_ -split "\\t")[0]
        }
    }
}
""";

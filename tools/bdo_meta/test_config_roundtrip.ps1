# Every config key the launcher seeds must also be written by Save-Config, and must
# appear in the migration list so existing config.json files gain it on upgrade.
#
# Save-Config builds an explicit [pscustomobject], so a key added to the seed but not
# to that object is silently dropped on every save. That is invisible at runtime: the
# value is set, used once, and gone on the next load. lastMetaVersion shipped with
# exactly that bug.
$ErrorActionPreference = 'Stop'
$fails = 0
function Check($name, $cond) {
    if ($cond) { Write-Host "  [PASS] $name" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $name" -ForegroundColor Red; $script:fails++ }
}

Write-Host 'Config round-trip' -ForegroundColor White

$src = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\bdo_aio.ps1') -Raw

function Get-KeysFromBlock([string]$text) {
    $depth = 0; $keys = @(); $started = $false
    foreach ($line in ($text -split "`n")) {
        if (-not $started) { if ($line -match '@\{') { $started = $true; $depth = 1 }; continue }
        $depth += ([regex]::Matches($line, '\{')).Count
        $depth -= ([regex]::Matches($line, '\}')).Count
        if ($depth -le 0) { break }
        if ($line -match '^\s*([A-Za-z][A-Za-z0-9]*)\s*=') { $keys += $Matches[1] }
    }
    return $keys
}

# the seed object created when no config.json exists
$seedStart = $src.IndexOf('if (-not $Script:Config) {')
Check 'found the config seed block' ($seedStart -ge 0)
$seed = Get-KeysFromBlock $src.Substring($seedStart, 4000)

# the object Save-Config actually persists
$saveStart = $src.IndexOf('function Save-Config {')
Check 'found Save-Config' ($saveStart -ge 0)
$saved = Get-KeysFromBlock $src.Substring($saveStart, 4000)

Check "seed has keys ($($seed.Count))" ($seed.Count -gt 10)
Check "Save-Config has keys ($($saved.Count))" ($saved.Count -gt 10)

$dropped = @($seed | Where-Object { $saved -notcontains $_ })
if ($dropped.Count) { Write-Host ("    dropped on save: " + ($dropped -join ', ')) -ForegroundColor Red }
Check 'every seeded key is persisted by Save-Config' ($dropped.Count -eq 0)

# the migration list gives existing config.json files the new key
$migration = ''
if ($src -match "foreach \(\`$p in @\(([^)]*)\)\) \{") { $migration = $Matches[1] }
Check 'found the migration key list' ($migration.Length -gt 50)
$missingMigration = @($seed | Where-Object { $_ -ne 'lastRun' -and $migration -notmatch [regex]::Escape("'$_'") })
if ($missingMigration.Count) { Write-Host ("    not migrated: " + ($missingMigration -join ', ')) -ForegroundColor Red }
Check 'every seeded key is in the migration list' ($missingMigration.Count -eq 0)

# the specific key this suite was written for
Check 'lastMetaVersion is seeded'    ($seed -contains 'lastMetaVersion')
Check 'lastMetaVersion is persisted' ($saved -contains 'lastMetaVersion')

Write-Host ''
if ($fails -gt 0) { Write-Host "$fails CHECK(S) FAILED" -ForegroundColor Red; exit 1 }
Write-Host 'ALL CONFIG ROUND-TRIP TESTS PASSED' -ForegroundColor Green

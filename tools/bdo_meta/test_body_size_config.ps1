$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourcePath = Join-Path $root 'bdo_aio.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $sourcePath,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -ne 0) {
    throw ($parseErrors | ForEach-Object Message | Out-String)
}

foreach ($name in @('Get-BodySizeSpec', 'Format-BodySizeSpec', 'Get-BodySizeArg', 'Update-BodySizeConfig')) {
    $fn = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true) | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if (-not $fn) { throw ($name + ' was not found in bdo_aio.ps1.') }
    Invoke-Expression $fn.Extent.Text
}

# Script-scope constants the functions rely on.
$Script:BodySizeParts = @('breasts', 'thighs', 'butt', 'belly')
$Script:BodySizePresets = [ordered]@{
    'vanilla'     = @{ Label = 'v'; Spec = 'breasts:1.25,thighs:1.15,butt:1.10,belly:1.10' }
    'recommended' = @{ Label = 'r'; Spec = 'breasts:1.37,thighs:1.30,butt:1.18,belly:1.20' }
    'high'        = @{ Label = 'h'; Spec = 'breasts:1.65,thighs:1.40,butt:1.19,belly:1.25' }
    'extreme'     = @{ Label = 'e'; Spec = 'breasts:2.00,thighs:1.45,butt:1.20,belly:1.30' }
}
$Script:BodySizeDefaultSpec = $Script:BodySizePresets['recommended'].Spec

$failures = New-Object System.Collections.Generic.List[string]

# Windows PowerShell 5.1 reads a .ps1 without a BOM as ANSI, so every non-ASCII
# character in the launcher renders as mojibake (an em dash becomes 3 junk
# characters). Any tool that rewrites the file must keep the BOM.
$rawBytes = [System.IO.File]::ReadAllBytes($sourcePath)
$hasBom = $rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF
$nonAscii = @($rawBytes | Where-Object { $_ -gt 127 }).Count
Write-Host 'Launcher file encoding' -ForegroundColor White
function Check {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        Write-Host ("  [PASS] " + $Name) -ForegroundColor Green
    } else {
        Write-Host ("  [FAIL] " + $Name + " " + $Detail) -ForegroundColor Red
        $failures.Add($Name)
    }
}

function Set-Parts {
    param([string]$Spec, [string]$Preset = 'custom')
    $Script:Config = [pscustomobject]@{ bodySizeParts = $Spec; bodySizePreset = $Preset }
}

Check 'bdo_aio.ps1 keeps its UTF-8 BOM (PS 5.1 shows mojibake without it)' ($hasBom -or $nonAscii -eq 0) ("bom=$hasBom non_ascii=$nonAscii")

# Mojibake signature: UTF-8 bytes decoded as ANSI and re-encoded, i.e. 0xC3 0xA2
# (the "a-circumflex" pair) appearing in the file. Checked as bytes so this test
# file itself stays pure ASCII.
$mojibake = $false
for ($i = 0; $i -lt ($rawBytes.Length - 1); $i++) {
    if ($rawBytes[$i] -eq 0xC3 -and $rawBytes[$i + 1] -eq 0xA2) { $mojibake = $true; break }
}
Check 'no mojibake byte sequences in the launcher' (-not $mojibake)
Write-Host ''

Write-Host 'Get-BodySizeSpec' -ForegroundColor White

Set-Parts 'breasts:2.0,thighs:1.5,butt:1.25,belly:1.2'
$spec = Get-BodySizeSpec
Check 'parses all four parts' ($spec.Count -eq 4)
Check 'breasts max is 2.0' ($spec['breasts'] -eq 2.0)
Check 'thighs max is 1.5' ($spec['thighs'] -eq 1.5)
Check 'butt max is 1.25' ($spec['butt'] -eq 1.25)
Check 'belly max is 1.2' ($spec['belly'] -eq 1.2)

Set-Parts 'breasts:2.0'
$spec = Get-BodySizeSpec
Check 'a one-part selection stays one part' ($spec.Count -eq 1 -and $spec.Contains('breasts')) ("got: " + ($spec.Keys -join ','))
Check 'unselected thighs are absent' (-not $spec.Contains('thighs'))
Check 'unselected butt is absent' (-not $spec.Contains('butt'))

Set-Parts 'pelvis:1.3'
$spec = Get-BodySizeSpec
Check 'pelvis resolves onto butt' ($spec.Contains('butt') -and $spec['butt'] -eq 1.3)

Set-Parts 'ass:1.2,pelvis:1.4'
$spec = Get-BodySizeSpec
Check 'ass and pelvis merge into one butt entry' ($spec.Count -eq 1 -and $spec['butt'] -eq 1.4) ("got: " + ($spec.Keys -join ','))

Set-Parts 'spine:1.2'
$spec = Get-BodySizeSpec
Check 'legacy spine resolves onto belly' ($spec.Count -eq 1 -and $spec['belly'] -eq 1.2) ("got: " + ($spec.Keys -join ','))

Set-Parts 'breasts:2.0,legs:2.0,spine:2.0,arms:2.0'
$spec = Get-BodySizeSpec
Check 'retired limbs are dropped while legacy spine becomes belly' ($spec.Count -eq 2 -and $spec.Contains('breasts') -and $spec.Contains('belly')) ("got: " + ($spec.Keys -join ','))

Set-Parts 'breasts'
Check 'a part with no max is rejected, not defaulted' ($null -eq (Get-BodySizeSpec))

Set-Parts 'legs:2.0,arms:2.0'
Check 'a retired-only selection yields null, never all' ($null -eq (Get-BodySizeSpec))

Set-Parts ''
Check 'an empty selection yields null, never all' ($null -eq (Get-BodySizeSpec))

Set-Parts 'breasts:0.5'
Check 'a max below 1.0 is rejected' ($null -eq (Get-BodySizeSpec))

Set-Parts 'breasts:abc'
Check 'a non-numeric max is rejected' ($null -eq (Get-BodySizeSpec))

Set-Parts 'BREASTS:2.0 , Thighs:1.5'
$spec = Get-BodySizeSpec
Check 'case and whitespace are tolerated' ($spec.Count -eq 2)

Write-Host ''
Write-Host 'Get-BodySizeArg' -ForegroundColor White
Set-Parts 'breasts:2.0,butt:1.25'
$arg = Get-BodySizeArg
Check 'round-trips into the python --parts form' ($arg -eq 'breasts:2,butt:1.25') ("got: " + $arg)
Set-Parts 'legs:2.0'
Check 'unusable config gives no argument at all' ($null -eq (Get-BodySizeArg))

Write-Host ''
Write-Host 'Update-BodySizeConfig (2.1.0 migration)' -ForegroundColor White

$Script:Config = [pscustomobject]@{
    bodySizeParts   = 'breasts,butt,thighs,arms,legs,pelvis,spine'
    bodySizePreset  = 'legacy'   # unknown name -> force default recommended
    bodySizeMin     = 0.80
    bodySizeDefault = 1.05
    bodySizeMax     = 2.50
}
Update-BodySizeConfig
Check 'legacy parts list migrates to recommended' ($Script:Config.bodySizeParts -eq $Script:BodySizeDefaultSpec) ("got: " + $Script:Config.bodySizeParts)
Check 'legacy preset migrates to recommended' ($Script:Config.bodySizePreset -eq 'recommended')
Check 'bodySizeMin is dropped' (-not ($Script:Config.PSObject.Properties.Name -contains 'bodySizeMin'))
Check 'bodySizeDefault is dropped' (-not ($Script:Config.PSObject.Properties.Name -contains 'bodySizeDefault'))
Check 'bodySizeMax is dropped' (-not ($Script:Config.PSObject.Properties.Name -contains 'bodySizeMax'))

$Script:Config = [pscustomobject]@{ bodySizeParts = 'breasts:2.0,thighs:1.5,butt:1.25'; bodySizePreset = 'recommended' }
Update-BodySizeConfig
Check 'a named preset gains the belly ceiling on version change' ($Script:Config.bodySizeParts -eq 'breasts:1.37,thighs:1.30,butt:1.18,belly:1.20') ("got: " + $Script:Config.bodySizeParts)

$Script:Config = [pscustomobject]@{ bodySizeParts = 'breasts:2.5'; bodySizePreset = 'custom' }
Update-BodySizeConfig
Check 'an already-migrated custom spec is preserved' ($Script:Config.bodySizeParts -eq 'breasts:2.5')
Check 'an already-migrated custom preset is preserved' ($Script:Config.bodySizePreset -eq 'custom')

$Script:Config = [pscustomobject]@{ bodySizeParts = ''; bodySizePreset = '' }
Update-BodySizeConfig
Check 'a blank config takes the safe default' ($Script:Config.bodySizeParts -eq $Script:BodySizeDefaultSpec)

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host ("FAILED: " + $failures.Count) -ForegroundColor Red
    exit 1
}
Write-Host 'ALL BODY SIZE CONFIG TESTS PASSED' -ForegroundColor Green
exit 0

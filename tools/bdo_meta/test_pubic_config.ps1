$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourcePath = Join-Path $root 'bdo_aio.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw ($parseErrors | ForEach-Object Message | Out-String) }

foreach ($name in @('Get-PubicStyleMap', 'Get-PubicClassCsv', 'Get-PubicStylesArg')) {
    $fn = $ast.FindAll({
        param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true) | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if (-not $fn) { throw ($name + ' was not found in bdo_aio.ps1.') }
    Invoke-Expression $fn.Extent.Text
}

$Script:PubicHairStyles = [ordered]@{
    'none' = 'No pubic hair'; 'shaved' = 'Shaved'; 'full_bush' = 'Full bush'
    'trimmed' = 'Trimmed'; 'small_bush' = 'Small bush'
}

$failures = New-Object System.Collections.Generic.List[string]
function Check {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) { Write-Host ("  [PASS] " + $Name) -ForegroundColor Green }
    else { Write-Host ("  [FAIL] " + $Name + " " + $Detail) -ForegroundColor Red; $failures.Add($Name) }
}
function Set-Styles { param([string]$V) $Script:Config = [pscustomobject]@{ pubicHairStyles = $V } }

Write-Host 'Get-PubicStyleMap' -ForegroundColor White

Set-Styles 'pnw=full_bush,pcw=trimmed,pgw=small_bush'
$m = Get-PubicStyleMap
Check 'parses three per-class styles' ($m.Count -eq 3)
Check 'kunoichi keeps its own style' ($m['pnw'] -eq 'full_bush')
Check 'mystic keeps a different style' ($m['pcw'] -eq 'trimmed')
Check 'guardian keeps a third style' ($m['pgw'] -eq 'small_bush')

Set-Styles ''
Check 'empty selection is empty, never all' ((Get-PubicStyleMap).Count -eq 0)
Check 'empty selection yields no tool argument' ($null -eq (Get-PubicStylesArg))

Set-Styles 'pnw=not_a_style'
Check 'unknown style is dropped' ((Get-PubicStyleMap).Count -eq 0)

Set-Styles 'pnw'
Check 'entry without a style is dropped' ((Get-PubicStyleMap).Count -eq 0)

Set-Styles 'PNW=FULL_BUSH , pcw=trimmed'
$m = Get-PubicStyleMap
Check 'case and spacing tolerated' ($m.Count -eq 2 -and $m['pnw'] -eq 'full_bush')

Set-Styles 'pnw=full_bush,pcw=trimmed'
Check 'class csv derives from the style map' ((Get-PubicClassCsv) -eq 'pnw,pcw') ("got: " + (Get-PubicClassCsv))
Check 'tool argument round-trips' ((Get-PubicStylesArg) -eq 'pnw=full_bush,pcw=trimmed') ("got: " + (Get-PubicStylesArg))

Write-Host ''
Write-Host 'Immersive preset' -ForegroundColor White

$presetAst = $ast.FindAll({
    param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst]
}, $true) | Where-Object { $_.Left.Extent.Text -eq '$Script:PubicImmersivePreset' } | Select-Object -First 1
if (-not $presetAst) { throw 'PubicImmersivePreset not found.' }
Invoke-Expression $presetAst.Extent.Text

$femaleAst = $ast.FindAll({
    param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst]
}, $true) | Where-Object { $_.Left.Extent.Text -eq '$Script:FemaleClasses' } | Select-Object -First 1
Invoke-Expression $femaleAst.Extent.Text

$realStyles = @(Get-ChildItem -Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tools\pubic_hair') -Directory |
    ForEach-Object { $_.Name })

$badStyle = @($Script:PubicImmersivePreset.Values | Where-Object { $_ -notin $realStyles })
Check 'every preset style has a real bin folder on disk' ($badStyle.Count -eq 0) ("bad: " + ($badStyle -join ', '))

$badClass = @($Script:PubicImmersivePreset.Keys | Where-Object { -not $Script:FemaleClasses.Contains($_) })
Check 'every preset class is a known female prefix' ($badClass.Count -eq 0) ("bad: " + ($badClass -join ', '))

# THE regression that made Maehwa/Woosa/Deadeye invisible: the preset gave
# individual styles to classes that share one texture, which forced the old
# PAC-renaming path. The preset must only ever name classes that own a texture.
$sharedAst = $ast.FindAll({
    param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst]
}, $true) | Where-Object { $_.Left.Extent.Text -eq '$Script:SharedAtlasPrefixes' } | Select-Object -First 1
Invoke-Expression $sharedAst.Extent.Text
$privateAst = $ast.FindAll({
    param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst]
}, $true) | Where-Object { $_.Left.Extent.Text -eq '$Script:PubicPrivateAtlasPrefixes' } | Select-Object -First 1
Invoke-Expression $privateAst.Extent.Text

$leaked = @($Script:PubicImmersivePreset.Keys | Where-Object { $_ -in $Script:SharedAtlasPrefixes })
Check 'preset never names a shared-texture class' ($leaked.Count -eq 0) ("leaked: " + ($leaked -join ', '))

$notPrivate = @($Script:PubicImmersivePreset.Keys | Where-Object { $_ -notin $Script:PubicPrivateAtlasPrefixes })
Check 'every preset class owns its own texture' ($notPrivate.Count -eq 0) ("bad: " + ($notPrivate -join ', '))

Check 'Corsair is excluded (no compatible hair bin)' (-not $Script:PubicImmersivePreset.Contains('pfw'))
Check 'shared-atlas list still has 13 classes' ($Script:SharedAtlasPrefixes.Count -eq 13) ("got: " + $Script:SharedAtlasPrefixes.Count)
Check 'shared and private lists do not overlap' (@($Script:PubicPrivateAtlasPrefixes | Where-Object { $_ -in $Script:SharedAtlasPrefixes }).Count -eq 0)
Check 'the two lists plus Corsair cover every female class' (($Script:SharedAtlasPrefixes.Count + $Script:PubicPrivateAtlasPrefixes.Count + 1) -eq $Script:FemaleClasses.Count)
Check 'Guardian is full bush' ($Script:PubicImmersivePreset['pgw'] -eq 'full_bush')

Write-Host ''
if ($failures.Count -gt 0) { Write-Host ("FAILED: " + $failures.Count) -ForegroundColor Red; exit 1 }
Write-Host 'ALL PUBIC CONFIG TESTS PASSED' -ForegroundColor Green
exit 0

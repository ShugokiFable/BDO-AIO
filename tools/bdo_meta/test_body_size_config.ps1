$ErrorActionPreference = 'Stop'

$localStageSource = Join-Path $PSScriptRoot 'bdo_aio.ps1'
if (Test-Path -LiteralPath $localStageSource) {
    $root = $PSScriptRoot
} else {
    $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$sourcePath = Join-Path $root 'bdo_aio.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw ($parseErrors | ForEach-Object Message | Out-String) }

foreach ($name in @(
    'Convert-BodySizeSpec', 'ConvertTo-BodySizeSpecString', 'Get-BodySizeSpec',
    'Format-BodySizeSpec', 'Get-BodySizeArg', 'Update-BodySizeConfig'
)) {
    $fn = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true) | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if (-not $fn) { throw ($name + ' was not found in bdo_aio.ps1.') }
    Invoke-Expression $fn.Extent.Text
}

foreach ($variableName in @(
    'BodySizeSchema', 'BodySizeAxes', 'BodySizeAxisDefaults',
    'BodySizeRecommendedSpec', 'BodySizeDefaultSpec'
)) {
    $assignment = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text -eq ('$Script:' + $variableName)
    }, $true) | Select-Object -First 1
    if (-not $assignment) { throw ('$Script:' + $variableName + ' was not found in bdo_aio.ps1.') }
    Invoke-Expression $assignment.Extent.Text
}

$failures = New-Object System.Collections.Generic.List[string]
function Check {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        Write-Host ('  [PASS] ' + $Name) -ForegroundColor Green
    } else {
        Write-Host ('  [FAIL] ' + $Name + ' ' + $Detail) -ForegroundColor Red
        $failures.Add($Name)
    }
}

function New-TestConfig {
    param([string]$Spec, [string]$Preset = 'custom', [int]$Schema = 0)
    $Script:Config = [pscustomobject]@{
        bodySizeSchema = $Schema
        bodySizeParts = $Spec
        bodySizePreset = $Preset
        bodySizeMin = 0.80
        bodySizeDefault = 1.05
        bodySizeMax = 2.50
    }
}

Write-Host 'Launcher encoding and schema contract' -ForegroundColor White
$rawBytes = [System.IO.File]::ReadAllBytes($sourcePath)
$hasBom = $rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF
$nonAscii = @($rawBytes | Where-Object { $_ -gt 127 }).Count
Check 'UTF-8 BOM is preserved for Windows PowerShell 5.1' ($hasBom -or $nonAscii -eq 0)
Check 'schema is exactly 2' ($Script:BodySizeSchema -eq 2)
Check 'Recommended spec is canonical and exact' ($Script:BodySizeRecommendedSpec -eq 'breasts.x:1.55,breasts.y:1.55,breasts.z:1.55,thighs.y:1.35,thighs.z:1.35,butt.x:1.20,butt.y:1.20,butt.z:1.20,pelvis.y:1.40,pelvis.z:1.40,belly.x:1.28,belly.z:1.45')
Check '12 supported axes are declared' ($Script:BodySizeAxes.Count -eq 12)
Write-Host ''

Write-Host 'Canonical parsing and formatting' -ForegroundColor White
$spec = Convert-BodySizeSpec 'breasts.x:1.55, breasts.y:1.80;belly.z:1.45'
Check 'canonical entries parse' ($spec.Count -eq 3)
Check 'breast width retains 1.80' ($spec['breasts.y'] -eq 1.80)
Check 'invariant formatter emits decimal points' ((ConvertTo-BodySizeSpecString $spec) -eq 'breasts.x:1.55,breasts.y:1.8,belly.z:1.45')
foreach ($bad in @('thighs.x:1.3', 'pelvis.x:1.4', 'belly.y:1.4', 'breasts.x:1.5,breasts.x:1.6', 'breasts.x:NaN', 'breasts.x:0.9', 'breasts.x:100', '')) {
    Check ('rejects invalid spec: ' + $bad) ($null -eq (Convert-BodySizeSpec $bad))
}
Write-Host ''

Write-Host 'Legacy migration expansion' -ForegroundColor White
$legacy = Convert-BodySizeSpec 'breasts:1.65,thighs:1.30,butt:1.18,belly:1.45'
Check 'legacy breast expands X/Y/Z' ($legacy['breasts.x'] -eq 1.65 -and $legacy['breasts.y'] -eq 1.65 -and $legacy['breasts.z'] -eq 1.65)
Check 'legacy thigh omits X' (-not $legacy.Contains('thighs.x') -and $legacy['thighs.y'] -eq 1.30 -and $legacy['thighs.z'] -eq 1.30)
Check 'legacy butt expands hips and pelvis' ($legacy['butt.x'] -eq 1.18 -and $legacy['pelvis.y'] -eq 1.18 -and $legacy['pelvis.z'] -eq 1.18)
Check 'legacy belly becomes Z only' ($legacy['belly.z'] -eq 1.45 -and -not $legacy.Contains('belly.x') -and -not $legacy.Contains('belly.y'))
Check 'retired-only spec fails closed' ($null -eq (Convert-BodySizeSpec 'legs:2.0,arms:2.0'))
Write-Host ''

Write-Host 'Get-BodySizeSpec and Python argument' -ForegroundColor White
New-TestConfig -Spec 'breasts.x:1.55,breasts.y:1.80,belly.z:1.45' -Schema 2
$parsed = Get-BodySizeSpec
Check 'current canonical config parses' ($parsed.Count -eq 3)
Check 'argument round-trips exactly' ((Get-BodySizeArg) -eq 'breasts.x:1.55,breasts.y:1.8,belly.z:1.45')
Write-Host ''

Write-Host 'Update-BodySizeConfig schema migration' -ForegroundColor White
New-TestConfig -Spec 'breasts:2.0,thighs:1.5,butt:1.18,belly:1.45' -Preset 'recommended' -Schema 1
Update-BodySizeConfig
Check 'named old preset becomes Recommended' ($Script:Config.bodySizeParts -eq $Script:BodySizeRecommendedSpec)
Check 'named old preset records schema 2' ($Script:Config.bodySizeSchema -eq 2)
Check 'obsolete Min/Default/Max properties are removed' (-not ($Script:Config.PSObject.Properties.Name -contains 'bodySizeMin') -and -not ($Script:Config.PSObject.Properties.Name -contains 'bodySizeDefault') -and -not ($Script:Config.PSObject.Properties.Name -contains 'bodySizeMax'))

New-TestConfig -Spec 'breasts:1.65,thighs:1.3,butt:1.18,belly:1.45' -Preset 'custom' -Schema 1
Update-BodySizeConfig
Check 'legacy Custom is retained through axis expansion' ($Script:Config.bodySizeParts -eq 'breasts.x:1.65,breasts.y:1.65,breasts.z:1.65,thighs.y:1.3,thighs.z:1.3,butt.x:1.18,butt.y:1.18,butt.z:1.18,pelvis.y:1.18,pelvis.z:1.18,belly.z:1.45') ($Script:Config.bodySizeParts)
Check 'legacy Custom does not infer belly X' (-not $Script:Config.bodySizeParts.Contains('belly.x'))

New-TestConfig -Spec 'breasts.x:1.65,belly.x:1.28,belly.z:1.45' -Preset 'custom' -Schema 2
Update-BodySizeConfig
Check 'schema 2 Custom remains literal' ($Script:Config.bodySizeParts -eq 'breasts.x:1.65,belly.x:1.28,belly.z:1.45')
Write-Host ''

Write-Host 'Simplified user-facing menu' -ForegroundColor White
$launcherText = [System.IO.File]::ReadAllText($sourcePath)
$configure = $ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Configure-BodySizeLimits'
}, $true) | Select-Object -First 1
$menuText = $configure.Extent.Text
Check 'menu offers Recommended' ($menuText -match '\[1\].*RECOMMENDED')
Check 'menu offers Custom' ($menuText -match '\[2\].*CUSTOM')
Check 'menu offers Keep current' ($menuText -match '\[3\].*Keep current')
Check 'active menu removes Baseline' ($menuText -notmatch '\[1\].*baseline')
Check 'active menu removes High' ($menuText -notmatch '\[3\].*high')
Check 'active menu removes Extreme' ($menuText -notmatch '\[4\].*extreme')
Check 'breast X meaning is explained' ($menuText -match 'X = length / forward projection')
Check 'uneven stock breast caps are explained' ($menuText -match 'X 1\.30.*Y/Z 1\.55')
Check 'equal additive test is shown' ($menuText -match '1\.55 / 1\.80 / 1\.80')
Check 'Spine X exception is explicit' ($menuText -match 'intentional.*HeightAxis')
Check 'butt is explained as cheek shape' ($menuText -match 'cheek shape / roundness, not overall ass size')
Check 'pelvis Z is explained as overall ass size' ($menuText -match 'pelvis\.z is the main overall pelvis / ass-size control')
Write-Host ''

if ($failures.Count -gt 0) {
    Write-Host ('FAILED: ' + $failures.Count) -ForegroundColor Red
    exit 1
}
Write-Host 'ALL BODY SIZE CONFIG TESTS PASSED' -ForegroundColor Green
exit 0

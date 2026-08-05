$ErrorActionPreference = 'Stop'

# Static sanity checks on bdo_aio.ps1. These catch the class of bug where a
# variable or function is deleted but a reference to it survives -- which only
# shows up at runtime, after the user has already done the work.

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourcePath = Join-Path $root 'bdo_aio.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)

$failures = New-Object System.Collections.Generic.List[string]
function Check {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) { Write-Host ("  [PASS] " + $Name) -ForegroundColor Green }
    else { Write-Host ("  [FAIL] " + $Name + " " + $Detail) -ForegroundColor Red; $failures.Add($Name) }
}

Write-Host 'Launcher static checks' -ForegroundColor White
Check 'parses under Windows PowerShell 5.1' ($parseErrors.Count -eq 0) (($parseErrors | ForEach-Object Message) -join '; ')
if ($parseErrors.Count -ne 0) { Write-Host 'FAILED'; exit 1 }

# Every function the script calls must exist somewhere in the script (or be a
# real cmdlet). Catches a deleted function still wired to a menu.
$defined = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
    ForEach-Object { $_.Name })
$called = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) |
    ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
$verbNoun = @($called | Where-Object { $_ -match '^[A-Z][a-z]+-[A-Za-z]' } | Select-Object -Unique)
$missing = @()
foreach ($c in $verbNoun) {
    if ($defined -contains $c) { continue }
    if (Get-Command $c -ErrorAction SilentlyContinue) { continue }
    $missing += $c
}
Check 'every called function exists' ($missing.Count -eq 0) ("missing: " + ($missing -join ', '))

# Per function: a local variable that is read but never assigned anywhere in that
# function, and is not a parameter / automatic / script-scoped, is a leftover.
$automatic = @('_', 'args', 'PSItem', 'true', 'false', 'null', 'PSScriptRoot', 'PSCommandPath',
    'LASTEXITCODE', 'Host', 'MyInvocation', 'Error', 'PWD', 'HOME', 'ErrorActionPreference',
    'PSVersionTable', 'OFS', 'input', 'foreach', 'switch', 'this', 'StackTrace', 'Matches')
$stale = @()
foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    # Parameters live on the function itself for `function Foo($a)` and on the
    # body's param block for `function Foo { param($a) }`. Both forms are used here.
    $params = @()
    if ($fn.Parameters) { $params += @($fn.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }) }
    if ($fn.Body.ParamBlock) { $params += @($fn.Body.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }) }
    $assigned = @($fn.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true) |
        ForEach-Object { $_.Left } |
        Where-Object { $_ -is [System.Management.Automation.Language.VariableExpressionAst] } |
        ForEach-Object { $_.VariablePath.UserPath })
    # foreach ($x in ...) also binds $x
    $assigned += @($fn.FindAll({ param($n) $n -is [System.Management.Automation.Language.ForEachStatementAst] }, $true) |
        ForEach-Object { $_.Variable.VariablePath.UserPath })
    $assigned += @($fn.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) |
        Where-Object { $_.GetCommandName() -eq 'New-Variable' } | ForEach-Object { 'skip' })
    foreach ($v in $fn.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)) {
        $name = $v.VariablePath.UserPath
        if ($v.VariablePath.IsGlobal -or $v.VariablePath.IsScript -or $name -like '*:*') { continue }
        if ($automatic -contains $name -or $params -contains $name -or $assigned -contains $name) { continue }
        $stale += ("{0}: `${1} (line {2})" -f $fn.Name, $name, $v.Extent.StartLineNumber)
    }
}
$stale = @($stale | Select-Object -Unique)
Check 'no variable is read without ever being assigned in its function' ($stale.Count -eq 0) ("`n      " + ($stale -join "`n      "))

Write-Host ''
if ($failures.Count -gt 0) { Write-Host ("FAILED: " + $failures.Count) -ForegroundColor Red; exit 1 }
Write-Host 'ALL LAUNCHER STATIC CHECKS PASSED' -ForegroundColor Green
exit 0

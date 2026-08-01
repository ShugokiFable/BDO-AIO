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

$functionAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Prepare-BdoInjectStage'
}, $true)
if (-not $functionAst) { throw 'Prepare-BdoInjectStage was not found.' }
Invoke-Expression $functionAst.Extent.Text

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('bdo-aio-meta-launch-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $dummyBuilder = Join-Path $tempRoot 'builder.ps1'
    Set-Content -LiteralPath $dummyBuilder -Encoding ASCII -Value @(
        "Write-Output 'builder stdout one'",
        "Write-Output 'builder stdout two'",
        'exit 0'
    )
    $Script:PythonExe = (Get-Process -Id $PID).Path
    $Script:InjectStageTool = $dummyBuilder
    function Write-Info([string]$Message) { Write-Host $Message }

    $stage = Prepare-BdoInjectStage -PazDrive 'X:' -SourceDrive 'Y:'
    if ($stage -isnot [string]) { throw "Stage must be one string; got $($stage.GetType().FullName)." }
    if ($stage -ne 'X:\BDO_AIO_INJECT') { throw "Unexpected stage path: $stage" }

    Write-Host 'PASS: stage-builder console output cannot contaminate the Meta Injector argument.'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

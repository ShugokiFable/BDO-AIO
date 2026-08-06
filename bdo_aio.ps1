#Requires -Version 5.1
# BDO Modding AIO - self-contained 2026 installer (everything under this folder)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:Version = '2.1.4'
$Script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ConfigPath = Join-Path $Script:Root 'config.json'
$Script:PackDir = Join-Path $Script:Root 'pack'
$Script:GraphicsDir = Join-Path $Script:Root 'graphics'
$Script:NvidiaDir = Join-Path $Script:GraphicsDir 'nvidia'
$Script:NipFileName = 'Black_Desert_Max_Quality.nip'
$Script:ExperimentalDlssDir = Join-Path $Script:Root 'experimental\dlss'
$Script:BodySizeTool = Join-Path $Script:Root 'tools\bdo_meta\body_size_patcher.py'
$Script:SlotHideTool = Join-Path $Script:Root 'tools\bdo_meta\slot_hide_patcher.py'
$Script:PubicHairTool = Join-Path $Script:Root 'tools\bdo_meta\pubic_hair_apply.py'
$Script:PubicHairRoot = Join-Path $Script:Root 'tools\pubic_hair'
$Script:CensorshipTool = Join-Path $Script:Root 'tools\bdo_meta\censorship_pack_apply.py'
$Script:CensorshipRoot = Join-Path $Script:Root 'tools\censorship_removal'
$Script:GenitalTool = Join-Path $Script:Root 'tools\bdo_meta\genital_pack_apply.py'
$Script:GenitalRoot = Join-Path $Script:Root 'tools\genital_packs'
$Script:GameOptionTool = Join-Path $Script:Root 'tools\bdo_meta\gameoption_patcher.py'
$Script:PazStatusTool = Join-Path $Script:Root 'tools\bdo_meta\paz_status_scan.py'
$Script:InjectStageTool = Join-Path $Script:Root 'tools\bdo_meta\inject_stage_builder.py'
$Script:PythonExe = $null
$Script:DefaultHeishaRoot = Join-Path $Script:Root 'heisha'
# AIO-generated folders under files_to_patch (safe to clear on restore)
$Script:AioPatchFolderPrefixes = @(
    '_body_size_limits',
    '_slot_hide_',
    '_pubic_hair_',
    '_censorship_',
    '_genital_'
)

$Script:PubicHairStyles = [ordered]@{
    'none'               = 'Off (do not apply)'
    'shaved'             = 'Shaved'
    'shaved_innie'       = 'Shaved innie'
    'full_bush'          = 'Full bush'
    'full_bush_2'        = 'Full bush 2'
    'full_bush_3'        = 'Full bush 3'
    'medium_bush'        = 'Medium bush'
    'medium_bush2'       = 'Medium bush 2'
    'small_bush'         = 'Small bush'
    'small_bush_2'       = 'Small bush 2'
    'thin_landing_strip' = 'Thin landing strip'
    'wide_landing_strip' = 'Wide landing strip'
    'trimmed'            = 'Trimmed'
    'wider_trimmed'      = 'Wider trimmed'
}

# Only these classes own their body texture, so only these can be given their own
# style. Corsair owns one too but no shipped hair bin matches its size.
$Script:PubicPrivateAtlasPrefixes = @('pbw', 'pdw', 'pew', 'pgw', 'pww')

# The 10 female classes with an authored 3D-vagina mesh in the Resorepless pack.
# A genital PAC is a whole body: it carries the mesh AND that class's skin
# material. Reusing one for another class gave the wrong body and skin (measured:
# 7 of 9 old donor mappings bound a different texture than the class really uses),
# so the newer classes are simply unsupported rather than faked.
$Script:GenitalFemalePrefixes = @(
    'pbw', 'pcw', 'pdw', 'pew', 'phw', 'pkww', 'pnw', 'psw', 'pvw', 'pww'
)

# Curated look, limited by what the assets actually allow. The other 13 classes
# all render from ONE texture, so they can only ever share a single style -- see
# Show-PubicIsolationNotice. Classes meant to read as bare are simply left out.
$Script:PubicImmersivePreset = [ordered]@{
    'pgw' = 'full_bush'
    'pew' = 'medium_bush'
    'pww' = 'medium_bush'
}
# Female class prefixes for per-class pubic/genital pickers (Shai excluded)
$Script:FemaleClasses = [ordered]@{
    'phw'  = 'Sorceress'
    'pew'  = 'Ranger'
    'pbw'  = 'Tamer'
    'pvw'  = 'Valkyrie'
    'pww'  = 'Witch'
    'pgw'  = 'Guardian [EXPER.]'
    'pnw'  = 'Kunoichi'
    'pdw'  = 'Dark Knight'
    'pcw'  = 'Mystic'
    'psw'  = 'Lahn'
    'ppw'  = 'Nova [EXPER.]'
    'pkww' = 'Maehwa'
    'pfw'  = 'Corsair [EXPER.]'
    'pqw'  = 'Drakania [EXPER.]'
    'pkow' = 'Maegu [EXPER.]'
    'pmyf' = 'Woosa [EXPER.]'
    'pnyw' = 'Scholar [EXPER.]'
    'pwge' = 'Deadeye [EXPER.]'
    'pdkl' = 'Seraph [EXPER.]'
}
$Script:NativePubicPrefixes = @('pbw', 'pdw', 'pew', 'phw', 'pww')
$Script:NewFemalePrefixes = @('pgw', 'ppw', 'pfw', 'pqw', 'pkow', 'pmyf', 'pnyw', 'pwge', 'pdkl')

# Measured from the Midnight nude PACs: these 13 all render from ONE texture,
# phw_01_nude_0001. Styling that DDS styles every one of them, which is why the
# old per-class pubic selector appeared to do nothing. Each of these needs a
# private texture copy to be styled on its own. The other six classes
# (pbw, pdw, pew, pfw, pgw, pww) own their texture and cost nothing extra.
$Script:SharedAtlasPrefixes = @(
    'phw', 'pnw', 'pcw', 'psw', 'ppw', 'pkww', 'pqw',
    'pkow', 'pmyf', 'pnyw', 'pvw', 'pwge', 'pdkl'
)
$Script:Config = $null

# Body size: 2.1.0 supports exactly three girth groups.
#   butt == hip + pelvis. On 33 of the game's 75 body files the hip bone's Max is
#   locked at <=1.00 (the butt slider cannot move at all), and pelvis is the only
#   bone there with headroom -- so they are patched as one option.
# legs/spine/arms were dropped: those scale bone LENGTH, and they are children of
#   pelvis, so they already inherit its scale.
$Script:BodySizeParts = @('breasts', 'thighs', 'butt')

# Body-size presets are MAX CEILINGS only (widen-only on Max= in
# customizationboneparamdesc). They do NOT force the body to that size.
#
# Live vanilla (restored NA client scan of all 75 boneparam files):
#   Default is almost always 1.00 (neutral).
#   Min is typically ~0.70 breasts / ~0.90 thighs-hips (floor of the slider).
#   Max (ceiling) is per-class; typical peaks:
#     breasts ~1.25 (majority), some classes already higher on Y/Z
#     thighs  ~1.10-1.15 peak (girth varies; some already 1.35)
#     hips    ~1.00 or 1.10 (many classes lock hip Max at 1.00)
#     pelvis  ~1.20 peak median
# "vanilla" preset ≈ typical STOCK Max ceilings per part (NOT the same number
# for every body part — breasts ~1.25, thighs ~1.15, hips ~1.10). Widen-only:
# never lowers a class that already has a higher stock Max.
#
# recommended = user-measured no-clip unlock (1.37 / 1.30 / 1.18)
# high/extreme = larger unlocks; some outfits will clip (user-only visuals)
$Script:BodySizePresets = [ordered]@{
    'vanilla'     = @{ Label = 'Stock Max ceilings (breasts 1.25 / thighs 1.15 / butt 1.10)'; Spec = 'breasts:1.25,thighs:1.15,butt:1.10' }
    'recommended' = @{ Label = 'RECOMMENDED no-clip unlock (1.37 / 1.30 / 1.18)'; Spec = 'breasts:1.37,thighs:1.30,butt:1.18' }
    'high'        = @{ Label = 'High (1.65 / 1.40 / 1.19) — breasts may clip; thighs may collide'; Spec = 'breasts:1.65,thighs:1.40,butt:1.19' }
    'extreme'     = @{ Label = 'Extreme (2.00 / 1.45 / 1.20) — breasts clip; thighs collide; butt mesh risk'; Spec = 'breasts:2.00,thighs:1.45,butt:1.20' }
}

$Script:BodySizeDefaultSpec = $Script:BodySizePresets['recommended'].Spec

# Files we may place in game root for experimental OptiScaler (uninstall list)
$Script:OptiProxyNames = @('dxgi.dll', 'winmm.dll', 'version.dll', 'd3d12.dll', 'dbghelp.dll', 'wininet.dll', 'winhttp.dll')
$Script:OptiExtraFiles = @(
    'OptiScaler.dll', 'OptiScaler.ini',
    'amd_fidelityfx_dx12.dll', 'amd_fidelityfx_framegeneration_dx12.dll',
    'amd_fidelityfx_upscaler_dx12.dll', 'amd_fidelityfx_vk.dll',
    'dlssg_to_fsr3_amd_is_better.dll', 'fakenvapi.dll', 'fakenvapi.ini',
    'libxell.dll', 'libxess.dll', 'libxess_dx11.dll', 'libxess_fg.dll',
    'setup_windows.bat', 'setup_linux.sh',
    'sl.common.dll', 'sl.deepdvc.dll', 'sl.directsr.dll', 'sl.dlss.dll',
    'sl.dlss_d.dll', 'sl.dlss_g.dll', 'sl.interposer.dll', 'sl.nis.dll',
    'sl.nvperf.dll', 'sl.pcl.dll', 'sl.reflex.dll'
)

# Bundled GameOption profiles (filename -> short description)
$Script:GraphicsProfiles = [ordered]@{
    'GameOption_Remastered_1080p.patch'       = 'Remastered 1080p - maximum-quality native gameplay'
    'GameOption_Remastered_1440p.patch'       = 'Remastered 1440p - maximum-quality native gameplay'
    'GameOption_Remastered_DLDSR_4K.patch'    = 'Remastered DLDSR 4K - maximum IQ on 1440p monitor (needs NVIDIA DSR 2.25x)'
}

$Script:GenderMap = [ordered]@{
    'F' = 'Female only'
    'M' = 'Male only'
    'B' = 'Both genders'
}
$Script:ArmorMap = [ordered]@{
    'A' = 'All armors and outfits (recommended for full nude look)'
    'P' = 'Pearl Shop outfits only'
    'F' = 'Free / non-cash outfits only'
    'U' = 'Underwear hide only (no full armor strip)'
}

function Write-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '  ============================================================' -ForegroundColor Cyan
    Write-Host ("   BDO MODDING AIO  " + $Script:Version + '  |  Self-contained  |  2026 pipeline') -ForegroundColor White
    Write-Host '   MODERN + RESTORED options  |  [X] EXPERIMENTAL only = from-scratch' -ForegroundColor DarkCyan
    Write-Host '  ============================================================' -ForegroundColor Cyan
    Write-Host ''
}

function Write-Info([string]$msg)  { Write-Host ("  [i] " + $msg) -ForegroundColor Cyan }
function Write-Ok([string]$msg)    { Write-Host ("  [OK] " + $msg) -ForegroundColor Green }
function Write-Warn([string]$msg)  { Write-Host ("  [!] " + $msg) -ForegroundColor Yellow }
function Write-Err([string]$msg)   { Write-Host ("  [X] " + $msg) -ForegroundColor Red }

function Pause-Any {
    Write-Host ''
    Write-Host '  Press any key to continue...' -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Read-Choice([string]$prompt, [string[]]$valid) {
    while ($true) {
        Write-Host ''
        $ans = (Read-Host ("  " + $prompt)).Trim().ToUpperInvariant()
        if ($valid -contains $ans) { return $ans }
        Write-Warn ("Pick one of: " + ($valid -join ', '))
    }
}

function Read-YesNo([string]$prompt, [bool]$defaultYes = $true) {
    $hint = if ($defaultYes) { 'Y/n' } else { 'y/N' }
    while ($true) {
        Write-Host ''
        $ans = (Read-Host ("  " + $prompt + " [" + $hint + "]")).Trim().ToLowerInvariant()
        if ([string]::IsNullOrEmpty($ans)) { return $defaultYes }
        if ($ans -in @('y', 'yes')) { return $true }
        if ($ans -in @('n', 'no'))  { return $false }
        Write-Warn 'Enter Y or N'
    }
}

function Get-FemaleClassKeys {
    return @($Script:FemaleClasses.Keys)
}

function Format-ClassList([string]$csv) {
    if ([string]::IsNullOrWhiteSpace($csv)) { return 'ALL females' }
    return $csv
}

function Select-FemaleClasses {
    param(
        [string]$Title = 'Select female classes',
        [string]$CurrentCsv = '',
        [switch]$DefaultAll
    )
    Write-Host ''
    Write-Host ("  " + $Title) -ForegroundColor White
    Write-Host '  -----------------------' -ForegroundColor DarkGray
    Write-Host ("  Current: " + (Format-ClassList $CurrentCsv)) -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host '    [A] ALL females' -ForegroundColor Green
    Write-Host '    [N] NATIVE pubic bins only (Tamer/DK/Ranger/Sorceress/Witch)' -ForegroundColor Cyan
    Write-Host '    [E] NEW females only (Seraph/Deadeye/Woosa/… EXPERIMENTAL)' -ForegroundColor Yellow
    Write-Host '    [C] CUSTOM multi-select by number' -ForegroundColor Magenta
    Write-Host '    [T] Type prefixes (e.g. phw,pdkl,pww)' -ForegroundColor Cyan
    Write-Host '    [K] Keep current' -ForegroundColor DarkGray
    $pick = (Read-Host '  Class pick').Trim().ToUpperInvariant()
    switch ($pick) {
        'A' { return '' }
        'N' { return ($Script:NativePubicPrefixes -join ',') }
        'E' { return ($Script:NewFemalePrefixes -join ',') }
        'K' { return $CurrentCsv }
        'T' {
            $raw = (Read-Host '  Prefixes comma-separated').Trim().ToLowerInvariant()
            if ([string]::IsNullOrWhiteSpace($raw)) { return '' }
            $legal = @($Script:FemaleClasses.Keys)
            $parts = @($raw -split '[,;\s]+' | Where-Object { $_ })
            $bad = @($parts | Where-Object { $_ -notin $legal })
            if ($bad.Count -gt 0) {
                Write-Warn ("Unknown prefixes ignored: " + ($bad -join ', '))
            }
            $ok = @($parts | Where-Object { $_ -in $legal } | Select-Object -Unique)
            if ($ok.Count -eq 0) {
                Write-Warn 'No valid prefixes — using ALL.'
                return ''
            }
            return ($ok -join ',')
        }
        'C' {
            $keys = @(Get-FemaleClassKeys)
            $on = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            if ([string]::IsNullOrWhiteSpace($CurrentCsv)) {
                if ($DefaultAll) { foreach ($k in $keys) { [void]$on.Add($k) } }
            } else {
                foreach ($p in ($CurrentCsv -split '[,;]+')) {
                    $t = $p.Trim()
                    if ($t) { [void]$on.Add($t) }
                }
            }
            while ($true) {
                Write-Host ''
                Write-Host '  Toggle classes (* = ON). Then D when done.' -ForegroundColor White
                for ($i = 0; $i -lt $keys.Count; $i++) {
                    $k = $keys[$i]
                    $mark = if ($on.Contains($k)) { '*' } else { ' ' }
                    $tag = if ($k -in $Script:NewFemalePrefixes) { ' EXPER' } elseif ($k -in $Script:NativePubicPrefixes) { ' native-bin' } else { '' }
                    Write-Host ("    [{0,2}] {1} {2,-6} {3}{4}" -f ($i + 1), $mark, $k, $Script:FemaleClasses[$k], $tag) -ForegroundColor Cyan
                }
                Write-Host '    [A] all on   [Z] all off   [N] native bins only   [E] new females only' -ForegroundColor DarkGray
                Write-Host '    [D] done' -ForegroundColor Green
                $cmd = (Read-Host '  Number(s) to toggle, or command').Trim().ToUpperInvariant()
                if ($cmd -eq 'D' -or $cmd -eq '') {
                    if ($on.Count -eq 0) {
                        Write-Warn 'None selected — using ALL females.'
                        return ''
                    }
                    if ($on.Count -eq $keys.Count) { return '' }
                    return (($on | Sort-Object) -join ',')
                }
                if ($cmd -eq 'A') { foreach ($k in $keys) { [void]$on.Add($k) }; continue }
                if ($cmd -eq 'Z') { $on.Clear(); continue }
                if ($cmd -eq 'N') {
                    $on.Clear()
                    foreach ($k in $Script:NativePubicPrefixes) { [void]$on.Add($k) }
                    continue
                }
                if ($cmd -eq 'E') {
                    $on.Clear()
                    foreach ($k in $Script:NewFemalePrefixes) { [void]$on.Add($k) }
                    continue
                }
                foreach ($tok in ($cmd -split '[,;\s]+')) {
                    if ($tok -match '^\d+$') {
                        $idx = [int]$tok - 1
                        if ($idx -ge 0 -and $idx -lt $keys.Count) {
                            $k = $keys[$idx]
                            if ($on.Contains($k)) { [void]$on.Remove($k) } else { [void]$on.Add($k) }
                        }
                    }
                }
            }
        }
        default {
            if ($DefaultAll -or [string]::IsNullOrWhiteSpace($CurrentCsv)) { return '' }
            return $CurrentCsv
        }
    }
}

function Load-Config {
    if (Test-Path -LiteralPath $Script:ConfigPath) {
        try {
            $Script:Config = Get-Content -LiteralPath $Script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Write-Warn 'config.json was unreadable; using defaults.'
            $Script:Config = $null
        }
    }
    if (-not $Script:Config) {
        $Script:Config = [pscustomobject]@{
            pazFolder       = ''
            gender          = 'F'
            armor           = 'A'
            xyzwCollections = $true
            npiPath         = ''
            bodySizePreset  = 'recommended'
            bodySizeParts   = 'breasts:1.37,thighs:1.30,butt:1.18'
            hideGloves      = $false
            hideBoots       = $false
            hideHelmets     = $false
            hideWeapons     = $false
            hideStockings   = $false
            slotHideClasses = ''
            pubicHairStyle  = 'none'
            pubicHairStyles = ''
            pubicHairReuse  = $false
            pubicHairClasses = ''
            censorshipTier  = 'off'
            female3dVagina  = $false
            genitalFemaleClasses = ''
            genitalReuse    = $false
            malePenisMode   = 'none'
            penisWarrior    = 'none'
            penisBerserker  = 'none'
            penisMusa       = 'none'
            penisWizard     = 'none'
            penisNinja      = 'none'
            penisStriker    = 'none'
            heishaRoot      = ''
            lastRun         = $null
        }
    }
    foreach ($p in @('pazFolder', 'gender', 'armor', 'xyzwCollections', 'npiPath', 'bodySizePreset', 'bodySizeParts', 'hideGloves', 'hideBoots', 'hideHelmets', 'hideWeapons', 'hideStockings', 'slotHideClasses', 'pubicHairStyle', 'pubicHairStyles', 'pubicHairReuse', 'pubicHairClasses', 'censorshipTier', 'female3dVagina', 'genitalFemaleClasses', 'genitalReuse', 'malePenisMode', 'penisWarrior', 'penisBerserker', 'penisMusa', 'penisWizard', 'penisNinja', 'penisStriker', 'heishaRoot', 'lastRun')) {
        if (-not ($Script:Config.PSObject.Properties.Name -contains $p)) {
            $val = switch ($p) {
                'gender' { 'F' }
                'armor'  { 'A' }
                'xyzwCollections' { $true }
                'bodySizePreset' { 'recommended' }
                'bodySizeParts' { $Script:BodySizeDefaultSpec }
                'hideGloves' { $false }
                'hideBoots' { $false }
                'hideHelmets' { $false }
                'hideWeapons' { $false }
                'hideStockings' { $false }
                'slotHideClasses' { '' }
                'pubicHairStyle' { 'none' }
                'pubicHairStyles' { '' }
                'pubicHairReuse' { $false }
                'pubicHairClasses' { '' }
                'censorshipTier' { 'off' }
                'female3dVagina' { $false }
                'genitalFemaleClasses' { '' }
                'genitalReuse' { $false }
                'malePenisMode' { 'none' }
                'penisWarrior' { 'none' }
                'penisBerserker' { 'none' }
                'penisMusa' { 'none' }
                'penisWizard' { 'none' }
                'penisNinja' { 'none' }
                'penisStriker' { 'none' }
                'heishaRoot' { '' }
                default { $null }
            }
            if ($null -eq $val -and $p -ne 'lastRun') {
                if ($p -match '^hide') { $val = $false } else { $val = '' }
            }
            Add-Member -InputObject $Script:Config -NotePropertyName $p -NotePropertyValue $val
        }
    }
    Update-BodySizeConfig
}

# 2.1.0 migration. Pre-2.1.0 configs stored a single min/default/max applied to
# every part, including legs/spine/arms, and overwrote the game's per-class
# Default -- that is what stretched bodies. Those settings have no equivalent
# under the new widen-only model, so a legacy config is moved to the
# recommended preset once. A config already using the name:max form is kept.
function Update-BodySizeConfig {
    foreach ($dead in @('bodySizeMin', 'bodySizeDefault', 'bodySizeMax')) {
        if ($Script:Config.PSObject.Properties.Name -contains $dead) {
            $Script:Config.PSObject.Properties.Remove($dead)
        }
    }
    # A named preset always re-derives its spec, so tuning a preset's numbers in a
    # new version reaches users who picked that preset. Only 'custom' is literal.
    $preset = [string]$Script:Config.bodySizePreset
    if ($preset -and $Script:BodySizePresets.Contains($preset)) {
        $Script:Config.bodySizeParts = $Script:BodySizePresets[$preset].Spec
        return
    }

    $spec = [string]$Script:Config.bodySizeParts
    if ($spec -and $spec.Contains(':')) { return }

    $Script:Config.bodySizeParts = $Script:BodySizeDefaultSpec
    $Script:Config.bodySizePreset = 'recommended'
    if ($spec) {
        Write-Host ''
        Write-Host ('  [MIGRATED] Body sliders "' + $spec + '" -> ' + $Script:BodySizeDefaultSpec) -ForegroundColor Yellow
        Write-Host '             2.1.0 patches breasts/thighs/butt only, widen-only, and no' -ForegroundColor DarkGray
        Write-Host '             longer rewrites the game Default or any bone-length axis.' -ForegroundColor DarkGray
        Write-Host '             Re-run menu 2 if you want different numbers.' -ForegroundColor DarkGray
    }
}

function Save-Config {
    $Script:Config.lastRun = (Get-Date).ToString('s')
    # Store game path, choices, optional NPI path (NPI path is machine-local)
    $out = [pscustomobject]@{
        pazFolder       = [string]$Script:Config.pazFolder
        gender          = [string]$Script:Config.gender
        armor           = [string]$Script:Config.armor
        xyzwCollections = [bool]$Script:Config.xyzwCollections
        npiPath         = [string]$Script:Config.npiPath
        bodySizePreset  = [string]$Script:Config.bodySizePreset
        bodySizeParts   = [string]$Script:Config.bodySizeParts
        hideGloves      = [bool]$Script:Config.hideGloves
        hideBoots       = [bool]$Script:Config.hideBoots
        hideHelmets     = [bool]$Script:Config.hideHelmets
        hideWeapons     = [bool]$Script:Config.hideWeapons
        hideStockings   = [bool]$Script:Config.hideStockings
        slotHideClasses = [string]$Script:Config.slotHideClasses
        pubicHairStyle  = [string]$Script:Config.pubicHairStyle
        pubicHairStyles = [string]$Script:Config.pubicHairStyles
        pubicHairReuse  = [bool]$Script:Config.pubicHairReuse
        pubicHairClasses = [string]$Script:Config.pubicHairClasses
        censorshipTier  = [string]$Script:Config.censorshipTier
        female3dVagina  = [bool]$Script:Config.female3dVagina
        genitalFemaleClasses = [string]$Script:Config.genitalFemaleClasses
        genitalReuse    = [bool]$Script:Config.genitalReuse
        malePenisMode   = [string]$Script:Config.malePenisMode
        penisWarrior    = [string]$Script:Config.penisWarrior
        penisBerserker  = [string]$Script:Config.penisBerserker
        penisMusa       = [string]$Script:Config.penisMusa
        penisWizard     = [string]$Script:Config.penisWizard
        penisNinja      = [string]$Script:Config.penisNinja
        penisStriker    = [string]$Script:Config.penisStriker
        heishaRoot      = [string]$Script:Config.heishaRoot
        lastRun         = $Script:Config.lastRun
    }
    $json = $out | ConvertTo-Json -Depth 4
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($Script:ConfigPath, $json, $utf8Bom)
}

function Test-IsPazFolder([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { return $false }
    return (Test-Path -LiteralPath (Join-Path $path 'pad00000.meta'))
}

function Test-PackReady {
    $need = @(
        (Join-Path $Script:PackDir 'midnight_xyzw.cmd'),
        (Join-Path $Script:PackDir 'midnight_xyzw\midnight_xyzw.py'),
        (Join-Path $Script:PackDir 'PartCutGen.exe'),
        (Join-Path $Script:PackDir 'Meta Injector.exe')
    )
    $missing = @($need | Where-Object { -not (Test-Path -LiteralPath $_) })
    return @{
        Ok      = ($missing.Count -eq 0)
        Missing = $missing
        PackDir = $Script:PackDir
    }
}

function Test-GraphicsReady {
    $missing = @($Script:GameOptionTool | Where-Object { -not (Test-Path -LiteralPath $_) })
    foreach ($name in $Script:GraphicsProfiles.Keys) {
        $p = Join-Path $Script:GraphicsDir $name
        if (-not (Test-Path -LiteralPath $p)) { $missing += $p }
    }
    return @{
        Ok           = ($missing.Count -eq 0)
        Missing      = $missing
        GraphicsDir  = $Script:GraphicsDir
    }
}

function Get-BdoDocumentsFolder {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    return (Join-Path $docs 'Black Desert')
}

function Get-BundledNipPath {
    return (Join-Path $Script:NvidiaDir $Script:NipFileName)
}

function Test-NipReady {
    $p = Get-BundledNipPath
    return @{
        Ok  = (Test-Path -LiteralPath $p)
        Path = $p
    }
}

function Find-NvidiaProfileInspector {
    # 1) User-saved path in config
    $cfg = [string]$Script:Config.npiPath
    if ($cfg -and (Test-Path -LiteralPath $cfg)) { return $cfg }

    # 2) Bundled with this AIO (preferred for publish)
    $bundled = Join-Path $Script:Root 'tools\nvidiaProfileInspector\nvidiaProfileInspector.exe'
    if (Test-Path -LiteralPath $bundled) { return $bundled }

    # 3) Common install locations (this machine + generic)
    $candidates = @(
        (Join-Path $env:USERPROFILE 'Documents\Apps\NvidiaProfileInspector\nvidiaProfileInspector.exe'),
        (Join-Path $env:USERPROFILE 'Documents\Apps\NVIDIA Profile Inspector\nvidiaProfileInspector.exe'),
        (Join-Path $env:USERPROFILE 'Desktop\nvidiaProfileInspector\nvidiaProfileInspector.exe'),
        'C:\Tools\nvidiaProfileInspector\nvidiaProfileInspector.exe',
        'C:\Program Files\NVIDIA Profile Inspector\nvidiaProfileInspector.exe',
        'C:\Program Files (x86)\NVIDIA Profile Inspector\nvidiaProfileInspector.exe'
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }

    # 4) PATH
    $cmd = Get-Command nvidiaProfileInspector.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    return $null
}

function Find-CommonPazCandidates {
    $hits = New-Object System.Collections.Generic.List[string]
    $roots = @(
        ${env:ProgramFiles(x86)},
        $env:ProgramFiles,
        'D:\',
        'E:\',
        'C:\Games',
        'C:\Program Files (x86)\Steam\steamapps\common',
        'C:\Program Files\Steam\steamapps\common',
        'C:\KakaoGames',
        'C:\Program Files (x86)\PearlAbyss'
    ) | Where-Object { $_ -and (Test-Path $_) }

    $names = @('BlackDesert', 'Black Desert Online', 'BlackDesertNA', 'BlackDesertEU', 'BDO')
    foreach ($root in $roots) {
        foreach ($n in $names) {
            $p = Join-Path (Join-Path $root $n) 'PAZ'
            if (Test-IsPazFolder $p) { [void]$hits.Add($p) }
        }
        try {
            Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'BlackDesert|Black Desert|BDO' } |
                ForEach-Object {
                    $p = Join-Path $_.FullName 'PAZ'
                    if (Test-IsPazFolder $p) { [void]$hits.Add($p) }
                }
        } catch {}
    }
    return @($hits | Select-Object -Unique)
}

function Ensure-Python {
    if ($Script:PythonExe -and (Test-Path -LiteralPath $Script:PythonExe)) { return $true }

    $commands = @(Get-Command python.exe -All -ErrorAction SilentlyContinue)
    foreach ($command in $commands) {
        try {
            $resolved = & $command.Source -c 'import sys; print(sys.executable)' 2>$null
            $resolvedPath = [string](@($resolved)[-1])
            if ($LASTEXITCODE -eq 0 -and $resolvedPath -and (Test-Path -LiteralPath $resolvedPath)) {
                $Script:PythonExe = $resolvedPath
                Write-Ok ("Python found: " + $Script:PythonExe)
                return $true
            }
        } catch {}
    }

    $launcher = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($launcher) {
        try {
            $resolved = & $launcher.Source -3 -c 'import sys; print(sys.executable)' 2>$null
            $resolvedPath = [string](@($resolved)[-1])
            if ($LASTEXITCODE -eq 0 -and $resolvedPath -and (Test-Path -LiteralPath $resolvedPath)) {
                $Script:PythonExe = $resolvedPath
                Write-Ok ("Python found through py launcher: " + $Script:PythonExe)
                return $true
            }
        } catch {}
    }

    $localPrograms = Join-Path $env:LOCALAPPDATA 'Programs\Python'
    if (Test-Path -LiteralPath $localPrograms) {
        $local = Get-ChildItem -LiteralPath $localPrograms -Filter python.exe -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($local) {
            $Script:PythonExe = $local.FullName
            Write-Ok ("Python found: " + $Script:PythonExe)
            return $true
        }
    }
    Write-Err 'Python is not installed (or not on PATH).'
    Write-Info 'Midnight deploy needs Python once (system install).'
    Write-Host '  Install with:  winget install Python.Python.3.12' -ForegroundColor White
    Write-Host '  Then close this window and run START.bat again.' -ForegroundColor White
    if (Read-YesNo 'Open winget install now?' $true) {
        try {
            Start-Process winget -ArgumentList @('install', '-e', '--id', 'Python.Python.3.12', '--accept-package-agreements', '--accept-source-agreements') -Wait
        } catch {
            Write-Warn 'Could not launch winget. Install Python from python.org or Microsoft Store.'
        }
        $py2 = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($py2) {
            $Script:PythonExe = $py2.Source
            Write-Ok ("Python is available now: " + $Script:PythonExe)
            return $true
        }
    }
    return $false
}

function Invoke-BdoPythonChecked {
    param(
        [object[]]$Arguments,
        [string]$Label = 'Python tool'
    )
    try {
        & $Script:PythonExe @Arguments
        if ($LASTEXITCODE -ne 0) {
            Write-Err ("$Label failed with exit code $LASTEXITCODE")
            return $false
        }
        return $true
    } catch {
        Write-Err ("$Label failed: " + $_.Exception.Message)
        return $false
    }
}

function Show-DevModeHint {
    Write-Info 'Optional: enable Windows Developer Mode for faster deploy (symlinks instead of huge copies).'
    Write-Host '  Settings -> System -> For developers -> Developer Mode = On' -ForegroundColor DarkGray
}

function Get-GenderLabel([string]$code) {
    if ($Script:GenderMap.Contains($code)) { return $Script:GenderMap[$code] }
    return $code
}

function Get-ArmorLabel([string]$code) {
    if ($Script:ArmorMap.Contains($code)) { return $Script:ArmorMap[$code] }
    return $code
}

function Get-PazStatusReport {
    param([string]$PazFolder)
    if (-not (Test-IsPazFolder $PazFolder)) { return $null }
    if (-not (Test-Path -LiteralPath $Script:PazStatusTool)) { return $null }
    if (-not (Ensure-Python)) { return $null }
    try {
        $json = & $Script:PythonExe $Script:PazStatusTool --paz $PazFolder --json 2>$null
        if (-not $json) { return $null }
        return ($json | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Show-PazInjectStatus {
    param(
        [string]$PazFolder,
        [switch]$Detailed
    )
    Write-Host ''
    Write-Host '  PAZ inject status (stock vs modded)' -ForegroundColor White
    Write-Host '  -----------------------------------' -ForegroundColor DarkGray
    if (-not (Test-IsPazFolder $PazFolder)) {
        Write-Warn '  Set a valid PAZ folder first (menu 1).'
        return
    }
    if (-not (Test-Path -LiteralPath $Script:PazStatusTool)) {
        Write-Warn '  paz_status_scan.py missing.'
        return
    }
    if (-not (Ensure-Python)) { return }

    if ($Detailed) {
        & $Script:PythonExe $Script:PazStatusTool --paz $PazFolder --write-status auto
        return
    }

    $rep = Get-PazStatusReport -PazFolder $PazFolder
    if (-not $rep) {
        Write-Warn '  Could not scan PAZ status.'
        return
    }

    $overall = [string]$rep.overall
    $metaState = [string]$rep.meta.state
    $col = switch -Wildcard ($overall) {
        '*STOCK*' { 'Green' }
        '*RESTORED*' { 'Green' }
        '*STAGED only*' { 'Yellow' }
        '*INJECTED*' { 'Magenta' }
        default { 'Cyan' }
    }
    Write-Host ("  OVERALL : " + $overall) -ForegroundColor $col
    if ($rep.overall_detail) {
        Write-Host ("           " + $rep.overall_detail) -ForegroundColor DarkGray
    }
    Write-Host ("  META    : " + $metaState) -ForegroundColor $(if ($metaState -eq 'MODDED') { 'Magenta' } elseif ($metaState -in @('STOCK', 'RESTORED')) { 'Green' } else { 'Yellow' })
    if ($rep.meta.detail) {
        Write-Host ("           " + $rep.meta.detail) -ForegroundColor DarkGray
    }
    $bc = 0
    if ($rep.backups) { $bc = @($rep.backups).Count }
    Write-Host ("  Backups : " + $bc + " Meta Injector *.meta.backup file(s)") -ForegroundColor Gray
    if ($rep.files_to_patch -and $rep.files_to_patch.exists) {
        Write-Host ("  Staged  : files_to_patch has " + $rep.files_to_patch.total_files + " file(s)") -ForegroundColor Gray
        if ($rep.files_to_patch.aio_packages) {
            foreach ($p in @($rep.files_to_patch.aio_packages)) {
                Write-Host ("           AIO: " + $p.name + " (" + $p.files + " files)") -ForegroundColor DarkCyan
            }
        }
    } else {
        Write-Host '  Staged  : no files_to_patch content' -ForegroundColor Gray
    }
    if ($rep.experimental_dlss -and $rep.experimental_dlss.installed) {
        Write-Host '  Exper.  : OptiScaler/DLSS inject MARKED in game root  [EXPERIMENTAL]' -ForegroundColor Red
    } else {
        Write-Host '  Exper.  : no experimental client inject marker' -ForegroundColor Gray
    }
    Write-Host '  Full report: menu [S]  |  Restore inject: Meta Injector "Restore Backup" or menu [R]' -ForegroundColor DarkGray
}

function Show-Status {
    Write-Host '  Current setup' -ForegroundColor White
    Write-Host '  -------------' -ForegroundColor DarkGray

    $pack = Test-PackReady
    if ($pack.Ok) {
        Write-Ok ("Pack      : " + $Script:PackDir + "  (bundled)")
    } else {
        Write-Err ("Pack      : incomplete under " + $Script:PackDir)
        foreach ($m in $pack.Missing) {
            Write-Warn ("  missing: " + $m)
        }
    }

    $paz = [string]$Script:Config.pazFolder
    if (Test-IsPazFolder $paz) {
        Write-Ok ("Game PAZ  : " + $paz)
        Show-PazInjectStatus -PazFolder $paz
    } elseif ($paz) {
        Write-Warn ("Game PAZ  : " + $paz + "  (pad00000.meta missing - check path)")
    } else {
        Write-Warn 'Game PAZ  : not set (user game folder only - not bundled)'
    }

    $gfx = Test-GraphicsReady
    if ($gfx.Ok) {
        Write-Ok ("Graphics  : " + $Script:GraphicsDir + "  (3 safe GameOption merge patches)")
    } else {
        Write-Warn ("Graphics  : incomplete under " + $Script:GraphicsDir)
    }

    $nip = Test-NipReady
    $npi = Find-NvidiaProfileInspector
    if ($nip.Ok) {
        Write-Ok ("NVIDIA NIP: " + $nip.Path)
    } else {
        Write-Warn ("NVIDIA NIP: missing " + $Script:NipFileName)
    }
    if ($npi) {
        Write-Ok ("NPI app   : " + $npi)
    } else {
        Write-Warn 'NPI app   : nvidiaProfileInspector.exe not found (menu N can browse)'
    }

    $optiDll = Join-Path $Script:ExperimentalDlssDir 'OptiScaler\OptiScaler.dll'
    if (Test-Path -LiteralPath $optiDll) {
        Write-Host '  [EXPERIMENTAL] DLSS/OptiScaler pack present  -> menu [X]  NOT SAFE' -ForegroundColor Red
    } else {
        Write-Warn 'Experimental DLSS pack missing under experimental\dlss\'
    }

    $g = [string]$Script:Config.gender
    $a = [string]$Script:Config.armor
    $x = [bool]$Script:Config.xyzwCollections
    Write-Host ("  Gender   : " + $g + " (" + (Get-GenderLabel $g) + ")") -ForegroundColor Gray
    Write-Host ("  Armor    : " + $a + " (" + (Get-ArmorLabel $a) + ")") -ForegroundColor Gray
    $xyzwText = if ($x) { 'Yes' } else { 'No' }
    Write-Host ("  Collections (XYZW outfits): " + $xyzwText) -ForegroundColor Gray
    try {
        Write-Host ("  Body size: " + [string]$Script:Config.bodySizePreset) -ForegroundColor Gray
        Write-Host ("  Body parts: " + (Format-BodySizeSpec (Get-BodySizeSpec))) -ForegroundColor Gray
    } catch {
        Write-Host '  Body size: (configure in menu 2)' -ForegroundColor Gray
    }
    Write-Host ''
}

function Set-PazFolder {
    Write-Banner
    Write-Host '  Set game PAZ folder' -ForegroundColor White
    Write-Host '  -------------------' -ForegroundColor DarkGray
    Write-Info 'This is YOUR Black Desert install (not inside this AIO folder).'
    Write-Info 'It must contain pad00000.meta'
    Write-Host ''

    $cands = @(Find-CommonPazCandidates)
    if ($cands.Count -gt 0) {
        Write-Host '  Found possible PAZ folders:' -ForegroundColor White
        for ($i = 0; $i -lt $cands.Count; $i++) {
            Write-Host ("    [" + ($i + 1) + "] " + $cands[$i]) -ForegroundColor Cyan
        }
        Write-Host '    [M] Type path manually' -ForegroundColor Cyan
        Write-Host '    [B] Browse with folder dialog' -ForegroundColor Cyan
        Write-Host '    [0] Cancel' -ForegroundColor DarkGray
        $pick = Read-Host '  Choice'
        if ($pick -eq '0') { return }
        if ($pick -match '^\d+$') {
            $idx = [int]$pick - 1
            if ($idx -ge 0 -and $idx -lt $cands.Count) {
                $Script:Config.pazFolder = $cands[$idx]
                Save-Config
                Write-Ok ("Saved PAZ: " + $Script:Config.pazFolder)
                Pause-Any
                return
            }
        }
        if ($pick -match '^[Mm]$') {
            $manual = (Read-Host '  Full path to PAZ folder').Trim().Trim('"')
            if (Test-IsPazFolder $manual) {
                $Script:Config.pazFolder = $manual
                Save-Config
                Write-Ok ("Saved PAZ: " + $Script:Config.pazFolder)
            } else {
                Write-Err 'That path does not look like a valid PAZ folder (pad00000.meta missing).'
            }
            Pause-Any
            return
        }
        if ($pick -notmatch '^[Bb]$') {
            Write-Warn 'Invalid choice.'
            Pause-Any
            return
        }
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Select your Black Desert PAZ folder (contains pad00000.meta)'
        $dlg.ShowNewFolderButton = $false
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $p = $dlg.SelectedPath
            if (Test-IsPazFolder $p) {
                $Script:Config.pazFolder = $p
                Save-Config
                Write-Ok ("Saved PAZ: " + $p)
            } else {
                Write-Err 'Selected folder is not a valid PAZ (pad00000.meta missing).'
            }
        }
    } catch {
        $manual = (Read-Host '  Folder dialog failed. Type full PAZ path').Trim().Trim('"')
        if (Test-IsPazFolder $manual) {
            $Script:Config.pazFolder = $manual
            Save-Config
            Write-Ok ("Saved PAZ: " + $Script:Config.pazFolder)
        } else {
            Write-Err 'Invalid PAZ path.'
        }
    }
    Pause-Any
}

function Configure-ModChoices {
    Write-Banner
    Write-Host '  OPTIONS HUB  (clearly labeled by origin)' -ForegroundColor White
    Write-Host '  ========================================' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Labels:' -ForegroundColor White
    Write-Host '    MODERN      = current Midnight / 2026 pipeline (recommended)' -ForegroundColor Cyan
    Write-Host '    RESTORED            = classic feature with NATIVE assets only' -ForegroundColor Green
    Write-Host '    EXPERIMENTAL        = from-scratch (DLSS inject) — not a classic restore' -ForegroundColor Red
    Write-Host ''

    Write-Host '  --- MODERN (Midnight) ---' -ForegroundColor Cyan
    Write-Host '   [1] Gender + armor hide + collections' -ForegroundColor Cyan
    Write-Host ''

    Write-Host '  --- RESTORED (classic / NATIVE assets) ---' -ForegroundColor Green
    Write-Host '   [2] Body size LIMITS (min/default/max + custom)  [RESTORED]' -ForegroundColor Green
    Write-Host '   [3] Apply body size patch now' -ForegroundColor Green
    Write-Host '   [4] Slot hide (gloves/boots/helmets/weapons/stockings)  [RESTORED]' -ForegroundColor Green
    Write-Host '   [5] Apply slot hide patch now' -ForegroundColor Green
    Write-Host '   [6] Pubic hair style  [RESTORED = native bins only by default]' -ForegroundColor Green
    Write-Host '   [7] Apply pubic hair now' -ForegroundColor Green
    Write-Host '   [C] Censorship tier presets  [RESTORED / old outfit textures]' -ForegroundColor Green
    Write-Host '   [V] Penis / 3D vagina  [RESTORED = authored meshes only]' -ForegroundColor Green
    Write-Host ''

    Write-Host '   [X] DLSS/OptiScaler inject hub  *** NOT SAFE / FROM-SCRATCH ***' -ForegroundColor Red
    Write-Host ''

    Write-Host '  --- TOOLS / INFO ---' -ForegroundColor Yellow
    Write-Host '   [8] Feature origin matrix (modern / restored / experimental)' -ForegroundColor Yellow
    Write-Host '   [0] Back' -ForegroundColor DarkGray
    Write-Host ''
    $c = (Read-Host '  Select').Trim().ToUpperInvariant()
    switch ($c) {
        '1' { Configure-MidnightChoices }
        '2' { Configure-BodySizeLimits }
        '3' { Apply-BodySizePatch }
        '4' { Configure-SlotHide }
        '5' { Apply-SlotHidePatch }
        '6' { Configure-PubicHair }
        '7' { Apply-PubicHair }
        'C' { Configure-CensorshipTier }
        'V' { Configure-GenitalMenus }
        'X' { Show-ExperimentalDlssMenu }
        '8' { Show-OptionsMatrix }
        default { return }
    }
}

function Configure-CensorshipTier {
    Write-Banner
    Write-Host '  CENSORSHIP TIER PRESETS' -ForegroundColor Magenta
    Write-Host '  ----------------------' -ForegroundColor DarkGray
    Write-Info 'Legacy = classic Resorepless outfit textures. Expanded = live PAZ under-armor scan.'
    Write-Warn 'Not perfect on every pearl outfit. Pair with Midnight Armor=All for best coverage.'
    Write-Host ''
    Write-Host '    [0] Off' -ForegroundColor DarkGray
    Write-Host '    [1] Minimal  — some Tamer/Ranger built-in panties  [RESTORED]' -ForegroundColor Cyan
    Write-Host '    [2] Medium   — + upper undercovers / more decals  [RESTORED]' -ForegroundColor Green
    Write-Host '    [3] High     — same texture set as medium  [RESTORED]' -ForegroundColor Cyan
    Write-Host '    [4] Expanded — medium + blank new/all-class under-decals from live PAZ' -ForegroundColor Yellow
    Write-Host '                  (scans *_dec* / under* / cull textures; best-effort)' -ForegroundColor DarkYellow
    $t = Read-Choice 'Tier' @('0', '1', '2', '3', '4')
    $Script:Config.censorshipTier = switch ($t) {
        '0' { 'off' }
        '1' { 'minimal' }
        '2' { 'medium' }
        '3' { 'high' }
        '4' { 'expanded' }
    }
    Save-Config
    Write-Ok ("Censorship tier: " + $Script:Config.censorshipTier)
    if ($Script:Config.censorshipTier -ne 'off' -and (Read-YesNo 'Apply censorship texture pack now?' $true)) {
        Apply-CensorshipPack
    } else {
        Pause-Any
    }
}

function Apply-CensorshipPack {
    param([switch]$NoPrompt)
    Write-Banner
    Write-Host '  Apply censorship pack' -ForegroundColor Magenta
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) { Write-Err 'Set PAZ first.'; if (-not $NoPrompt) { Pause-Any }; return $false }
    $tier = [string]$Script:Config.censorshipTier
    if (-not $tier -or $tier -eq 'off') { Write-Warn 'Tier is off.'; if (-not $NoPrompt) { Pause-Any }; return $false }
    if (-not (Test-Path $Script:CensorshipRoot)) { Write-Err "Missing $($Script:CensorshipRoot)"; if (-not $NoPrompt) { Pause-Any }; return $false }
    if (-not (Ensure-Python)) { if (-not $NoPrompt) { Pause-Any }; return $false }
    $out = Join-Path $Script:Config.pazFolder ("files_to_patch\_censorship_" + $tier)
    Write-Info ("tier=$tier out=$out")
    if (-not $NoPrompt -and -not (Read-YesNo 'Copy / expand texture pack?' $true)) { Pause-Any; return $false }
    $pyArgs = @(
        $Script:CensorshipTool, '--tier', $tier,
        '--pack-root', $Script:CensorshipRoot, '--out', $out,
        '--paz', [string]$Script:Config.pazFolder
    )
    if ($tier -eq 'expanded') {
        Write-Warn 'Expanded scans full meta (can take a minute)...'
    }
    & $Script:PythonExe @pyArgs
    $ok = -not ($LASTEXITCODE -and $LASTEXITCODE -ne 0)
    if ($ok) { Write-Ok 'Censorship pack ready. Meta Inject after Midnight.'; Ensure-ToolsInPaz } else { Write-Err "Exit $LASTEXITCODE" }
    if (-not $NoPrompt) { Pause-Any }
    return $ok
}

function Read-PenisStyle([string]$label, [string]$current) {
    Write-Host ''
    Write-Host ("  " + $label + " penis style  (current: " + $current + ")") -ForegroundColor White
    Write-Host '    [0] none   [1] normal   [2] hard' -ForegroundColor Cyan
    $c = Read-Choice 'Style' @('0', '1', '2')
    return $(switch ($c) { '0' { 'none' } '1' { 'normal' } '2' { 'hard' } })
}

# The [F] NEW FEMALES hub was removed in 2.1.1. Every class it targeted now has
# no supported genital path: a genital PAC carries the donor's body and skin, so
# reusing one gave those classes the wrong body. Pubic hair for them is handled
# by the normal per-class menu (shared-texture group, one style).

function Configure-GenitalMenus {
    Write-Banner
    Write-Host '  PENIS / 3D VAGINA' -ForegroundColor Magenta
    Write-Host '  ================' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Authored meshes only — the classes that shipped a real Resorepless mesh.' -ForegroundColor Green
    Write-Host '  Newer classes are not offered: a genital PAC carries the donor body AND' -ForegroundColor DarkGray
    Write-Host '  skin, so reusing one gave them the wrong body. Removed in 2.1.1.' -ForegroundColor DarkGray
    Write-Warn 'Penis skin tone often mismatches. Shai never included.'
    Write-Host ''
    Write-Host '  --- FEMALE 3D vagina ---' -ForegroundColor Green
    $Script:Config.female3dVagina = Read-YesNo 'Enable female 3D vagina packs?' ([bool]$Script:Config.female3dVagina)
    if ([bool]$Script:Config.female3dVagina) {
        Write-Host ''
        Write-Host '  Only these 10 classes have an authored 3D-vagina mesh:' -ForegroundColor Gray
        Write-Host ('    ' + (($Script:GenitalFemalePrefixes | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', ')) -ForegroundColor DarkGray
        Write-Host '  Newer classes are not offered: a genital PAC carries the donor body' -ForegroundColor DarkGray
        Write-Host '  AND skin, so reusing one gave them the wrong body. Removed in 2.1.1.' -ForegroundColor DarkGray
        $Script:Config.genitalFemaleClasses = Select-FemaleClasses -Title '3D vagina — which females?' -CurrentCsv ([string]$Script:Config.genitalFemaleClasses) -DefaultAll
        $asked = @(([string]$Script:Config.genitalFemaleClasses) -split '[,;]+' | Where-Object { $_ })
        $unsupported = @($asked | Where-Object { $_ -notin $Script:GenitalFemalePrefixes })
        if ($unsupported.Count -gt 0) {
            Write-Warn ('No authored mesh, skipped: ' + (($unsupported | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', '))
            $Script:Config.genitalFemaleClasses = (@($asked | Where-Object { $_ -in $Script:GenitalFemalePrefixes }) -join ',')
        }
        $Script:Config.genitalReuse = $false
    } else {
        $Script:Config.genitalFemaleClasses = ''
        $Script:Config.genitalReuse = $false
    }

    Write-Host ''
    Write-Host '  MALE — native penis meshes only (Warrior/Berserker/Musa/Wizard/Ninja/Striker)' -ForegroundColor White
    Write-Host '    [1] All native males same style' -ForegroundColor Green
    Write-Host '    [2] Per-class styles (those 6 only)' -ForegroundColor Cyan
    Write-Host '    [3] All off' -ForegroundColor DarkGray
    $m = Read-Choice 'Male mode' @('1', '2', '3')
    if ($m -eq '3') {
        $Script:Config.malePenisMode = 'none'
        foreach ($k in @('penisWarrior', 'penisBerserker', 'penisMusa', 'penisWizard', 'penisNinja', 'penisStriker')) {
            $Script:Config.$k = 'none'
        }
    } elseif ($m -eq '1') {
        $all = Read-PenisStyle 'All native males' $(if ($Script:Config.malePenisMode -in @('normal', 'hard')) { $Script:Config.malePenisMode } else { 'normal' })
        $Script:Config.malePenisMode = $all
        foreach ($k in @('penisWarrior', 'penisBerserker', 'penisMusa', 'penisWizard', 'penisNinja', 'penisStriker')) {
            $Script:Config.$k = $all
        }
    } else {
        $Script:Config.malePenisMode = 'perclass'
        $Script:Config.penisWarrior = Read-PenisStyle 'Warrior' ([string]$Script:Config.penisWarrior)
        $Script:Config.penisBerserker = Read-PenisStyle 'Berserker' ([string]$Script:Config.penisBerserker)
        $Script:Config.penisMusa = Read-PenisStyle 'Musa' ([string]$Script:Config.penisMusa)
        $Script:Config.penisWizard = Read-PenisStyle 'Wizard' ([string]$Script:Config.penisWizard)
        $Script:Config.penisNinja = Read-PenisStyle 'Ninja' ([string]$Script:Config.penisNinja)
        $Script:Config.penisStriker = Read-PenisStyle 'Striker' ([string]$Script:Config.penisStriker)
    }

    Save-Config
    Write-Ok 'Genital options saved.'
    Write-Host ("  female3dVagina         = " + $Script:Config.female3dVagina) -ForegroundColor Gray
    Write-Host ("  female classes        = " + (Format-ClassList $Script:Config.genitalFemaleClasses)) -ForegroundColor Gray
    Write-Host ("  malePenisMode         = " + $Script:Config.malePenisMode) -ForegroundColor Gray
    if (Read-YesNo 'Apply genital packs to files_to_patch now?' $true) {
        Apply-GenitalPacks
    } else {
        Pause-Any
    }
}

function Apply-GenitalPacks {
    Write-Banner
    Write-Host '  Apply genital packs' -ForegroundColor Magenta
    Write-Host '  Authored meshes only; classes without one are skipped with a reason' -ForegroundColor DarkGray
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) { Write-Err 'Set PAZ first.'; Pause-Any; return }
    if (-not (Test-Path $Script:GenitalRoot)) { Write-Err "Missing $($Script:GenitalRoot)"; Pause-Any; return }
    if (-not (Ensure-Python)) { Pause-Any; return }

    $f3d = if ([bool]$Script:Config.female3dVagina) { 'on' } else { 'off' }
    $maleArg = 'none'
    if ([string]$Script:Config.malePenisMode -eq 'perclass') {
        $parts = @(
            "warrior=$($Script:Config.penisWarrior)",
            "berserker=$($Script:Config.penisBerserker)",
            "musa=$($Script:Config.penisMusa)",
            "wizard=$($Script:Config.penisWizard)",
            "ninja=$($Script:Config.penisNinja)",
            "striker=$($Script:Config.penisStriker)"
        )
        $maleArg = $parts -join ','
    } elseif ([string]$Script:Config.malePenisMode -in @('normal', 'hard')) {
        $maleArg = [string]$Script:Config.malePenisMode
    }

    if ($f3d -eq 'off' -and $maleArg -eq 'none') {
        Write-Warn 'Nothing enabled.'
        Pause-Any
        return
    }

    $out = Join-Path $Script:Config.pazFolder 'files_to_patch\_genital_RESTORED_native'
    Write-Info ("female_3d=$f3d male=$maleArg")
    Write-Info 'mode=NATIVE only (authored meshes; classes without one are skipped)'
    Write-Info ("out=$out")
    if (-not (Read-YesNo 'Copy genital packs?' $true)) { Pause-Any; return }

    $fClasses = [string]$Script:Config.genitalFemaleClasses
    $pyArgs = @(
        $Script:GenitalTool,
        '--pack-root', $Script:GenitalRoot,
        '--out', $out,
        '--paz', [string]$Script:Config.pazFolder,
        '--female-3d-vagina', $f3d,
        '--male-penis', $maleArg
    )
    if ($fClasses) { $pyArgs += @('--female-classes', $fClasses) }

    Write-Info ("female classes = " + (Format-ClassList $fClasses))
    & $Script:PythonExe @pyArgs
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Write-Err "Exit $LASTEXITCODE" } else {
        Write-Ok 'Genital packs written. Deploy Midnight underwear hide too, then Meta Inject + PartCutGen.'
        Ensure-ToolsInPaz
    }
    Pause-Any
}

function Configure-SlotHide {
    Write-Banner
    Write-Host '  SLOT HIDE TOGGLES (extra dummy-mesh hides)' -ForegroundColor White
    Write-Host '  ------------------------------------------' -ForegroundColor DarkGray
    Write-Info 'Independent of Midnight All/Pearl/Free. Hides matching .pac models from live PAZ.'
    Write-Info 'Uses gender filter from your Midnight gender setting (F/M/B).'
    Write-Host ''
    Write-Host ("  Current: gloves={0} boots={1} helmets={2} weapons={3} stockings={4}" -f `
        $Script:Config.hideGloves, $Script:Config.hideBoots, $Script:Config.hideHelmets, $Script:Config.hideWeapons, $Script:Config.hideStockings) -ForegroundColor DarkCyan
    Write-Host ("  Classes : " + $(if ([string]$Script:Config.slotHideClasses) { $Script:Config.slotHideClasses } else { 'ALL' })) -ForegroundColor DarkCyan
    Write-Host ''
    $Script:Config.hideGloves = Read-YesNo 'Hide GLOVES / hands gear?' ([bool]$Script:Config.hideGloves)
    $Script:Config.hideBoots = Read-YesNo 'Hide BOOTS / shoes?' ([bool]$Script:Config.hideBoots)
    $Script:Config.hideHelmets = Read-YesNo 'Hide HELMETS (may affect some hair/hel combos)?' ([bool]$Script:Config.hideHelmets)
    $Script:Config.hideWeapons = Read-YesNo 'Hide WEAPONS (main/sub/awakening meshes)?' ([bool]$Script:Config.hideWeapons)
    $Script:Config.hideStockings = Read-YesNo 'Hide STOCKINGS (best-effort name match)?' ([bool]$Script:Config.hideStockings)
    Write-Host ''
    Write-Host '  Optional PER-CLASS filter (leave empty = all classes):' -ForegroundColor Yellow
    Write-Host '  Examples: pdkl          (Seraph only)' -ForegroundColor DarkGray
    Write-Host '            phw,pew,pdw   (Sorceress, Ranger, Dark Knight)' -ForegroundColor DarkGray
    Write-Host '            phm,pcm       (Warrior, Striker weapons only if weapons on)' -ForegroundColor DarkGray
    $cls = Read-Host '  Class prefixes (comma-separated, blank=ALL)'
    if ($null -eq $cls) { $cls = '' }
    $Script:Config.slotHideClasses = $cls.Trim()
    Save-Config
    Write-Ok 'Slot hide flags saved.'
    if (Read-YesNo 'Apply slot hide patch now (scans live PAZ)?' $true) {
        Apply-SlotHidePatch
    } else {
        Pause-Any
    }
}

function Get-EnabledHideSlots {
    $slots = @()
    if ([bool]$Script:Config.hideGloves) { $slots += 'gloves' }
    if ([bool]$Script:Config.hideBoots) { $slots += 'boots' }
    if ([bool]$Script:Config.hideHelmets) { $slots += 'helmets' }
    if ([bool]$Script:Config.hideWeapons) { $slots += 'weapons' }
    if ([bool]$Script:Config.hideStockings) { $slots += 'stockings' }
    return $slots
}

function Apply-SlotHidePatch {
    param([switch]$NoPrompt)
    Write-Banner
    Write-Host '  Apply slot hide patch' -ForegroundColor White
    Write-Host '  ---------------------' -ForegroundColor DarkGray
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ first (menu 1).'
        if (-not $NoPrompt) { Pause-Any }
        return $false
    }
    $slots = @(Get-EnabledHideSlots)
    if ($slots.Count -eq 0) {
        Write-Warn 'No slots enabled. Turn some on in menu 2 option 4 first.'
        if (-not $NoPrompt) { Pause-Any }
        return $false
    }
    if (-not (Test-Path -LiteralPath $Script:SlotHideTool)) {
        Write-Err ("Missing " + $Script:SlotHideTool)
        if (-not $NoPrompt) { Pause-Any }
        return $false
    }
    if (-not (Ensure-Python)) { if (-not $NoPrompt) { Pause-Any }; return $false }

    $gender = [string]$Script:Config.gender
    if ($gender -notin @('F', 'M', 'B')) { $gender = 'B' }
    $out = Join-Path $Script:Config.pazFolder 'files_to_patch'
    $cls = [string]$Script:Config.slotHideClasses
    Write-Info ("Slots  : " + ($slots -join ', '))
    Write-Info ("Gender : " + $gender)
    Write-Info ("Classes: " + $(if ($cls) { $cls } else { 'ALL' }))
    Write-Info ("Output : " + $out)
    Write-Warn 'Scans full meta (can take a minute). Then run PartCutGen + Meta Injector.'
    if (-not $NoPrompt -and -not (Read-YesNo 'Run slot hide patcher?' $true)) { Pause-Any; return $false }

    $pyArgs = @(
        $Script:SlotHideTool,
        '--paz', [string]$Script:Config.pazFolder,
        '--out', $out,
        '--slots', ($slots -join ','),
        '--gender', $gender
    )
    if ($cls) { $pyArgs += @('--classes', $cls) }
    $ok = $false
    try {
        & $Script:PythonExe @pyArgs
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Err ("Exit code " + $LASTEXITCODE)
        } else {
            Write-Ok 'Slot hide folders written under files_to_patch\_slot_hide_*'
            Ensure-ToolsInPaz
            $ok = $true
        }
    } catch {
        Write-Err $_.Exception.Message
    }
    if (-not $NoPrompt) { Pause-Any }
    return $ok
}

function Configure-PubicHair {
    Write-Banner
    Write-Host '  PUBIC HAIR' -ForegroundColor Magenta
    Write-Host '  ==========' -ForegroundColor DarkGray
    Write-Host '  Texture-only. A class is styled on its own when it owns its body texture;' -ForegroundColor Green
    Write-Host '  the 13 classes sharing one texture can only share a single style.' -ForegroundColor DarkGray
    Write-Host ''
    if (-not (Test-Path -LiteralPath (Join-Path $Script:PubicHairRoot 'offsets.bin'))) {
        Write-Err ("Pubic hair pack missing: " + $Script:PubicHairRoot)
        Write-Info 'Expected tools\pubic_hair\ from Resorepless resources.'
        Pause-Any
        return
    }

    Write-Host '  Pick the classes you want, then a style for each one.' -ForegroundColor Gray
    Write-Host '  Classes you do not pick are left completely untouched.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '    [I] IMMERSIVE preset (recommended) — a different look per class' -ForegroundColor Green
    Write-Host '    [C] Choose classes and styles yourself' -ForegroundColor Cyan
    Write-Host '    [P] Open preview image first' -ForegroundColor Yellow
    Write-Host '    [X] Clear pubic hair selection' -ForegroundColor DarkGray
    $mode = (Read-Host '  Choice').Trim().ToUpperInvariant()
    if ($mode -eq 'I') {
        Write-Host ''
        Write-Host '  IMMERSIVE preset' -ForegroundColor Green
        Write-Host '  ----------------' -ForegroundColor DarkGray
        Write-Host '  Individually styled (these classes own their body texture):' -ForegroundColor Gray
        $picked = [ordered]@{}
        foreach ($p in $Script:PubicImmersivePreset.Keys) {
            $picked[$p] = $Script:PubicImmersivePreset[$p]
            $label = if ($Script:FemaleClasses.Contains($p)) { $Script:FemaleClasses[$p] } else { $p }
            Write-Host ("    {0,-20} {1}" -f $label, $Script:PubicHairStyles[$Script:PubicImmersivePreset[$p]]) -ForegroundColor Gray
        }
        Show-PubicIsolationNotice $picked
        Write-Host ''
        Write-Host '  The other 13 classes all render from ONE shared texture:' -ForegroundColor Yellow
        Write-Host ('    ' + (($Script:SharedAtlasPrefixes | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', ')) -ForegroundColor DarkGray
        Write-Host '  They can only have ONE style between them, or stay bare.' -ForegroundColor DarkGray
        Write-Host ''
        if (Read-YesNo 'Give that whole group of 13 a style too?' $false) {
            $styleKeys = @($Script:PubicHairStyles.Keys | Where-Object { $_ -ne 'none' })
            for ($i = 0; $i -lt $styleKeys.Count; $i++) {
                Write-Host ("    [{0}] {1}" -f ($i + 1), $Script:PubicHairStyles[$styleKeys[$i]]) -ForegroundColor Cyan
            }
            while ($true) {
                $ans = (Read-Host '  Style number for all 13').Trim()
                if ($ans -notmatch '^\d+$') { Write-Warn 'Enter a number.'; continue }
                $n = [int]$ans
                if ($n -lt 1 -or $n -gt $styleKeys.Count) { Write-Warn 'Out of range.'; continue }
                foreach ($p in $Script:SharedAtlasPrefixes) { $picked[$p] = $styleKeys[$n - 1] }
                break
            }
        } else {
            Write-Info 'Those 13 stay bare (not touched at all).'
        }
        Write-Host ''
        if (-not (Read-YesNo 'Use this preset?' $true)) { Pause-Any; return }
        $Script:Config.pubicHairStyles = (($picked.Keys |
            ForEach-Object { '{0}={1}' -f $_, $picked[$_] }) -join ',')
        $Script:Config.pubicHairClasses = ($picked.Keys -join ',')
        $Script:Config.pubicHairStyle = @($picked.Values)[0]
        Save-Config
        Write-Ok 'Immersive preset saved.'
        if (Read-YesNo 'Apply pubic hair textures now?' $true) { Apply-PubicHair } else { Pause-Any }
        return
    }
    if ($mode -eq 'P') {
        $prev = Join-Path $Script:PubicHairRoot 'preview.jpg'
        if (Test-Path $prev) { Start-Process $prev } else { Write-Warn 'preview.jpg missing' }
        Pause-Any
        Configure-PubicHair
        return
    }
    if ($mode -eq 'X') {
        $Script:Config.pubicHairStyles = ''
        $Script:Config.pubicHairStyle = 'none'
        $Script:Config.pubicHairClasses = ''
        Save-Config
        Write-Ok 'Pubic hair selection cleared.'
        Pause-Any
        return
    }
    if ($mode -ne 'C') {
        Write-Warn 'Cancelled.'
        Pause-Any
        return
    }

    $classes = Select-FemaleClasses -Title 'Pubic hair — pick classes' -CurrentCsv (Get-PubicClassCsv)
    if ([string]::IsNullOrWhiteSpace($classes)) {
        Write-Warn 'No classes selected — nothing will be generated.'
        $Script:Config.pubicHairStyles = ''
        $Script:Config.pubicHairStyle = 'none'
        $Script:Config.pubicHairClasses = ''
        Save-Config
        Pause-Any
        return
    }

    $existing = Get-PubicStyleMap
    $picked = [ordered]@{}
    $styleKeys = @($Script:PubicHairStyles.Keys | Where-Object { $_ -ne 'none' })
    $lastChoice = 0

    Write-Host ''
    Write-Host '  --- STYLE PER CLASS ---' -ForegroundColor White
    Write-Host '  Enter a style number for each class. Blank repeats your previous answer.' -ForegroundColor DarkGray
    Write-Host '  Enter 0 to skip that class entirely.' -ForegroundColor DarkGray
    Write-Host ''
    for ($i = 0; $i -lt $styleKeys.Count; $i++) {
        Write-Host ("    [{0}] {1}" -f ($i + 1), $Script:PubicHairStyles[$styleKeys[$i]]) -ForegroundColor Cyan
    }
    Write-Host ''

    foreach ($prefix in ($classes -split '[,;]+')) {
        $prefix = $prefix.Trim()
        if (-not $prefix) { continue }
        $label = if ($Script:FemaleClasses.Contains($prefix)) { $Script:FemaleClasses[$prefix] } else { $prefix }
        $default = $lastChoice
        if ($existing.Contains($prefix)) {
            $idx = [array]::IndexOf($styleKeys, $existing[$prefix])
            if ($idx -ge 0) { $default = $idx + 1 }
        }
        while ($true) {
            $hint = if ($default -gt 0) { " [$default]" } else { '' }
            $ans = (Read-Host ("  " + $label + " (" + $prefix + ")" + $hint)).Trim()
            if (-not $ans -and $default -gt 0) { $ans = "$default" }
            if ($ans -notmatch '^\d+$') { Write-Warn 'Enter a number.'; continue }
            $n = [int]$ans
            if ($n -eq 0) { break }
            if ($n -lt 1 -or $n -gt $styleKeys.Count) { Write-Warn 'Out of range.'; continue }
            $picked[$prefix] = $styleKeys[$n - 1]
            $lastChoice = $n
            break
        }
    }

    if ($picked.Count -eq 0) {
        Write-Warn 'Every class was skipped — nothing will be generated.'
        $Script:Config.pubicHairStyles = ''
        $Script:Config.pubicHairStyle = 'none'
        $Script:Config.pubicHairClasses = ''
        Save-Config
        Pause-Any
        return
    }

    $Script:Config.pubicHairStyles = (($picked.Keys | ForEach-Object { '{0}={1}' -f $_, $picked[$_] }) -join ',')
    # Kept in sync so older status screens and the run-all path stay meaningful.
    $Script:Config.pubicHairClasses = (($picked.Keys) -join ',')
    $Script:Config.pubicHairStyle = @($picked.Values)[0]
    Save-Config

    Write-Host ''
    Write-Ok 'Pubic hair selection saved:'
    foreach ($p in $picked.Keys) {
        $label = if ($Script:FemaleClasses.Contains($p)) { $Script:FemaleClasses[$p] } else { $p }
        Write-Host ("    {0,-14} {1}" -f $label, $Script:PubicHairStyles[$picked[$p]]) -ForegroundColor Gray
    }
    Show-PubicIsolationNotice $picked
    if (Read-YesNo 'Apply pubic hair textures now?' $true) {
        Apply-PubicHair
    } else {
        Pause-Any
    }
}

# Selected classes -> ordered map of prefix=style, from the saved config.
function Get-PubicStyleMap {
    $map = [ordered]@{}
    foreach ($token in ([string]$Script:Config.pubicHairStyles -split '[,;]+')) {
        $token = $token.Trim()
        if (-not $token) { continue }
        $bits = $token -split '=', 2
        if ($bits.Count -ne 2) { continue }
        $p = $bits[0].Trim().ToLowerInvariant()
        $s = $bits[1].Trim().ToLowerInvariant()
        if ($p -and $s -and $Script:PubicHairStyles.Contains($s)) { $map[$p] = $s }
    }
    return $map
}

function Get-PubicClassCsv {
    return ((Get-PubicStyleMap).Keys -join ',')
}

function Get-PubicStylesArg {
    $map = Get-PubicStyleMap
    if ($map.Count -eq 0) { return $null }
    return (($map.Keys | ForEach-Object { '{0}={1}' -f $_, $map[$_] }) -join ',')
}

# 13 of 19 female bodies render from ONE texture (phw_01_nude_0001). Tell the user
# what that costs before they generate, instead of surprising them with GB of files.
# Warns about selections the assets cannot satisfy, BEFORE anything is generated.
function Show-PubicIsolationNotice {
    param($Picked)
    # Corsair's texture is a size no shipped hair bin matches, so it cannot be
    # styled at all. Say so up front rather than letting it look like a failure.
    if ($Picked.Contains('pfw')) {
        Write-Host ''
        Write-Warn 'Corsair has no compatible hair bin in this pack and will be skipped.'
    }
    $shared = @($Picked.Keys | Where-Object { $_ -in $Script:SharedAtlasPrefixes })
    if ($shared.Count -eq 0) { return }

    $missing = @($Script:SharedAtlasPrefixes | Where-Object { -not $Picked.Contains($_) })
    $styles = @($shared | ForEach-Object { $Picked[$_] } | Select-Object -Unique)
    if ($missing.Count -eq 0 -and $styles.Count -eq 1) {
        Write-Host ''
        Write-Info ('All 13 shared-texture classes selected with one style — they will all get ' + $Script:PubicHairStyles[$styles[0]] + '.')
        return
    }
    Write-Host ''
    Write-Warn 'These picked classes all render from ONE shared body texture, so they'
    Write-Warn 'cannot have different styles and WILL BE SKIPPED:'
    Write-Host ('    ' + (($shared | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', ')) -ForegroundColor DarkGray
    if ($styles.Count -gt 1) {
        Write-Host ('    conflicting styles requested: ' + ($styles -join ', ')) -ForegroundColor DarkGray
    }
    if ($missing.Count -gt 0) {
        Write-Host ('    not selected, would also be changed: ' + (($missing | ForEach-Object { $Script:FemaleClasses[$_] }) -join ', ')) -ForegroundColor DarkGray
    }
    Write-Host '    To style them, pick ALL 13 with the SAME style.' -ForegroundColor DarkGray
}

function Apply-PubicHair {
    Write-Banner
    Write-Host '  Apply pubic hair' -ForegroundColor Magenta
    Write-Host '  Per-class styles; unselected classes are left untouched' -ForegroundColor DarkGray
    $stylesArg = Get-PubicStylesArg
    if (-not $stylesArg) {
        Write-Warn 'No classes selected — pick classes and styles first (menu 2 option 6).'
        Pause-Any
        return
    }
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ first.'
        Pause-Any
        return
    }
    if (-not (Ensure-Python)) { Pause-Any; return }

    $baseRoots = @(
        (Join-Path $Script:Root 'pack\midnight_xyzw\_00_suzu_nude'),
        (Join-Path $Script:Root 'pack\midnight_xyzw\_00_thegreatsage_nude')
    ) -join ';'
    # One package for the whole selection: a per-style folder would leave the
    # previous run's package behind and re-inject classes you just deselected.
    $out = Join-Path $Script:Config.pazFolder 'files_to_patch\_pubic_hair_perclass'
    Write-Info ("Selection : " + $stylesArg)
    Write-Info ("Out       : " + $out)
    if (-not (Read-YesNo 'Merge hair bins onto nude DDS and write files_to_patch?' $true)) {
        Pause-Any
        return
    }
    Remove-StalePubicPackages
    $pyArgs = @(
        $Script:PubicHairTool,
        '--hair-root', $Script:PubicHairRoot,
        '--base-roots', $baseRoots,
        '--out', $out,
        '--paz', [string]$Script:Config.pazFolder,
        '--styles', $stylesArg
    )
    try {
        & $Script:PythonExe @pyArgs
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Err ("Exit " + $LASTEXITCODE)
        } else {
            Write-Ok 'Pubic hair textures ready. Meta Inject after Midnight deploy (nude body first).'
            Ensure-ToolsInPaz
        }
    } catch {
        Write-Err $_.Exception.Message
    }
    Pause-Any
}

# Old builds wrote one package per style/mode, so switching style or narrowing the
# class list left the previous package in files_to_patch and it kept getting
# injected. That is the other half of "I picked two classes and got all of them".
function Remove-StalePubicPackages {
    $ftp = Join-Path $Script:Config.pazFolder 'files_to_patch'
    if (-not (Test-Path -LiteralPath $ftp)) { return }
    $stale = @(Get-ChildItem -LiteralPath $ftp -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '_pubic_hair_*' -and $_.Name -ne '_pubic_hair_perclass' })
    foreach ($dir in $stale) {
        try {
            Remove-Item -LiteralPath $dir.FullName -Recurse -Force -Confirm:$false
            Write-Info ("Removed stale pubic package: " + $dir.Name)
        } catch {
            Write-Warn ("Could not remove " + $dir.Name + ": " + $_.Exception.Message)
        }
    }
}

function Configure-MidnightChoices {
    Write-Banner
    Write-Host '  Midnight hide / nude options' -ForegroundColor White
    Write-Host '  ----------------------------' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  WHO should armor/underwear removal apply to?' -ForegroundColor White
    Write-Host '    [F] Female only     (most common)' -ForegroundColor Cyan
    Write-Host '    [M] Male only' -ForegroundColor Cyan
    Write-Host '    [B] Both genders' -ForegroundColor Cyan
    $Script:Config.gender = Read-Choice 'Gender letter' @('F', 'M', 'B')

    Write-Host ''
    Write-Host '  WHICH outfits should become transparent / stripped?' -ForegroundColor White
    Write-Host '    [A] All armors and outfits (includes gloves/boots/helmets/stockings)' -ForegroundColor Cyan
    Write-Host '    [P] Pearl Shop only' -ForegroundColor Cyan
    Write-Host '    [F] Free / non-cash only' -ForegroundColor Cyan
    Write-Host '    [U] Underwear hide only (keep armor meshes)' -ForegroundColor Cyan
    Write-Host ''
    Write-Info 'Nude base body (Suzu + TheGreatSage) is always included.'
    Write-Info 'Underwear removal for the gender you picked is always included.'
    $Script:Config.armor = Read-Choice 'Armor letter' @('A', 'P', 'F', 'U')

    Write-Host ''
    Write-Host '  EXTRA outfit packs (XYZW collections)?' -ForegroundColor White
    $Script:Config.xyzwCollections = Read-YesNo 'Include XYZW collection mods?' $true

    Save-Config
    Write-Ok 'Midnight choices saved.'
    Pause-Any
}

function Read-FloatValue {
    param(
        [string]$Prompt,
        [double]$Default,
        [double]$MinAllowed = -5.0,
        [double]$MaxAllowed = 10.0
    )
    while ($true) {
        Write-Host ''
        $raw = (Read-Host ("  " + $Prompt + " [default " + ("{0:0.##}" -f $Default) + "]")).Trim()
        if ([string]::IsNullOrEmpty($raw)) { return $Default }
        $raw = $raw.Replace(',', '.')
        $val = 0.0
        if (-not [double]::TryParse($raw, [ref]$val)) {
            Write-Warn 'Enter a number (example: 2.5 or 1.0)'
            continue
        }
        if ($val -lt $MinAllowed -or $val -gt $MaxAllowed) {
            Write-Warn ("Value out of safe range " + $MinAllowed + " .. " + $MaxAllowed + " (you can still type again)")
            if (-not (Read-YesNo ("Use " + $val + " anyway?") $false)) { continue }
        }
        return $val
    }
}

# The parts string is the single source of truth: "name:max" pairs, e.g.
# "breasts:2.0,thighs:1.5,butt:1.25". Returns $null when it is unusable.
function Get-BodySizeSpec {
    $raw = [string]$Script:Config.bodySizeParts
    if (-not $raw) { return $null }
    $out = [ordered]@{}
    foreach ($token in ($raw -split '[,;]+')) {
        $token = $token.Trim()
        if (-not $token) { continue }
        $bits = $token -split ':', 2
        $name = $bits[0].Trim().ToLowerInvariant()
        if ($name -in @('pelvis', 'ass', 'hips', 'hip')) { $name = 'butt' }
        if ($name -notin $Script:BodySizeParts) { continue }
        $max = $null
        if ($bits.Count -eq 2) { [void][double]::TryParse($bits[1].Trim(), [ref]$max) }
        if ($null -eq $max -or $max -lt 1.0 -or $max -gt 99.0) { continue }
        if ($out.Contains($name)) {
            if ($max -gt $out[$name]) { $out[$name] = $max }
        } else {
            $out[$name] = $max
        }
    }
    if ($out.Count -eq 0) { return $null }
    return $out
}

function Format-BodySizeSpec {
    param($Spec)
    if (-not $Spec) { return '(none)' }
    return (($Spec.Keys | ForEach-Object { '{0} max {1:0.##}' -f $_, $Spec[$_] }) -join ', ')
}

function Get-BodySizeArg {
    $spec = Get-BodySizeSpec
    if (-not $spec) { return $null }
    return (($spec.Keys | ForEach-Object { '{0}:{1}' -f $_, $spec[$_] }) -join ',')
}

function Configure-BodySizeLimits {
    Write-Banner
    Write-Host '  BODY SIZE LIMITS  [RESTORED — all classes via live PAZ]' -ForegroundColor White
    Write-Host '  -----------------------------------------------------' -ForegroundColor DarkGray
    Write-Info 'Patches ALL customizationboneparamdesc files in the live game (every class).'
    Write-Info 'Raises only the Max (slider ceiling). Default and Min are left alone.'
    Write-Warn 'After inject: beauty salon or new character. Tamer breasts often ignore this.'
    Write-Host ''
    Write-Host '  WHAT THE NUMBERS MEAN (read this — easy to confuse)' -ForegroundColor White
    Write-Host '  Each body bone has three scale values in the game files:' -ForegroundColor Gray
    Write-Host '    Min     = lowest the slider can go  (vanilla often ~0.70-0.90)' -ForegroundColor DarkGray
    Write-Host '    Default = neutral body             (vanilla almost always 1.00)' -ForegroundColor DarkGray
    Write-Host '    Max     = highest the slider can go (the ceiling — THIS is what we patch)' -ForegroundColor DarkGray
    Write-Host '  Preset numbers below are Max ceilings only. They do NOT force your body' -ForegroundColor Gray
    Write-Host '  to that size. You still set size in character creation / beauty salon.' -ForegroundColor Gray
    Write-Host '  Caps are client-side (your machine only).' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  VANILLA MAX CEILINGS (restored live client scan, all classes)' -ForegroundColor White
    Write-Host '    Breasts  typical Max ~1.25 (majority). Some classes already higher on Y/Z.' -ForegroundColor Cyan
    Write-Host '    Thighs   typical peak Max ~1.10-1.15 (varies; some already ~1.35 girth).' -ForegroundColor Cyan
    Write-Host '    Hips     typical Max ~1.00 or 1.10 (many classes lock hip at 1.00).' -ForegroundColor Cyan
    Write-Host '    Pelvis   typical peak Max ~1.20 (part of "butt" with hips in this AIO).' -ForegroundColor Cyan
    Write-Host '    So recommended butt 1.18 is ABOVE stock hip max (1.00/1.10), not below.' -ForegroundColor Green
    Write-Host ''
    Write-Host '  Only three groups: breasts / thighs / butt (hip + pelvis).' -ForegroundColor Gray
    Write-Host '  legs/spine/arms removed in 2.1.0 (those scale bone LENGTH).' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  RECOMMENDED NO-CLIP UNLOCK (measured in-game)' -ForegroundColor White
    Write-Host '    Breasts  1.37  zero outfit clip' -ForegroundColor Green
    Write-Host '    Thighs   1.30  no thigh-on-thigh overlap' -ForegroundColor Green
    Write-Host '    Butt     1.18  good unlock; much above this lower cheek can pyramid' -ForegroundColor Green
    Write-Host ''
    Write-Host ("  Current preset Max: " + (Format-BodySizeSpec (Get-BodySizeSpec))) -ForegroundColor DarkCyan
    Write-Host ''

    Write-Host '  PRESETS  (breasts / thighs / butt = Max ceilings — NOT all the same number)' -ForegroundColor White
    Write-Host '    [1] vanilla       1.25 / 1.15 / 1.10   ~stock Max per part (breasts/thighs/hips)' -ForegroundColor Cyan
    Write-Host '                      (NOT 1.25 for everything — stock hips are usually 1.00-1.10)' -ForegroundColor DarkGray
    Write-Host '    [2] recommended   1.37 / 1.30 / 1.18   NO CLIP unlock  << default' -ForegroundColor Green
    Write-Host '    [3] high          1.65 / 1.40 / 1.19' -ForegroundColor Yellow
    Write-Host '                      BREASTS may clip outfits (pick clothes that wont).' -ForegroundColor Red
    Write-Host '                      Thighs may start to collide/overlap each other.' -ForegroundColor Yellow
    Write-Host '    [4] extreme       2.00 / 1.45 / 1.20' -ForegroundColor Yellow
    Write-Host '                      BREASTS will clip many outfits (pick clothes that wont).' -ForegroundColor Red
    Write-Host '                      Thighs more likely to collide/overlap.' -ForegroundColor Yellow
    Write-Host '                      Butt Max 1.20 — lower cheek can pyramid-spike (mesh trash).' -ForegroundColor Red
    Write-Host '    [5] CUSTOM        type each Max yourself' -ForegroundColor Magenta
    Write-Host '    [6] Keep current' -ForegroundColor DarkGray
    $p = Read-Choice 'Choice' @('1', '2', '3', '4', '5', '6')

    switch ($p) {
        '1' { $Script:Config.bodySizePreset = 'vanilla';     $Script:Config.bodySizeParts = $Script:BodySizePresets['vanilla'].Spec }
        '2' { $Script:Config.bodySizePreset = 'recommended'; $Script:Config.bodySizeParts = $Script:BodySizePresets['recommended'].Spec }
        '3' {
            $Script:Config.bodySizePreset = 'high'
            $Script:Config.bodySizeParts = $Script:BodySizePresets['high'].Spec
            Write-Host ''
            Write-Host '  HIGH tradeoffs (client-side only):' -ForegroundColor Yellow
            Write-Host '    BREASTS  may clip outfits — choose outfits that will not clip.' -ForegroundColor Red
            Write-Host '    THIGHS   may collide / overlap each other.' -ForegroundColor Yellow
            Write-Host '    BUTT     1.19 is still mild; pyramid risk grows as you go higher.' -ForegroundColor DarkGray
        }
        '4' {
            $Script:Config.bodySizePreset = 'extreme'
            $Script:Config.bodySizeParts = $Script:BodySizePresets['extreme'].Spec
            Write-Host ''
            Write-Host '  EXTREME tradeoffs (client-side only):' -ForegroundColor Yellow
            Write-Host '    BREASTS  will clip many outfits — choose outfits that will not clip.' -ForegroundColor Red
            Write-Host '    THIGHS   more likely to collide / overlap each other.' -ForegroundColor Yellow
            Write-Host '    BUTT     1.20 — lower cheek mesh can pyramid-spike (looks broken).' -ForegroundColor Red
        }
        '5' {
            Write-Host ''
            Write-Host '  CUSTOM (you are typing Max ceilings, not body size)' -ForegroundColor Magenta
            Write-Info 'Answer y/n per part, then give that part its Max. Parts you skip are'
            Write-Info 'not written at all, so they keep exactly the values the game shipped.'
            Write-Host ''
            Write-Host '  Vanilla Max reminder: breasts~1.25  thighs~1.10-1.15  hips~1.00-1.10' -ForegroundColor Cyan
            Write-Host '  Recommended no-clip:  1.37 / 1.30 / 1.18' -ForegroundColor Green
            Write-Host '  Tradeoffs if you go higher:' -ForegroundColor Yellow
            Write-Host '    Breasts -> outfit clipping (pick clothes that wont clip)' -ForegroundColor Red
            Write-Host '    Thighs  -> thighs collide / overlap each other' -ForegroundColor Yellow
            Write-Host '    Butt    -> lower cheek pyramid polygon spike (mesh trash)' -ForegroundColor Red
            Write-Host ''
            $base = Get-BodySizeSpec
            $chosen = [ordered]@{}
            $labels = @{
                breasts = 'Breasts Max  (vanilla~1.25 | no-clip 1.37 | high 1.65 | extreme 2.00) — high = outfit clip'
                thighs  = 'Thighs Max   (vanilla~1.10-1.15 | no-clip 1.30 | high 1.40 | extreme 1.45) — high = collide'
                butt    = 'Butt Max     (vanilla hips~1.00-1.10 | no-clip 1.18 | high 1.19 | extreme 1.20) — high = pyramid'
            }
            $suggest = @{ breasts = 1.37; thighs = 1.30; butt = 1.18 }
            foreach ($part in $Script:BodySizeParts) {
                Write-Host ('    ' + $labels[$part]) -ForegroundColor DarkGray
                if (Read-YesNo ("Patch " + $part + "?") $true) {
                    $default = $suggest[$part]
                    if ($base -and $base.Contains($part)) { $default = $base[$part] }
                    $val = Read-FloatValue -Prompt ("  " + $part + " Max ceiling") -Default $default -MinAllowed 1.0 -MaxAllowed 5.0
                    if ($part -eq 'butt' -and $val -gt 1.20) {
                        Write-Host '  Butt Max > 1.20 often pyramid-spikes the lower cheek mesh.' -ForegroundColor Red
                        if (-not (Read-YesNo 'Keep this butt Max anyway?' $false)) {
                            $val = 1.18
                            Write-Info 'Clamped butt Max to 1.18 (recommended).'
                        }
                    }
                    $chosen[$part] = $val
                }
                Write-Host ''
            }
            if ($chosen.Count -eq 0) {
                Write-Err 'Nothing selected — keeping your previous settings.'
            } else {
                $Script:Config.bodySizePreset = 'custom'
                $Script:Config.bodySizeParts = (($chosen.Keys | ForEach-Object { '{0}:{1}' -f $_, $chosen[$_] }) -join ',')
                Write-Ok ('Custom saved: ' + (Format-BodySizeSpec $chosen))
            }
        }
        '6' { Write-Info 'Keeping existing settings.' }
    }

    Save-Config
    Write-Host ''
    Write-Ok 'Body size settings saved.'
    Write-Host ("  Preset : " + $Script:Config.bodySizePreset) -ForegroundColor Gray
    Write-Host ("  Applies: " + (Format-BodySizeSpec (Get-BodySizeSpec))) -ForegroundColor Gray
    Write-Host '  Untouched: game Default, every bone-length axis, and every part above' -ForegroundColor DarkGray
    Write-Host '             that you did not pick.' -ForegroundColor DarkGray
    Write-Host ''
    if (Read-YesNo 'Apply body size patch to game files_to_patch now?' $true) {
        Apply-BodySizePatch
    } else {
        Pause-Any
    }
}

function Apply-BodySizePatch {
    Write-Banner
    Write-Host '  Apply body size limit patch' -ForegroundColor White
    Write-Host '  ---------------------------' -ForegroundColor DarkGray

    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set game PAZ first (menu 1).'
        Pause-Any
        return
    }
    if (-not (Test-Path -LiteralPath $Script:BodySizeTool)) {
        Write-Err ("Missing tool: " + $Script:BodySizeTool)
        Pause-Any
        return
    }
    if (-not (Ensure-Python)) {
        Pause-Any
        return
    }

    $parts = Get-BodySizeArg
    if (-not $parts) {
        Write-Err 'No usable body parts configured. Re-run menu 2 body size config.'
        Pause-Any
        return
    }
    $out = Join-Path $Script:Config.pazFolder 'files_to_patch\_body_size_limits'

    Write-Info ("PAZ     : " + $Script:Config.pazFolder)
    Write-Info ("Preset  : " + $Script:Config.bodySizePreset)
    Write-Info ("Applies : " + (Format-BodySizeSpec (Get-BodySizeSpec)))
    Write-Info ("Output  : " + $out)
    Write-Warn 'Extracts ~75 customizationboneparamdesc.xml from live game (takes a minute).'
    if (-not (Read-YesNo 'Run body size patcher with these values?' $true)) {
        Pause-Any
        return
    }

    # The parts string carries each part's own max, so this is the only knob.
    $pyArgs = @(
        $Script:BodySizeTool,
        '--paz', [string]$Script:Config.pazFolder,
        '--out', $out,
        '--parts', $parts
    )
    try {
        & $Script:PythonExe @pyArgs
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Err ("Patcher exit code " + $LASTEXITCODE)
        } else {
            Write-Ok 'Body size files written under files_to_patch\_body_size_limits'
            Write-Info 'Next: Meta Injector, then beauty salon or new character to use the new max.'
            Ensure-ToolsInPaz
        }
    } catch {
        Write-Err $_.Exception.Message
    }
    Pause-Any
}

function Show-OptionsMatrix {
    Write-Banner
    Write-Host '  FEATURE ORIGIN MATRIX' -ForegroundColor White
    Write-Host '  =====================' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  MODERN (Midnight / recommended pipeline)' -ForegroundColor Cyan
    Write-Host '  ---------------------------------------' -ForegroundColor DarkGray
    Write-Host '  Gender F/M/Both; armor All/Pearl/Free/Underwear-only'
    Write-Host '  Nude body through Seraph; live-regenerated armor/underwear hide includes Wukong (not Shai)'
    Write-Host '  XYZW collections; PartCutGen + Meta Injector'
    Write-Host '  GameOption profiles [G]; NVIDIA .nip [N]'
    Write-Host ''
    Write-Host '  RESTORED (classic Resorepless-era, re-wired in this AIO)' -ForegroundColor Green
    Write-Host '  -------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  Body size min/default/max (presets + custom numbers)'
    Write-Host '  Slot hide: gloves / boots / helmets / weapons / stockings'
    Write-Host '  Pubic hair styles (old texture bins)'
    Write-Host '  Censorship tiers minimal/medium/high (old outfit textures)'
    Write-Host '  Penis none/normal/hard + 3D vagina (old class meshes)'
    Write-Host '  Old Resorepless UI omitted: its restored features are native AIO options'
    Write-Host ''
    Write-Host '  EXPERIMENTAL (from-scratch in BDO-AIO — NOT a classic restore)' -ForegroundColor Red
    Write-Host '  -------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  [X] OptiScaler / Streamline / DLSS-style inject  *** NOT SAFE ***'
    Write-Host '      Lives under experimental\dlss\ only. Separate from RESTORED packs.'
    Write-Host '      May be flagged by anti-cheat. Not from Resorepless/Midnight.'
    Write-Host ''
    Write-Host '  RESTORED but LIMITED on modern content' -ForegroundColor Yellow
    Write-Host '  --------------------------------------' -ForegroundColor DarkGray
    Write-Host '  Genital / pubic / censorship packs: best on older classes/outfits'
    Write-Host '  Penis skin-tone mismatch (classic issue)'
    Write-Host ''
    Write-Host '  Not supported on newer classes' -ForegroundColor Yellow
    Write-Host '  ------------------------------' -ForegroundColor DarkGray
    Write-Host '  Seraph / Deadeye / Woosa / Maegu / Scholar / Nova / Corsair /'
    Write-Host '  Drakania / Guardian have no authored genital mesh. Reusing another'
    Write-Host '  class''s gave them that class''s body AND skin, so it was removed in 2.1.1.'
    Write-Host ''
    Write-Host '  NOT SUPPORTED' -ForegroundColor DarkGray
    Write-Host '  -------------' -ForegroundColor DarkGray
    Write-Host '  Shai nude; anti-cheat stealth; inventing new high-quality body meshes'
    Write-Host '  Dosa/Wukong male genital donor reuse (no verified compatible mesh)'
    Write-Host ''
    Pause-Any
}

function Ensure-ToolsInPaz {
    $paz = [string]$Script:Config.pazFolder
    if (-not (Test-IsPazFolder $paz)) { return }

    foreach ($name in @('PartCutGen.exe', 'Meta Injector.exe')) {
        $dest = Join-Path $paz $name
        $src = Join-Path $Script:PackDir $name
        if (Test-Path -LiteralPath $dest) {
            Write-Ok ("Tool present in game PAZ: " + $name)
            continue
        }
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination $dest -Force
            Write-Ok ("Copied " + $name + " from pack into game PAZ")
        } else {
            Write-Warn ("Missing in pack: " + $src)
        }
    }
}

function Test-BdoToolkitInstalled {
    $gac = Join-Path $env:windir 'Microsoft.NET\assembly\GAC_MSIL\BDOToolkit\v4.0_1.3.0.0__e09839e68adb5566\BDOToolkit.dll'
    if (Test-Path -LiteralPath $gac) { return $true }
    $local = Join-Path ([string]$Script:Config.pazFolder) 'BDOToolkit.dll'
    return (Test-Path -LiteralPath $local)
}

function Deploy-Midnight {
    Write-Banner
    Write-Host '  Step 1 - Deploy mods to files_to_patch' -ForegroundColor White
    Write-Host '  --------------------------------------' -ForegroundColor DarkGray

    $pack = Test-PackReady
    if (-not $pack.Ok) {
        Write-Err 'Bundled pack is incomplete. Re-download the full AIO release zip.'
        foreach ($m in $pack.Missing) { Write-Warn ("  " + $m) }
        Pause-Any
        return $false
    }

    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set a valid game PAZ folder first (menu option 1).'
        Pause-Any
        return $false
    }
    if (-not (Ensure-Python)) {
        Pause-Any
        return $false
    }
    Show-DevModeHint
    Write-Host ''

    $pyScript = Join-Path $Script:PackDir 'midnight_xyzw\midnight_xyzw.py'
    $g = [string]$Script:Config.gender
    $a = [string]$Script:Config.armor
    $xyzwArg = if ([bool]$Script:Config.xyzwCollections) { '--xyzw' } else { '--no-xyzw' }

    Write-Info ("Pack     : " + $Script:PackDir)
    Write-Info ("Target   : " + $Script:Config.pazFolder)
    Write-Info ("Args     : -g " + $g + " -a " + $a + " " + $xyzwArg + " --yes")
    Write-Host ''
    if (-not (Read-YesNo 'Deploy now?' $true)) {
        Write-Warn 'Cancelled.'
        Pause-Any
        return $false
    }

    $pyArgs = @(
        '-x', $pyScript,
        '-g', $g,
        '-a', $a,
        $xyzwArg,
        '--yes',
        [string]$Script:Config.pazFolder
    )

    Write-Host ''
    Write-Info 'Running Midnight deploy (first run can take a while)...'
    try {
        & $Script:PythonExe @pyArgs
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Err ("Python exited with code " + $LASTEXITCODE)
            Pause-Any
            return $false
        }
    } catch {
        Write-Err $_.Exception.Message
        Pause-Any
        return $false
    }

    $ftp = Join-Path $Script:Config.pazFolder 'files_to_patch'
    if (Test-Path -LiteralPath $ftp) {
        Write-Ok ("Deployed. Folder ready: " + $ftp)
    } else {
        Write-Warn 'files_to_patch not found after deploy - check console output above.'
    }

    Ensure-ToolsInPaz
    Save-Config
    Pause-Any
    return $true
}

function Run-PartCutGen {
    Write-Banner
    Write-Host '  Step 2 - PartCutGen (REQUIRED since ~2024)' -ForegroundColor White
    Write-Host '  ------------------------------------------' -ForegroundColor DarkGray
    Write-Info 'Rebuilds part-cut exclusion so body/armor clipping is correct.'
    Write-Info 'Follow the on-screen instructions in the tool window.'
    Write-Host ''

    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ folder first.'
        Pause-Any
        return
    }
    Ensure-ToolsInPaz
    $exe = Join-Path $Script:Config.pazFolder 'PartCutGen.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Err ("Missing: " + $exe)
        Pause-Any
        return
    }
    Write-Info ("Launching: " + $exe)
    Start-Process -FilePath $exe -WorkingDirectory $Script:Config.pazFolder
    Write-Ok 'PartCutGen launched. Finish it, then run Meta Injector (menu 5).'
    Pause-Any
}

function Get-FreeBdoDriveLetter {
    foreach ($code in 90..68) {
        $drive = ([char]$code).ToString() + ':'
        if (-not (Test-Path -LiteralPath ($drive + '\'))) { return $drive }
    }
    throw 'No free temporary drive letter is available.'
}

function Mount-BdoTemporaryDrive {
    param([string]$Target)
    $drive = Get-FreeBdoDriveLetter
    & "$env:SystemRoot\System32\subst.exe" $drive $Target | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath ($drive + '\'))) {
        throw "Could not create temporary short-path drive $drive for $Target"
    }
    return $drive
}

function Dismount-BdoTemporaryDrive {
    param([string]$Drive)
    if ($Drive) { & "$env:SystemRoot\System32\subst.exe" $Drive /D 2>$null | Out-Null }
}

function Prepare-BdoInjectStage {
    param(
        [string]$PazDrive,
        [string]$SourceDrive
    )
    if (-not (Test-Path -LiteralPath $Script:InjectStageTool)) {
        throw "Missing canonical stage builder: $Script:InjectStageTool"
    }
    $stage = $PazDrive + '\BDO_AIO_INJECT'
    Write-Info 'Building canonical injection tree (all collections kept; organizer folders flattened)...'
    & $Script:PythonExe $Script:InjectStageTool `
        --paz ($PazDrive + '\') `
        --source ($SourceDrive + '\') `
        --stage $stage | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "Canonical injection stage failed with exit code $LASTEXITCODE. No injection was started."
    }
    return $stage
}

function Run-MetaInjector {
    Write-Banner
    Write-Host '  Step 3 - Meta Injector (applies the patch)' -ForegroundColor White
    Write-Host '  ------------------------------------------' -ForegroundColor DarkGray
    Write-Info 'Patches the game meta so files_to_patch are used in-game.'
    Write-Warn 'Close the BDO client and launcher before injecting.'
    Write-Host ''

    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ folder first.'
        Pause-Any
        return
    }
    if (-not (Ensure-Python)) {
        Pause-Any
        return
    }
    Ensure-ToolsInPaz
    $paz = [string]$Script:Config.pazFolder
    $source = Join-Path $paz 'files_to_patch'
    $exe = Join-Path $paz 'Meta Injector.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Err ("Missing: " + $exe)
        Pause-Any
        return
    }
    if (-not (Test-BdoToolkitInstalled)) {
        Write-Err 'Meta Injector 1.4.1 requires BDO Toolkit 1.3.0, but it was not found.'
        Write-Info 'Install the official BDO Toolkit package, then run this step again.'
        Write-Host '  https://www.undertow.club/downloads/meta-injector.4367/' -ForegroundColor Cyan
        Pause-Any
        return
    }
    if (-not (Test-Path -LiteralPath $source)) {
        Write-Err ("Missing: " + $source)
        Pause-Any
        return
    }
    # Snapshot a pristine meta before the very first inject. Once injected, the
    # only pre-inject copy left is Meta Injector's own backup, and losing it means
    # a full Steam/launcher repair.
    Write-Host ''
    Write-Info 'Checking for a vanilla meta backup...'
    [void](Invoke-VanillaRestoreTool @('backup'))

    Write-Host ''
    Write-Host '  If the game breaks, menu [R] -> [V] restores vanilla without Steam.' -ForegroundColor Yellow
    Write-Host '  The AIO passes a canonical short-path stage; no XYZW collection is deleted.' -ForegroundColor Green
    Write-Host ''
    $pazDrive = $null
    $sourceDrive = $null
    try {
        $pazDrive = Mount-BdoTemporaryDrive -Target $paz
        $sourceDrive = Mount-BdoTemporaryDrive -Target $source
        $stage = [string](Prepare-BdoInjectStage -PazDrive $pazDrive -SourceDrive $sourceDrive)
        $shortExe = $pazDrive + '\Meta Injector.exe'
        Write-Info ("Launching through short path: " + $shortExe)
        $process = Start-Process -FilePath $shortExe -WorkingDirectory ($pazDrive + '\') `
            -ArgumentList ('-files "{0}"' -f $stage) -PassThru -Wait
        Write-Ok ("Meta Injector closed (process exit code " + $process.ExitCode + ").")
        $region = Get-BdoClientRegion
        $metaPatcher = $pazDrive + '\Meta Patcher.exe'
        if ($region -in @('NA', 'EU')) {
            Write-Ok ("Meta Patcher skipped: the author's FAQ excludes NA/EU; detected " + $region + '.')
        } elseif ($region) {
            Write-Warn ("Client region detected: " + $region + '. The Meta Patcher FAQ says official regions other than NA/EU require it.')
            if (Test-Path -LiteralPath $metaPatcher) {
                if (Read-YesNo 'Run Meta Patcher now?' $true) {
                    $patcherProcess = Start-Process -FilePath $metaPatcher `
                        -WorkingDirectory ($pazDrive + '\') -PassThru -Wait
                    Write-Ok ("Meta Patcher closed (process exit code " + $patcherProcess.ExitCode + ").")
                }
            } else {
                Write-Warn 'Meta Patcher 1.1.0 is not installed.'
                Write-Host '  Official page: https://www.undertow.club/downloads/meta-patcher.7829/' -ForegroundColor Cyan
            }
        } else {
            Write-Warn 'Could not detect the client region from service.ini; Meta Patcher was not run automatically.'
            Write-Host '  Check the author FAQ before using it: https://www.undertow.club/downloads/meta-patcher.7829/field?field=FAQ' -ForegroundColor Cyan
        }
    } catch {
        Write-Err $_.Exception.Message
        Write-Warn 'No files were deleted. Fix the reported input and run Meta Injector again.'
    } finally {
        Dismount-BdoTemporaryDrive -Drive $sourceDrive
        Dismount-BdoTemporaryDrive -Drive $pazDrive
    }
    Pause-Any
}

function Apply-AllRestoredChoices {
    param([switch]$NoPrompt)
    Write-Banner
    Write-Host '  APPLY ALL RESTORED CHOICES' -ForegroundColor Green
    Write-Host '  ==========================' -ForegroundColor DarkGray
    Write-Info 'Runs enabled RESTORED options from config in order:'
    Write-Host '    body size -> slot hide -> pubic -> censorship -> genitals' -ForegroundColor Gray
    Write-Host ''
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ first (menu 1).'
        if (-not $NoPrompt) { Pause-Any }
        return $false
    }
    if (-not (Ensure-Python)) { if (-not $NoPrompt) { Pause-Any }; return $false }

    Write-Host '  From config:' -ForegroundColor White
    Write-Host ("    bodySizePreset = " + $Script:Config.bodySizePreset) -ForegroundColor Gray
    Write-Host ("    slots          = " + ((Get-EnabledHideSlots) -join ', ')) -ForegroundColor Gray
    Write-Host ("    slot classes   = " + $(if ($Script:Config.slotHideClasses) { $Script:Config.slotHideClasses } else { 'ALL' })) -ForegroundColor Gray
    Write-Host ("    pubic          = " + $(if (Get-PubicStylesArg) { Get-PubicStylesArg } else { 'none' })) -ForegroundColor Gray
    Write-Host ("    censorship     = " + $Script:Config.censorshipTier) -ForegroundColor Gray
    Write-Host ("    female3d       = " + $Script:Config.female3dVagina) -ForegroundColor Gray
    Write-Host ("    malePenisMode  = " + $Script:Config.malePenisMode) -ForegroundColor Gray
    Write-Host ''
    if (-not $NoPrompt -and -not (Read-YesNo 'Apply all enabled RESTORED packs now (no further prompts)?' $true)) {
        Pause-Any
        return $false
    }

    $paz = [string]$Script:Config.pazFolder
    $ftp = Join-Path $paz 'files_to_patch'
    if (-not (Test-Path $ftp)) { New-Item -ItemType Directory -Path $ftp -Force | Out-Null }
    $allOk = $true

    # 1) Body size — same single --parts argument as Apply-BodySizePatch
    if ($Script:Config.bodySizePreset -and $Script:Config.bodySizePreset -ne '') {
        Write-Info '--- Body size limits ---'
        $parts = Get-BodySizeArg
        if (-not $parts) {
            Write-Warn 'Body size config unusable — skipping body size.'
        } else {
            Write-Info ("Applies : " + (Format-BodySizeSpec (Get-BodySizeSpec)))
            $out = Join-Path $ftp '_body_size_limits'
            $pyArgs = @(
                $Script:BodySizeTool, '--paz', $paz, '--out', $out,
                '--parts', $parts
            )
            if (-not (Invoke-BdoPythonChecked -Arguments $pyArgs -Label 'Body size patcher')) { $allOk = $false }
        }
    }

    # 2) Slot hide
    $slots = @(Get-EnabledHideSlots)
    if ($slots.Count -gt 0) {
        Write-Info '--- Slot hide ---'
        if (-not (Apply-SlotHidePatch -NoPrompt)) { $allOk = $false }
    }

    # 3) Pubic hair — one package for the whole per-class selection
    $stylesArg = Get-PubicStylesArg
    if ($stylesArg) {
        Write-Info '--- Pubic hair ---'
        Write-Info ("  selection = " + $stylesArg)
        Remove-StalePubicPackages
        $out = Join-Path $ftp '_pubic_hair_perclass'
        $baseRoots = @(
            (Join-Path $Script:Root 'pack\midnight_xyzw\_00_suzu_nude'),
            (Join-Path $Script:Root 'pack\midnight_xyzw\_00_thegreatsage_nude')
        ) -join ';'
        $pyArgs = @(
            $Script:PubicHairTool, '--hair-root', $Script:PubicHairRoot,
            '--base-roots', $baseRoots, '--out', $out, '--paz', $paz,
            '--styles', $stylesArg
        )
        if (-not (Invoke-BdoPythonChecked -Arguments $pyArgs -Label 'Pubic hair patcher')) { $allOk = $false }
    }

    # 4) Censorship
    if ([string]$Script:Config.censorshipTier -and $Script:Config.censorshipTier -ne 'off') {
        Write-Info '--- Censorship ---'
        if (-not (Apply-CensorshipPack -NoPrompt)) { $allOk = $false }
    }

    # 5) Genitals (native / all-class reuse)
    $f3d = [bool]$Script:Config.female3dVagina
    $maleMode = [string]$Script:Config.malePenisMode
    if (($f3d -or ($maleMode -and $maleMode -ne 'none')) -and (Test-Path -LiteralPath $Script:GenitalRoot)) {
        Write-Info '--- Genitals ---'
        $maleArg = 'none'
        if ($maleMode -eq 'perclass') {
            $maleArg = @(
                "warrior=$($Script:Config.penisWarrior)",
                "berserker=$($Script:Config.penisBerserker)",
                "musa=$($Script:Config.penisMusa)",
                "wizard=$($Script:Config.penisWizard)",
                "ninja=$($Script:Config.penisNinja)",
                "striker=$($Script:Config.penisStriker)"
            ) -join ','
        } elseif ($maleMode -in @('normal', 'hard')) {
            $maleArg = $maleMode
        }
        $out = Join-Path $ftp '_genital_RESTORED_native'
        $fClasses = [string]$Script:Config.genitalFemaleClasses
        $pyArgs = @(
            $Script:GenitalTool, '--pack-root', $Script:GenitalRoot, '--out', $out,
            '--paz', $paz,
            '--female-3d-vagina', $(if ($f3d) { 'on' } else { 'off' }),
            '--male-penis', $maleArg
        )
        if ($fClasses) { $pyArgs += @('--female-classes', $fClasses) }
        if (-not (Invoke-BdoPythonChecked -Arguments $pyArgs -Label 'Genital patcher')) { $allOk = $false }
    } elseif ($f3d -or ($maleMode -and $maleMode -ne 'none')) {
        Write-Warn "Genital pack missing: $Script:GenitalRoot"
    }

    # The old "new females EXPERIMENTAL genitals" pass is gone: it copied a donor
    # class's whole body PAC under a new class's name, giving that class the
    # donor's mesh and skin. Only authored meshes are generated now.

    # The old "new females EXPERIMENTAL pubic" pass wrote a SECOND pubic package
    # with its own class list in the same run, which re-applied hair to classes the
    # main pass had deliberately skipped. Every class now goes through step 3.

    Ensure-ToolsInPaz
    if ($allOk) {
        Write-Ok 'RESTORED batch finished. Run PartCutGen then Meta Injector.'
    } else {
        Write-Err 'RESTORED batch completed with one or more failed generators. Do not inject until fixed.'
    }
    if (-not $NoPrompt) { Pause-Any }
    return $allOk
}

function Get-HeishaRoot {
    $c = [string]$Script:Config.heishaRoot
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    if (Test-Path -LiteralPath $Script:DefaultHeishaRoot) { return $Script:DefaultHeishaRoot }
    $local = Join-Path $Script:Root 'heisha'
    if (Test-Path -LiteralPath $local) { return $local }
    return $null
}

function Show-HeishaRegenHelper {
    Write-Banner
    Write-Host '  POST-PATCH REGEN HELPER (heisha / Midnight)' -ForegroundColor Yellow
    Write-Host '  ===========================================' -ForegroundColor DarkGray
    Write-Info 'After a BDO client patch, Meta Injector may fail until packs are regenerated.'
    Write-Host ''
    Write-Host '  Recommended flow:' -ForegroundColor White
    Write-Host '    1. Open heisha (Midnight regenerator)' -ForegroundColor Cyan
    Write-Host '    2. setupenv.cmd  (once per machine)' -ForegroundColor Cyan
    Write-Host '    3. run.cmd -i <game\PAZ> -o .\PAZ\midnight_xyzw -m all' -ForegroundColor Cyan
    Write-Host '    4. Copy regenerated pack into this AIO pack\midnight_xyzw  (or re-point)' -ForegroundColor Cyan
    Write-Host '    5. AIO menu 3 deploy -> 4 PartCutGen -> 5 Meta Injector' -ForegroundColor Cyan
    Write-Host '    6. Optional: menu A apply all RESTORED choices' -ForegroundColor Cyan
    Write-Host ''

    $root = Get-HeishaRoot
    if ($root) {
        Write-Ok ("heisha root: " + $root)
    } else {
        Write-Warn 'heisha not found in the saved path or this AIO folder.'
        if (Read-YesNo 'Browse for heisha folder now?' $true) {
            Add-Type -AssemblyName System.Windows.Forms
            $d = New-Object System.Windows.Forms.FolderBrowserDialog
            $d.Description = 'Select heisha (midnightxyzw) folder'
            if ($d.ShowDialog() -eq 'OK') {
                $Script:Config.heishaRoot = $d.SelectedPath
                Save-Config
                $root = $d.SelectedPath
                Write-Ok ("Saved heishaRoot = " + $root)
            }
        }
    }

    Write-Host ''
    Write-Host '   [1] Open heisha folder in Explorer' -ForegroundColor Cyan
    Write-Host '   [2] Open run.cmd in notepad (read flags)' -ForegroundColor Cyan
    Write-Host '   [3] Print suggested run.cmd line for your PAZ' -ForegroundColor Green
    Write-Host '   [4] Open AIO pack\midnight_xyzw folder' -ForegroundColor Cyan
    Write-Host '   [0] Back' -ForegroundColor DarkGray
    $c = (Read-Host '  Select').Trim()
    switch ($c) {
        '1' {
            if ($root -and (Test-Path $root)) { Start-Process explorer.exe -ArgumentList $root }
            else { Write-Warn 'No heisha root.' }
        }
        '2' {
            $run = if ($root) { Join-Path $root 'run.cmd' } else { $null }
            if ($run -and (Test-Path $run)) { Start-Process notepad.exe -ArgumentList $run }
            else { Write-Warn 'run.cmd not found.' }
        }
        '3' {
            $paz = [string]$Script:Config.pazFolder
            if (-not (Test-IsPazFolder $paz)) { Write-Warn 'Set PAZ first.' }
            else {
                Write-Host ''
                Write-Host '  Suggested (from heisha folder after setupenv):' -ForegroundColor Yellow
                Write-Host ("  run.cmd -i `"$paz`" -o .\PAZ\midnight_xyzw -m all") -ForegroundColor White
                Write-Host ''
                Write-Info 'Then copy regenerated files into BDO-AIO\pack\midnight_xyzw and redeploy.'
            }
        }
        '4' {
            $p = Join-Path $Script:PackDir 'midnight_xyzw'
            if (Test-Path $p) { Start-Process explorer.exe -ArgumentList $p } else { Write-Warn 'pack\midnight_xyzw missing.' }
        }
    }
    Pause-Any
}

# Remove only AIO-generated packages; user-created folders and the Midnight
# deploy are left alone.
function Clear-AioGenerated {
    $ftp = Join-Path ([string]$Script:Config.pazFolder) 'files_to_patch'
    if (-not (Test-Path -LiteralPath $ftp)) { Write-Warn 'No files_to_patch.'; return 0 }
    $n = 0
    Get-ChildItem -LiteralPath $ftp -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $name = $_.Name
        $hit = $false
        foreach ($p in $Script:AioPatchFolderPrefixes) {
            if ($name -eq $p.TrimEnd('_') -or $name.StartsWith($p)) { $hit = $true; break }
        }
        if ($hit) {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host ("  removed: files_to_patch\" + $name) -ForegroundColor DarkGray
            $n++
        }
    }
    return $n
}

# Runs tools\bdo_meta\vanilla_restore.py against the configured PAZ folder.
# Returns $true when the tool reported success.
function Invoke-VanillaRestoreTool {
    param([string[]]$ToolArgs)
    if (-not (Ensure-Python)) { return $false }
    $tool = Join-Path $Script:Root 'tools\bdo_meta\vanilla_restore.py'
    if (-not (Test-Path -LiteralPath $tool)) {
        Write-Err ("Missing tool: " + $tool)
        return $false
    }
    $pyArgs = @($tool) + $ToolArgs + @('--paz', [string]$Script:Config.pazFolder)
    try {
        & $Script:PythonExe @pyArgs
    } catch {
        Write-Err $_.Exception.Message
        return $false
    }
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Write-Err ("vanilla_restore exit " + $LASTEXITCODE)
        return $false
    }
    return $true
}

function Restore-UneditedGameFiles {
    Write-Banner
    Write-Host '  RESTORE / CLEAN AIO CHANGES' -ForegroundColor Yellow
    Write-Host '  ===========================' -ForegroundColor DarkGray
    Write-Info 'For troubleshooting and making changes easily.'
    Write-Warn 'True vanilla meta may still need Pearl Abyss launcher Verify/Repair.'
    Write-Host ''
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ first.'
        Pause-Any
        return
    }
    $paz = [string]$Script:Config.pazFolder
    $gameRoot = Get-GameRootFromPaz
    $ftp = Join-Path $paz 'files_to_patch'

    Show-PazInjectStatus -PazFolder $paz
    Write-Host ''

    Write-Host '   [V] RESTORE GAME TO VANILLA  (meta backup + delete injected PAZ)' -ForegroundColor Green
    Write-Host '       No Steam verify needed. Shows a dry run first.' -ForegroundColor DarkGray
    Write-Host '   [S] Scan meta / backup state' -ForegroundColor Cyan
    Write-Host '   [B] Make a vanilla meta backup now (do this while unmodded)' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '   [1] Clear AIO-generated folders under files_to_patch only' -ForegroundColor Cyan
    Write-Host '       (_body_size, _slot_hide_*, _pubic_*, _censorship_*, _genital_*)' -ForegroundColor DarkGray
    Write-Host '   [2] Clear ENTIRE files_to_patch (includes Midnight deploy)' -ForegroundColor Yellow
    Write-Host '   [3] Uninstall AIO-marked experimental OptiScaler files from game root' -ForegroundColor Cyan
    Write-Host '   [4] Restore latest BDO-AIO-backup-dlss-* folder into game root' -ForegroundColor Cyan
    Write-Host '   [5] Do 1 + 3 (recommended soft reset)' -ForegroundColor Green
    Write-Host '   [6] Open Pearl Abyss launcher note (verify game files)' -ForegroundColor Magenta
    Write-Host '   [0] Cancel' -ForegroundColor DarkGray
    $c = (Read-Host '  Select').Trim().ToUpperInvariant()
    if ($c -eq '0' -or [string]::IsNullOrWhiteSpace($c)) { return }

    if ($c -eq 'S') { Invoke-VanillaRestoreTool @('scan'); Pause-Any; return }
    if ($c -eq 'B') { Invoke-VanillaRestoreTool @('backup'); Pause-Any; return }
    if ($c -eq 'V') {
        Write-Host ''
        Write-Info 'DRY RUN first — nothing is changed yet:'
        Write-Host ''
        if (-not (Invoke-VanillaRestoreTool @('restore'))) { Pause-Any; return }
        Write-Host ''
        Write-Warn 'This restores pad00000.meta from the oldest backup and deletes the'
        Write-Warn 'injected PAZ files listed above. Your AIO settings are NOT touched.'
        if (-not (Read-YesNo 'Restore the game to vanilla now?' $false)) {
            Write-Info 'Cancelled — nothing changed.'
            Pause-Any
            return
        }
        $keepPaz = -not (Read-YesNo 'Also delete the injected PAZ files (frees the space)?' $true)
        $restoreArgs = @('restore', '--apply')
        if ($keepPaz) { $restoreArgs += '--keep-paz' }
        if (Invoke-VanillaRestoreTool $restoreArgs) {
            Write-Host ''
            Write-Ok 'Game restored to vanilla.'
            if (Read-YesNo 'Also clear AIO-generated files_to_patch folders?' $true) {
                $n = Clear-AioGenerated
                Write-Ok ("Cleared $n AIO folder(s).")
            }
            Write-Info 'Your pubic/slider choices are kept in config.json — just re-apply and inject.'
        }
        Pause-Any
        return
    }

    if ($c -in @('1', '5')) {
        if (Read-YesNo 'Clear AIO-generated files_to_patch folders?' $true) {
            $n = Clear-AioGenerated
            Write-Ok ("Cleared $n AIO folder(s). Re-run PartCutGen + Meta Injector if meta was patched.")
        }
    }
    if ($c -eq '2') {
        if (Read-YesNo 'DELETE entire files_to_patch? This removes Midnight deploy too.' $false) {
            if (Test-Path -LiteralPath $ftp) {
                Remove-Item -LiteralPath $ftp -Recurse -Force
                Write-Ok 'files_to_patch removed.'
            }
            Write-Warn 'Run Meta Injector after clearing, or Verify game files for full stock meta.'
        }
    }
    if ($c -in @('3', '5')) {
        if ($gameRoot) {
            Uninstall-ExperimentalDlss
        }
    }
    if ($c -eq '4') {
        if (-not $gameRoot) { Write-Err 'No game root.'; Pause-Any; return }
        $backs = @(Get-ChildItem -LiteralPath $gameRoot -Directory -Filter 'BDO-AIO-backup-dlss-*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
        if ($backs.Count -eq 0) { Write-Warn 'No BDO-AIO-backup-dlss-* folders found.'; Pause-Any; return }
        Write-Info ("Using latest: " + $backs[0].Name)
        if (Read-YesNo 'Copy backup contents back into game root?' $true) {
            Get-ChildItem -LiteralPath $backs[0].FullName -Force | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $gameRoot $_.Name) -Recurse -Force
                Write-Host ("  restored: " + $_.Name) -ForegroundColor DarkGray
            }
            Write-Ok 'Backup restored into game root.'
        }
    }
    if ($c -eq '6') {
        Write-Host ''
        Write-Host '  To fully restore unedited game PAZ/meta:' -ForegroundColor White
        Write-Host '    1. Close BDO + launcher helpers' -ForegroundColor Cyan
        Write-Host '    2. Open Pearl Abyss / Steam / game launcher' -ForegroundColor Cyan
        Write-Host '    3. Use Verify / Repair / Check integrity of game files' -ForegroundColor Cyan
        Write-Host '    4. Then re-run AIO wizard if you still want mods' -ForegroundColor Cyan
        Write-Host ''
        Write-Info ("PAZ: " + $paz)
        if ($gameRoot) { Write-Info ("Game root: " + $gameRoot) }
    }

    Write-Host ''
    Write-Ok 'Restore menu step finished.'
    Pause-Any
}

function Run-FullWizard {
    Write-Banner
    Write-Host '  Full easy install wizard' -ForegroundColor White
    Write-Host '  ------------------------' -ForegroundColor DarkGray
    Write-Info 'This walks through Midnight, optional RESTORED batch, PartCutGen, Meta Injector.'
    Write-Host ''

    $pack = Test-PackReady
    if (-not $pack.Ok) {
        Write-Err 'Bundled pack is incomplete. This release zip may be damaged.'
        foreach ($m in $pack.Missing) { Write-Warn ("  " + $m) }
        Pause-Any
        return
    }

    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Warn 'PAZ not set yet.'
        if (Read-YesNo 'Set PAZ folder now?' $true) { Set-PazFolder }
        if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
            Write-Err 'Cannot continue without PAZ.'
            Pause-Any
            return
        }
    }

    Write-Host '  Your saved choices:' -ForegroundColor White
    Write-Host ("    Gender = " + (Get-GenderLabel $Script:Config.gender)) -ForegroundColor Gray
    Write-Host ("    Armor  = " + (Get-ArmorLabel $Script:Config.armor)) -ForegroundColor Gray
    Write-Host ("    XYZW   = " + $Script:Config.xyzwCollections) -ForegroundColor Gray
    if (Read-YesNo 'Change options (Midnight / RESTORED) before deploy?' $false) {
        Configure-ModChoices
    }

    if (-not (Deploy-Midnight)) { return }

    Write-Banner
    Write-Host '  RESTORED batch (optional)' -ForegroundColor Green
    if (Read-YesNo 'Apply all configured RESTORED choices now (body/slots/pubic/censorship/genitals)?' $true) {
        [void](Apply-AllRestoredChoices -NoPrompt)
    }

    Write-Banner
    Write-Host '  Next: PartCutGen' -ForegroundColor White
    if (Read-YesNo 'Launch PartCutGen now?' $true) {
        Run-PartCutGen
    }

    Write-Banner
    Write-Host '  Next: Meta Injector' -ForegroundColor White
    Write-Warn 'Game + launcher must be closed.'
    if (Read-YesNo 'Launch Meta Injector now?' $true) {
        Run-MetaInjector
    }

    Write-Host ''
    Write-Ok 'Wizard finished.'
    Write-Info 'After every official BDO patch: menu H (regen helper) then this wizard again.'
    Write-Info 'To undo AIO changes: menu R (Restore / clean).'
    Pause-Any
}

function Open-FilesToPatch {
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ first.'
        Pause-Any
        return
    }
    $ftp = Join-Path $Script:Config.pazFolder 'files_to_patch'
    if (-not (Test-Path -LiteralPath $ftp)) {
        New-Item -ItemType Directory -Path $ftp -Force | Out-Null
        Write-Info 'Created empty files_to_patch (deploy Midnight first for full mods).'
    }
    Start-Process explorer.exe -ArgumentList $ftp
    Write-Ok ("Opened: " + $ftp)
    Write-Info 'Drop extra Meta-Injector style mods here (character/model, character/texture), then re-run PartCutGen + Injector.'
    Pause-Any
}

function Apply-GraphicsProfile {
    Write-Banner
    Write-Host '  Graphics profile pack (GameOption)' -ForegroundColor White
    Write-Host '  ----------------------------------' -ForegroundColor DarkGray
    Write-Info 'Merges verified max-quality keys into Documents\Black Desert\GameOption.txt'
    Write-Info 'Display adapter, window mode, HDR, audio, UI, gamma, and every unknown/current key are preserved.'
    Write-Warn 'Close Black Desert completely before applying.'
    Write-Host ''

    $gfx = Test-GraphicsReady
    if (-not $gfx.Ok) {
        Write-Err 'Graphics pack incomplete in this AIO folder.'
        foreach ($m in $gfx.Missing) { Write-Warn ("  " + $m) }
        Pause-Any
        return
    }

    $bdoDocs = Get-BdoDocumentsFolder
    $target = Join-Path $bdoDocs 'GameOption.txt'
    Write-Info ("Target folder : " + $bdoDocs)
    Write-Info ("Target file   : " + $target)
    Write-Host ''

    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        Write-Err 'GameOption.txt does not exist. Start BDO once, close it completely, then retry.'
        Pause-Any
        return
    }
    if (-not (Ensure-Python)) {
        Pause-Any
        return
    }

    Write-Host '  PROFILES' -ForegroundColor White
    Write-Host '  --------' -ForegroundColor DarkGray
    $keys = @($Script:GraphicsProfiles.Keys)
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $k = $keys[$i]
        Write-Host ("    [" + ($i + 1) + "] " + $Script:GraphicsProfiles[$k]) -ForegroundColor Cyan
        Write-Host ("        file: " + $k) -ForegroundColor DarkGray
    }
    Write-Host '    [R] Open graphics README' -ForegroundColor Yellow
    Write-Host '    [O] Open Documents\Black Desert folder' -ForegroundColor Yellow
    Write-Host '    [0] Cancel' -ForegroundColor DarkGray
    Write-Host ''

    $pick = (Read-Host '  Select profile').Trim().ToUpperInvariant()
    if ($pick -eq '0' -or [string]::IsNullOrEmpty($pick)) { return }

    if ($pick -eq 'R') {
        $readme = Join-Path $Script:GraphicsDir 'README.txt'
        if (Test-Path -LiteralPath $readme) {
            Start-Process notepad.exe -ArgumentList $readme
            Write-Ok 'Opened graphics README.'
        } else {
            Write-Warn 'README.txt missing from graphics folder.'
        }
        Pause-Any
        return
    }
    if ($pick -eq 'O') {
        if (-not (Test-Path -LiteralPath $bdoDocs)) {
            New-Item -ItemType Directory -Path $bdoDocs -Force | Out-Null
        }
        Start-Process explorer.exe -ArgumentList $bdoDocs
        Write-Ok ("Opened: " + $bdoDocs)
        Pause-Any
        return
    }

    if ($pick -notmatch '^\d+$') {
        Write-Warn 'Invalid choice.'
        Pause-Any
        return
    }
    $idx = [int]$pick - 1
    if ($idx -lt 0 -or $idx -ge $keys.Count) {
        Write-Warn 'Invalid profile number.'
        Pause-Any
        return
    }

    $fileName = $keys[$idx]
    $src = Join-Path $Script:GraphicsDir $fileName
    Write-Host ''
    Write-Host ("  Selected: " + $Script:GraphicsProfiles[$fileName]) -ForegroundColor White
    Write-Host ("  Source  : " + $src) -ForegroundColor Gray

    if ($fileName -match 'DLDSR') {
        Write-Host ''
        Write-Warn 'DLDSR profiles need NVIDIA Control Panel first:'
        Write-Host '  Manage 3D Settings -> DSR Factors -> DL scaling 2.25x' -ForegroundColor Yellow
        Write-Host '  Then in BDO fullscreen pick 3840x2160' -ForegroundColor Yellow
        Write-Host '  Start DSR Smoothness around 50%' -ForegroundColor Yellow
    }
    Write-Host ''
    if (-not (Read-YesNo 'Merge this profile now? (backs up the complete existing file)' $true)) {
        Write-Warn 'Cancelled.'
        Pause-Any
        return
    }

    try {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
        $backup = Join-Path $bdoDocs ("GameOption.backup." + $stamp + ".txt")
        Copy-Item -LiteralPath $target -Destination $backup
        Write-Ok ("Backed up complete file -> " + [IO.Path]::GetFileName($backup))

        $ok = Invoke-BdoPythonChecked -Arguments @(
            $Script:GameOptionTool,
            '--game-option', $target,
            '--profile', $src,
            '--output', $target
        ) -Label 'GameOption merge'
        if (-not $ok) { throw 'GameOption merge failed; the original target was not replaced.' }
        Write-Ok ("Merged verified keys into: " + $target)
        Write-Info 'Do NOT mark GameOption.txt read-only (game/patches may update it).'
        Write-Info 'Start the game and verify: Texture High, Remastered, TAA, Upscale Off.'
    } catch {
        Write-Err $_.Exception.Message
    }
    Pause-Any
}

function Get-GameRootFromPaz {
    $paz = [string]$Script:Config.pazFolder
    if (-not (Test-IsPazFolder $paz)) { return $null }
    $root = Split-Path -Parent $paz
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return $null }
    return $root
}

function Get-BdoClientRegion {
    $gameRoot = Get-GameRootFromPaz
    if (-not $gameRoot) { return '' }
    $serviceIni = Join-Path $gameRoot 'service.ini'
    if (-not (Test-Path -LiteralPath $serviceIni -PathType Leaf)) { return '' }
    foreach ($line in Get-Content -LiteralPath $serviceIni -ErrorAction Stop) {
        if ($line -match '^\s*TYPE\s*=\s*(.*?)\s*$') {
            return $Matches[1].Trim().ToUpperInvariant()
        }
    }
    return ''
}

function Test-ExperimentalDlssReady {
    $opti = Join-Path $Script:ExperimentalDlssDir 'OptiScaler\OptiScaler.dll'
    $ini  = Join-Path $Script:ExperimentalDlssDir 'OptiScaler\OptiScaler.ini'
    $sl   = Join-Path $Script:ExperimentalDlssDir 'Streamline\sl.dlss.dll'
    $missing = @()
    if (-not (Test-Path -LiteralPath $opti)) { $missing += $opti }
    if (-not (Test-Path -LiteralPath $ini))  { $missing += $ini }
    if (-not (Test-Path -LiteralPath $sl))   { $missing += $sl }
    return @{
        Ok      = ($missing.Count -eq 0)
        Missing = $missing
        OptiDir = (Join-Path $Script:ExperimentalDlssDir 'OptiScaler')
        StreamDir = (Join-Path $Script:ExperimentalDlssDir 'Streamline')
    }
}

function Confirm-ExperimentalDanger {
    Write-Host ''
    Write-Host '  ############################################################' -ForegroundColor Red
    Write-Host '  #   EXPERIMENTAL  /  NOT SAFE  /  OWN RISK ONLY            #' -ForegroundColor Red
    Write-Host '  #   Unofficial DLL inject for DLSS-style upscaling         #' -ForegroundColor Red
    Write-Host '  #   Ban / crash / black screen / broken after patches      #' -ForegroundColor Red
    Write-Host '  #   BDO only has weak FSR-class upscale; this hacks around #' -ForegroundColor Red
    Write-Host '  ############################################################' -ForegroundColor Red
    Write-Host ''
    Write-Host '  Safe alternatives: menu G (GameOption) + menu N (NVIDIA profile).' -ForegroundColor Yellow
    Write-Host '  Do NOT use on a main account you care about.' -ForegroundColor Yellow
    Write-Host ''

    $a = (Read-Host '  Type YES to acknowledge this is EXPERIMENTAL and NOT SAFE').Trim()
    if ($a -cne 'YES') {
        Write-Warn 'Aborted (you must type YES in capitals).'
        return $false
    }
    if (-not (Read-YesNo 'Install unofficial DLLs into your BDO game folder anyway?' $false)) {
        Write-Warn 'Aborted.'
        return $false
    }
    return $true
}

function Install-ExperimentalDlss {
    Write-Banner
    Write-Host '  [X] EXPERIMENTAL DLSS / OptiScaler for BDO' -ForegroundColor Red
    Write-Host '  ==========================================' -ForegroundColor Red
    Write-Info 'BDO native upscale is weak (FSR 1.0-class). This tries modern upscalers via OptiScaler.'
    Write-Warn 'THIS IS UNOFFICIAL CLIENT MODIFICATION. NOT SAFE.'
    Write-Host ''

    $ready = Test-ExperimentalDlssReady
    if (-not $ready.Ok) {
        Write-Err 'Experimental pack incomplete under experimental\dlss\'
        foreach ($m in $ready.Missing) { Write-Warn ("  " + $m) }
        Pause-Any
        return
    }

    if (-not (Confirm-ExperimentalDanger)) {
        Pause-Any
        return
    }

    $gameRoot = Get-GameRootFromPaz
    if (-not $gameRoot) {
        Write-Err 'Set a valid game PAZ folder first (menu 1). Game root is the parent of PAZ.'
        Pause-Any
        return
    }

    $exeCandidates = @('BlackDesert64.exe', 'BlackDesertOnline.exe', 'BlackDesert.exe')
    $exeFound = $false
    foreach ($e in $exeCandidates) {
        if (Test-Path -LiteralPath (Join-Path $gameRoot $e)) { $exeFound = $true; break }
    }
    Write-Info ("Game root : " + $gameRoot)
    if ($exeFound) {
        Write-Ok 'Found BDO executable in game root.'
    } else {
        Write-Warn 'Did not find BlackDesert64.exe in game root — double-check PAZ parent is correct.'
        if (-not (Read-YesNo 'Continue install into this folder anyway?' $false)) {
            Pause-Any
            return
        }
    }

    Write-Host ''
    Write-Host '  Proxy DLL name for OptiScaler (how it loads):' -ForegroundColor White
    Write-Host '    [1] dxgi.dll     (RECOMMENDED default, most compatible)' -ForegroundColor Cyan
    Write-Host '    [2] winmm.dll    (alternate)' -ForegroundColor Cyan
    Write-Host '    [3] version.dll (alternate; may conflict with other mods)' -ForegroundColor Cyan
    $proxyPick = Read-Choice 'Proxy' @('1', '2', '3')
    $proxyName = switch ($proxyPick) {
        '1' { 'dxgi.dll' }
        '2' { 'winmm.dll' }
        '3' { 'version.dll' }
    }

    Write-Host ''
    Write-Host '  Preferred upscaler in OptiScaler.ini (game still must enable upscale):' -ForegroundColor White
    Write-Host '    [1] dlss     (NVIDIA DLSS, if compatible inputs are available)' -ForegroundColor Cyan
    Write-Host '    [2] auto    (OptiScaler default)' -ForegroundColor Cyan
    Write-Host '    [3] fsr31   (OptiScaler bundled FidelityFX path)' -ForegroundColor Cyan
    Write-Host '    [4] xess    (Intel XeSS)' -ForegroundColor Cyan
    $upPick = Read-Choice 'Upscaler' @('1', '2', '3', '4')
    $upName = switch ($upPick) {
        '1' { 'dlss' }
        '2' { 'auto' }
        '3' { 'fsr31' }
        '4' { 'xess' }
    }

    Write-Host ''
    Write-Warn ("About to copy EXPERIMENTAL files into: " + $gameRoot)
    Write-Warn ("Proxy: " + $proxyName + "  |  Upscaler: " + $upName + '  |  official OptiScaler bundle only')
    if (-not (Read-YesNo 'Final confirm — install now?' $false)) {
        Write-Warn 'Cancelled.'
        Pause-Any
        return
    }

    # Backup existing proxies / known files
    $backupDir = Join-Path $gameRoot ('BDO-AIO-backup-dlss-' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Info ("Backup folder: " + $backupDir)

    $toBackup = @($Script:OptiProxyNames + $Script:OptiExtraFiles + @('D3D12_Optiscaler')) | Select-Object -Unique
    foreach ($name in $toBackup) {
        $p = Join-Path $gameRoot $name
        if (Test-Path -LiteralPath $p) {
            try {
                Copy-Item -LiteralPath $p -Destination (Join-Path $backupDir $name) -Recurse -Force
                Write-Host ("  backed up: " + $name) -ForegroundColor DarkGray
            } catch {
                Write-Warn ("Could not back up " + $name + ": " + $_.Exception.Message)
            }
        }
    }

    # Copy OptiScaler tree (files + D3D12_Optiscaler + Licenses)
    Write-Info 'Copying OptiScaler...'
    $optiSrc = $ready.OptiDir
    Get-ChildItem -LiteralPath $optiSrc -Force | ForEach-Object {
        $dest = Join-Path $gameRoot $_.Name
        if ($_.PSIsContainer) {
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force
        } else {
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        }
    }

    # Copy Streamline DLLs into game root
    Write-Info 'Copying Streamline DLLs...'
    Get-ChildItem -LiteralPath $ready.StreamDir -File -Filter 'sl.*.dll' | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $gameRoot $_.Name) -Force
    }

    # Rename OptiScaler.dll -> proxy
    $optiInGame = Join-Path $gameRoot 'OptiScaler.dll'
    $proxyPath = Join-Path $gameRoot $proxyName
    if (-not (Test-Path -LiteralPath $optiInGame)) {
        Write-Err 'OptiScaler.dll missing after copy — install failed.'
        Pause-Any
        return
    }

    if (Test-Path -LiteralPath $proxyPath) {
        Remove-Item -LiteralPath $proxyPath -Force
    }
    Rename-Item -LiteralPath $optiInGame -NewName $proxyName
    Write-Ok ("Installed proxy: " + $proxyName + " (was OptiScaler.dll)")

    # Patch OptiScaler.ini upscaler preferences when not auto
    $iniPath = Join-Path $gameRoot 'OptiScaler.ini'
    if ((Test-Path -LiteralPath $iniPath) -and ($upName -ne 'auto')) {
        try {
            $ini = Get-Content -LiteralPath $iniPath -Raw -Encoding UTF8
            $ini = [regex]::Replace($ini, '(?m)^Dx11Upscaler=.*$', "Dx11Upscaler=$upName")
            $ini = [regex]::Replace($ini, '(?m)^Dx12Upscaler=.*$', "Dx12Upscaler=$upName")
            $ini = [regex]::Replace($ini, '(?m)^VulkanUpscaler=.*$', "VulkanUpscaler=$upName")
            # Prefer FSR FG path when fsr31 selected (keys vary by OptiScaler version — best-effort)
            if ($upName -eq 'fsr31') {
                $ini = [regex]::Replace($ini, '(?m)^FgType=.*$', 'FgType=optifg')
            }
            $utf8 = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($iniPath, $ini, $utf8)
            Write-Ok ("OptiScaler.ini upscalers set to: " + $upName)
            Write-Info 'Using only the DLL set bundled by the official OptiScaler release.'
        } catch {
            Write-Warn ("Could not edit OptiScaler.ini: " + $_.Exception.Message)
        }
    }

    # Marker for uninstall awareness
    $marker = Join-Path $gameRoot 'BDO-AIO-EXPERIMENTAL-DLSS.txt'
    @(
        ('EXPERIMENTAL / NOT SAFE - installed by BDO-AIO ' + $Script:Version),
        ('Installed: ' + (Get-Date).ToString('s')),
        ('Proxy: ' + $proxyName),
        ('Upscaler: ' + $upName),
        ('Backup: ' + $backupDir),
        'Uninstall via BDO-AIO menu X / R. Do not delete unrelated proxy DLLs by filename.'
    ) | Set-Content -LiteralPath $marker -Encoding UTF8

    Write-Host ''
    Write-Ok 'Experimental install finished.'
    Write-Host '  NEXT STEPS' -ForegroundColor Yellow
    Write-Host '  1. Launch BDO. If it fails to start -> menu X Uninstall or menu R immediately.' -ForegroundColor Yellow
    Write-Host '  2. Enable in-game Upscale / FSR if available so the hook has something to replace.' -ForegroundColor Yellow
    Write-Host '  3. OptiScaler overlay keys are in OptiScaler.ini / OptiScaler wiki.' -ForegroundColor Yellow
    Write-Host '  4. After game patches, reinstall or remove — DLLs often break.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Remember: EXPERIMENTAL. NOT SAFE. Own risk.' -ForegroundColor Red
    Pause-Any
}

function Uninstall-ExperimentalDlss {
    Write-Banner
    Write-Host '  Uninstall EXPERIMENTAL DLSS / OptiScaler files' -ForegroundColor Yellow
    Write-Host '  ----------------------------------------------' -ForegroundColor DarkGray

    $gameRoot = Get-GameRootFromPaz
    if (-not $gameRoot) {
        Write-Err 'Set PAZ first (menu 1).'
        Pause-Any
        return
    }
    Write-Info ("Game root: " + $gameRoot)
    $marker = Join-Path $gameRoot 'BDO-AIO-EXPERIMENTAL-DLSS.txt'
    if (-not (Test-Path -LiteralPath $marker)) {
        Write-Warn 'No BDO-AIO experimental-install marker was found. Refusing filename-only DLL deletion.'
        Write-Info 'Use the launcher Verify/Repair flow or restore a known backup instead.'
        Pause-Any
        return
    }
    Write-Warn 'This removes the AIO-marked OptiScaler proxy and bundled Streamline/Opti files.'
    if (-not (Read-YesNo 'Remove experimental DLLs now?' $true)) {
        Pause-Any
        return
    }

    $removed = 0
    foreach ($name in ($Script:OptiProxyNames + $Script:OptiExtraFiles | Select-Object -Unique)) {
        $p = Join-Path $gameRoot $name
        if (Test-Path -LiteralPath $p) {
            # Never delete an unrelated loader just because it uses a common proxy filename.
            $isProxy = $Script:OptiProxyNames -contains $name
            $delete = $true
            if ($isProxy) {
                $delete = $false
                try {
                    $orig = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($p).OriginalFilename
                    if ($orig -match 'OptiScaler') { $delete = $true }
                } catch {}
                if (-not $delete) {
                    $bundled = Join-Path $Script:ExperimentalDlssDir 'OptiScaler\OptiScaler.dll'
                    if (Test-Path -LiteralPath $bundled) {
                        try {
                            $delete = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -eq
                                      (Get-FileHash -LiteralPath $bundled -Algorithm SHA256).Hash
                        } catch {}
                    }
                }
                if (-not $delete) { Write-Warn ("Skipping unrelated or unverifiable proxy: " + $name) }
            }
            if ($delete) {
                Remove-Item -LiteralPath $p -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host ("  removed: " + $name) -ForegroundColor DarkGray
                $removed++
            }
        }
    }
    $d3 = Join-Path $gameRoot 'D3D12_Optiscaler'
    if (Test-Path -LiteralPath $d3) {
        Remove-Item -LiteralPath $d3 -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host '  removed: D3D12_Optiscaler\' -ForegroundColor DarkGray
        $removed++
    }
    $lic = Join-Path $gameRoot 'Licenses'
    # only remove Licenses if it looks like OptiScaler licenses folder
    if (Test-Path -LiteralPath (Join-Path $lic 'XeSS_LICENSE.txt')) {
        Remove-Item -LiteralPath $lic -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host '  removed: Licenses\' -ForegroundColor DarkGray
    }
    if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }

    Write-Ok ("Uninstall pass done. Items removed: " + $removed)
    Write-Info 'If the game still misbehaves, verify/repair game files in the launcher.'
    Write-Info 'Timestamped BDO-AIO-backup-dlss-* folders in game root are left for you to restore manually.'
    Pause-Any
}

function Show-ExperimentalDlssMenu {
    Write-Banner
    Write-Host '  ########################################################' -ForegroundColor Red
    Write-Host '  #  EXPERIMENTAL (FROM-SCRATCH) — NOT a RESTORED feature  #' -ForegroundColor Red
    Write-Host '  #  OptiScaler / DLSS inject — NOT SAFE                   #' -ForegroundColor Red
    Write-Host '  ########################################################' -ForegroundColor Red
    Write-Host ''
    Write-Host '  This is NOT Resorepless and NOT Midnight. Built separately in BDO-AIO.' -ForegroundColor Yellow
    Write-Host '  Uses the unmodified official OptiScaler bundle only. High ban/crash risk.' -ForegroundColor Yellow
    Write-Host ''

    $ready = Test-ExperimentalDlssReady
    if ($ready.Ok) {
        Write-Ok 'Experimental pack found under experimental\dlss\'
    } else {
        Write-Err 'Experimental pack incomplete.'
        foreach ($m in $ready.Missing) { Write-Warn ("  " + $m) }
    }

    $gameRoot = Get-GameRootFromPaz
    if ($gameRoot) {
        Write-Info ("Game root: " + $gameRoot)
        if (Test-Path -LiteralPath (Join-Path $gameRoot 'BDO-AIO-EXPERIMENTAL-DLSS.txt')) {
            Write-Warn 'Marker found: experimental DLSS appears INSTALLED in game root.'
        }
    } else {
        Write-Warn 'Game PAZ not set — set menu 1 before install.'
    }

    Write-Host ''
    Write-Host '   [1] Read WARNING.txt' -ForegroundColor Red
    Write-Host '   [2] Read experimental README' -ForegroundColor Yellow
    Write-Host '   [3] INSTALL official OptiScaler 0.9.4 + bundled Streamline  *** NOT SAFE ***' -ForegroundColor Red
    Write-Host '   [4] UNINSTALL experimental DLLs from game folder' -ForegroundColor Cyan
    Write-Host '   [5] Open experimental\dlss folder' -ForegroundColor Cyan
    Write-Host '   [0] Back' -ForegroundColor DarkGray
    Write-Host ''
    $c = (Read-Host '  Select').Trim()
    switch ($c) {
        '1' {
            $w = Join-Path $Script:ExperimentalDlssDir 'WARNING.txt'
            if (Test-Path -LiteralPath $w) { Start-Process notepad.exe -ArgumentList $w }
            Pause-Any
            Show-ExperimentalDlssMenu
        }
        '2' {
            $r = Join-Path $Script:ExperimentalDlssDir 'README.txt'
            if (Test-Path -LiteralPath $r) { Start-Process notepad.exe -ArgumentList $r }
            Pause-Any
            Show-ExperimentalDlssMenu
        }
        '3' { Install-ExperimentalDlss }
        '4' { Uninstall-ExperimentalDlss }
        '5' {
            if (Test-Path -LiteralPath $Script:ExperimentalDlssDir) {
                Start-Process explorer.exe -ArgumentList $Script:ExperimentalDlssDir
            }
            Pause-Any
            Show-ExperimentalDlssMenu
        }
        default { return }
    }
}

function Resolve-NpiInteractive {
    $found = Find-NvidiaProfileInspector
    if ($found) { return $found }

    Write-Warn 'nvidiaProfileInspector.exe not found automatically.'
    Write-Info 'Pick the EXE (often under Documents\Apps\NvidiaProfileInspector).'
    Write-Host '    [B] Browse for nvidiaProfileInspector.exe' -ForegroundColor Cyan
    Write-Host '    [M] Type full path manually' -ForegroundColor Cyan
    Write-Host '    [0] Cancel' -ForegroundColor DarkGray
    $pick = (Read-Host '  Choice').Trim().ToUpperInvariant()
    if ($pick -eq '0' -or [string]::IsNullOrEmpty($pick)) { return $null }

    if ($pick -eq 'B') {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $dlg = New-Object System.Windows.Forms.OpenFileDialog
            $dlg.Title = 'Select nvidiaProfileInspector.exe'
            $dlg.Filter = 'NVIDIA Profile Inspector|nvidiaProfileInspector.exe|EXE|*.exe'
            $dlg.FileName = 'nvidiaProfileInspector.exe'
            $start = Join-Path $env:USERPROFILE 'Documents\Apps\NvidiaProfileInspector'
            if (Test-Path -LiteralPath $start) { $dlg.InitialDirectory = $start }
            if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                if (Test-Path -LiteralPath $dlg.FileName) {
                    $Script:Config.npiPath = $dlg.FileName
                    Save-Config
                    return $dlg.FileName
                }
            }
        } catch {
            Write-Warn 'Folder dialog failed; use manual path.'
            $pick = 'M'
        }
    }

    if ($pick -eq 'M') {
        $manual = (Read-Host '  Full path to nvidiaProfileInspector.exe').Trim().Trim('"')
        if (Test-Path -LiteralPath $manual) {
            $Script:Config.npiPath = $manual
            Save-Config
            return $manual
        }
        Write-Err 'Path not found.'
    }
    return $null
}

function Apply-NvidiaProfile {
    Write-Banner
    Write-Host '  NVIDIA Profile Inspector (.nip)' -ForegroundColor White
    Write-Host '  --------------------------------' -ForegroundColor DarkGray
    Write-Info 'Imports Black_Desert_Max_Quality.nip for blackdesert64.exe'
    Write-Warn 'Close Black Desert before importing. NVIDIA GPU required.'
    Write-Host ''

    $nip = Test-NipReady
    if (-not $nip.Ok) {
        Write-Err ("Missing bundled profile: " + $nip.Path)
        Pause-Any
        return
    }
    Write-Ok ("NIP file : " + $nip.Path)

    $npi = Resolve-NpiInteractive
    if (-not $npi) {
        Write-Err 'Cannot import without nvidiaProfileInspector.exe'
        Write-Info 'Install NPI or place it under tools\nvidiaProfileInspector\ in this AIO folder.'
        Pause-Any
        return
    }
    Write-Ok ("NPI app  : " + $npi)
    Write-Host ''
    Write-Host '  Options' -ForegroundColor White
    Write-Host '    [1] Import .nip silently (recommended)' -ForegroundColor Cyan
    Write-Host '    [2] Open NPI GUI (manual import)' -ForegroundColor Cyan
    Write-Host '    [R] Open NIP README' -ForegroundColor Yellow
    Write-Host '    [0] Cancel' -ForegroundColor DarkGray
    Write-Host ''
    $pick = (Read-Host '  Select').Trim().ToUpperInvariant()
    if ($pick -eq '0' -or [string]::IsNullOrEmpty($pick)) { return }

    if ($pick -eq 'R') {
        $rm = Join-Path $Script:NvidiaDir 'README.txt'
        if (Test-Path -LiteralPath $rm) { Start-Process notepad.exe -ArgumentList $rm }
        Pause-Any
        return
    }

    if ($pick -eq '2') {
        Write-Info 'In NPI: Profile menu -> Import profile(s) -> select the .nip -> Apply changes'
        Start-Process -FilePath $npi -WorkingDirectory (Split-Path -Parent $npi)
        # Also open the folder containing the nip for easy drag
        Start-Process explorer.exe -ArgumentList ("/select," + $nip.Path)
        Write-Ok 'Opened NPI and highlighted the .nip file.'
        Pause-Any
        return
    }

    if ($pick -ne '1') {
        Write-Warn 'Invalid choice.'
        Pause-Any
        return
    }

    if (-not (Read-YesNo 'Import Black Desert max-quality driver profile now?' $true)) {
        Write-Warn 'Cancelled.'
        Pause-Any
        return
    }

    Write-Info 'Running silent import...'
    try {
        # Official CLI: nvidiaProfileInspector.exe -silentImport "file.nip"
        $p = Start-Process -FilePath $npi -ArgumentList @('-silentImport', $nip.Path) -WorkingDirectory (Split-Path -Parent $npi) -PassThru -Wait
        if ($p.ExitCode -and $p.ExitCode -ne 0) {
            Write-Warn ("NPI exit code " + $p.ExitCode + " - trying plain import (opens UI)...")
            Start-Process -FilePath $npi -ArgumentList @($nip.Path) -WorkingDirectory (Split-Path -Parent $npi)
            Write-Info 'If a window opened, confirm Apply/Save in NPI.'
        } else {
            Write-Ok 'Import finished (silent). Driver profile "Black Desert" should be active for blackdesert64.exe.'
        }
        Write-Info 'Tip: After big GeForce driver updates, re-run menu N if settings reset.'
        Write-Info 'Pair with menu G (GameOption) + NVIDIA DSR if using DLDSR 4K profiles.'
    } catch {
        Write-Err $_.Exception.Message
        Write-Info 'Fallback: open NPI GUI and import the .nip manually (menu N option 2).'
    }
    Pause-Any
}

function Show-Guide2026 {
    Write-Banner
    Write-Host '  2026 - What is in THIS package vs what is not' -ForegroundColor White
    Write-Host '  =============================================' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  INSIDE this AIO folder (publish as one zip)' -ForegroundColor Green
    Write-Host '  -------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  START.bat              double-click entry'
    Write-Host '  bdo_aio.ps1            menu / wizard'
    Write-Host '  config.json            remembers YOUR game path + choices'
    Write-Host '  pack\                  Midnight mods + PartCutGen + Meta Injector'
    Write-Host '  graphics\              GameOption max-quality profiles'
    Write-Host '  graphics\nvidia\       Black_Desert_Max_Quality.nip'
    Write-Host '  tools\nvidiaProfileInspector\   NPI app (bundled when present)'
    Write-Host '  experimental\dlss\     OptiScaler + Streamline  [EXPERIMENTAL / NOT SAFE]'
    Write-Host '  README.md / CREDITS.md docs'
    Write-Host ''
    Write-Host '  NOT in the zip (user must have)' -ForegroundColor Yellow
    Write-Host '  -------------------------------' -ForegroundColor DarkGray
    Write-Host '  Black Desert Online install (PAZ folder)'
    Write-Host '  Documents\Black Desert (created/used for GameOption.txt)'
    Write-Host '  Python 3 (python.exe, py launcher, or normal per-user install)'
    Write-Host '  BDO Toolkit 1.3.0 (required by bundled Meta Injector 1.4.1)'
    Write-Host '  Meta Patcher 1.1.0: not needed on NA/EU; other official regions may require it'
    Write-Host '  NVIDIA GPU + driver (for .nip import / DLSS path)'
    Write-Host ''
    Write-Host '  REDUNDANT / creator-only (not bundled)' -ForegroundColor Yellow
    Write-Host '  --------------------------------------' -ForegroundColor DarkGray
    Write-Host '  Resorepless UI, PAZ Unpacker/Browser, PACtool, 3D Converter,'
    Write-Host '  old 0.3.0 pack, SkyrimUpscaler (wrong game)'
    Write-Host ''
    Write-Host '  PIPELINE' -ForegroundColor White
    Write-Host '  --------' -ForegroundColor DarkGray
    Write-Host '  NA/EU: Deploy -> PartCutGen -> canonical stage -> Meta Injector -> Launch'
    Write-Host '  GFX : Menu G -> GameOption.txt'
    Write-Host '  NPI : Menu N -> import .nip driver profile'
    Write-Host '  DLSS: Menu X -> EXPERIMENTAL OptiScaler (NOT SAFE)'
    Write-Host ''
    Write-Host '  RISK: client mods can break after patches and may violate ToS.' -ForegroundColor Red
    Write-Host '  Menu X is EXTRA risky (DLL inject / ban potential).' -ForegroundColor Red
    Write-Host ''
    Pause-Any
}

function Show-VerifyPack {
    Write-Banner
    Write-Host '  Verify bundled content (publisher / integrity)' -ForegroundColor White
    Write-Host '  ----------------------------------------------' -ForegroundColor DarkGray

    $pack = Test-PackReady
    Write-Info ("Pack folder: " + $Script:PackDir)
    if ($pack.Ok) {
        Write-Ok 'Mod pack tools present.'
        $fileCount = (Get-ChildItem -LiteralPath $Script:PackDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $mb = (Get-ChildItem -LiteralPath $Script:PackDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
        Write-Host ("  Files : " + $fileCount) -ForegroundColor Gray
        Write-Host ("  Size  : {0:N1} MB" -f $mb) -ForegroundColor Gray
        if ($mb -lt 500) {
            Write-Warn 'Pack looks small (expected ~1.5-2 GB with full Midnight content). Zip may be incomplete.'
        }
    } else {
        Write-Err 'Mod pack incomplete:'
        foreach ($m in $pack.Missing) { Write-Warn ("  " + $m) }
    }

    Write-Host ''
    $gfx = Test-GraphicsReady
    Write-Info ("Graphics folder: " + $Script:GraphicsDir)
    if ($gfx.Ok) {
        Write-Ok 'All 3 GameOption merge patches and the safe patcher are present.'
        foreach ($name in $Script:GraphicsProfiles.Keys) {
            $p = Join-Path $Script:GraphicsDir $name
            $len = (Get-Item -LiteralPath $p).Length
            Write-Host ("  " + $name + "  (" + $len + " bytes)") -ForegroundColor Gray
        }
    } else {
        Write-Err 'Graphics pack incomplete:'
        foreach ($m in $gfx.Missing) { Write-Warn ("  " + $m) }
    }

    Write-Host ''
    $nip = Test-NipReady
    $npi = Find-NvidiaProfileInspector
    Write-Info ("NVIDIA folder: " + $Script:NvidiaDir)
    if ($nip.Ok) {
        Write-Ok ("NIP present: " + $nip.Path + "  (" + (Get-Item -LiteralPath $nip.Path).Length + " bytes)")
    } else {
        Write-Err ("NIP missing: " + $nip.Path)
    }
    if ($npi) {
        Write-Ok ("NPI present: " + $npi)
    } else {
        Write-Warn 'NPI missing: put nvidiaProfileInspector.exe in tools\nvidiaProfileInspector\ or set path via menu N'
    }

    Write-Host ''
    Write-Host '  EXPERIMENTAL DLSS pack (NOT SAFE)' -ForegroundColor Red
    $ex = Test-ExperimentalDlssReady
    if ($ex.Ok) {
        Write-Ok 'OptiScaler + Streamline present under experimental\dlss\'
        $mb = (Get-ChildItem -LiteralPath $Script:ExperimentalDlssDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
        Write-Host ("  Size ~ {0:N0} MB" -f $mb) -ForegroundColor Gray
    } else {
        Write-Err 'Experimental DLSS pack incomplete:'
        foreach ($m in $ex.Missing) { Write-Warn ("  " + $m) }
    }
    Pause-Any
}

function Show-MainMenu {
    while ($true) {
        Write-Banner
        Show-Status
        Write-Host ("  MENU  (BDO-AIO " + $Script:Version + ')') -ForegroundColor White
        Write-Host '  ------------------' -ForegroundColor DarkGray
        Write-Host '   [1] Set / find game PAZ folder' -ForegroundColor Cyan
        Write-Host '   [2] Options hub  (MODERN + RESTORED)' -ForegroundColor Cyan
        Write-Host '   [3] Deploy Midnight mods  ->  files_to_patch     [MODERN]' -ForegroundColor Cyan
        Write-Host '   [4] Run PartCutGen        (required)             [MODERN]' -ForegroundColor Cyan
        Write-Host '   [5] Run Meta Injector     (apply patch)          [MODERN]' -ForegroundColor Cyan
        Write-Host '   [6] FULL WIZARD           (Midnight + RESTORED)  [MODERN]' -ForegroundColor Green
        Write-Host '   [A] Apply ALL RESTORED choices (from config)     [RESTORED]' -ForegroundColor Green
        Write-Host '   [7] Open files_to_patch   (add extra mods)' -ForegroundColor Cyan
        Write-Host '   [S] Scan PAZ status (stock / staged / injected / restored)' -ForegroundColor Yellow
        Write-Host '   [H] Post-patch regen helper (heisha / Midnight)' -ForegroundColor Yellow
        Write-Host '   [R] Restore / clean AIO changes (troubleshooting)' -ForegroundColor Yellow
        Write-Host '   [G] Graphics profiles (GameOption)               [user pack]' -ForegroundColor Magenta
        Write-Host '   [N] NVIDIA .nip (Profile Inspector)              [user pack]' -ForegroundColor Magenta
        Write-Host '   [X] EXPERIMENTAL upscale (official OptiScaler bundle) *** NOT SAFE ***' -ForegroundColor Red
        Write-Host '   [8] 2026 guide + feature labels' -ForegroundColor Yellow
        Write-Host '   [9] Verify pack integrity' -ForegroundColor Yellow
        Write-Host '   [0] Exit' -ForegroundColor DarkGray
        Write-Host ''
        $c = Read-Host '  Select'
        switch ($c.Trim().ToUpperInvariant()) {
            '1' { Set-PazFolder }
            '2' { Configure-ModChoices }
            '3' { [void](Deploy-Midnight) }
            '4' { Run-PartCutGen }
            '5' { Run-MetaInjector }
            '6' { Run-FullWizard }
            'A' { [void](Apply-AllRestoredChoices) }
            '7' { Open-FilesToPatch }
            'S' {
                Write-Banner
                if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
                    Write-Err 'Set PAZ first (menu 1).'
                } else {
                    Show-PazInjectStatus -PazFolder ([string]$Script:Config.pazFolder) -Detailed
                }
                Pause-Any
            }
            'H' { Show-HeishaRegenHelper }
            'R' { Restore-UneditedGameFiles }
            'G' { Apply-GraphicsProfile }
            'N' { Apply-NvidiaProfile }
            'X' { Show-ExperimentalDlssMenu }
            '8' { Show-Guide2026 }
            '9' { Show-VerifyPack }
            '0' { return }
            default { Write-Warn 'Unknown option.'; Start-Sleep -Milliseconds 600 }
        }
    }
}

try {
    Load-Config
    Show-MainMenu
} catch {
    Write-Host ''
    Write-Err $_.Exception.Message
    if ($_.ScriptStackTrace) {
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host 'Press any key to exit...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

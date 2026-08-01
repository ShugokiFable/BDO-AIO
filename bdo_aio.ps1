#Requires -Version 5.1
# BDO Modding AIO - self-contained 2026 installer (everything under this folder)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
$Script:ResoreplessExe = 'Z:\Backup\BDO\heisha\contrib\resorepless-v3.6f\resorepless.exe'
$Script:PazUnpackerExe = 'Z:\Backup\BDO\PAZ-UnpackerV2.6.0\PAZ-Unpacker.exe'

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
$Script:Config = $null

$Script:BodySizePresets = [ordered]@{
    'vanilla'  = 'Vanilla limits (max 1.25)'
    'mild'     = 'Mild unlock (max 1.75)'
    'high'     = 'High unlock (max 2.5) — classic Resorepless-style'
    'extreme'  = 'Extreme (max 3.0) — may clip badly'
}

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
    'GameOption_Remastered_1440p.txt'           = 'Remastered 1440p - best safe native gameplay'
    'GameOption_Remastered_DLDSR_4K.txt'         = 'Remastered DLDSR 4K - best IQ on 1440p monitor (needs NVIDIA DSR 2.25x)'
    'GameOption_Ultra_Screenshot_DLDSR_4K.txt'  = 'Ultra screenshot/video only - NOT for normal play'
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
    Write-Host '   BDO MODDING AIO  |  Self-contained  |  2026 pipeline' -ForegroundColor White
    Write-Host '   Mods + GFX + NIP  |  [X] EXPERIMENTAL DLSS = NOT SAFE' -ForegroundColor DarkCyan
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
            bodySizePreset  = 'high'
            bodySizeParts   = 'breasts,butt,thighs,arms,legs,pelvis,spine'
            bodySizeMin     = $null
            bodySizeDefault = $null
            bodySizeMax     = $null
            hideGloves      = $false
            hideBoots       = $false
            hideHelmets     = $false
            hideWeapons     = $false
            hideStockings   = $false
            pubicHairStyle  = 'none'
            censorshipTier  = 'off'
            female3dVagina  = $false
            malePenisMode   = 'none'
            penisWarrior    = 'none'
            penisBerserker  = 'none'
            penisMusa       = 'none'
            penisWizard     = 'none'
            penisNinja      = 'none'
            penisStriker    = 'none'
            lastRun         = $null
        }
    }
    foreach ($p in @('pazFolder', 'gender', 'armor', 'xyzwCollections', 'npiPath', 'bodySizePreset', 'bodySizeParts', 'bodySizeMin', 'bodySizeDefault', 'bodySizeMax', 'hideGloves', 'hideBoots', 'hideHelmets', 'hideWeapons', 'hideStockings', 'pubicHairStyle', 'censorshipTier', 'female3dVagina', 'malePenisMode', 'penisWarrior', 'penisBerserker', 'penisMusa', 'penisWizard', 'penisNinja', 'penisStriker', 'lastRun')) {
        if (-not ($Script:Config.PSObject.Properties.Name -contains $p)) {
            $val = switch ($p) {
                'gender' { 'F' }
                'armor'  { 'A' }
                'xyzwCollections' { $true }
                'bodySizePreset' { 'high' }
                'bodySizeParts' { 'breasts,butt,thighs,arms,legs,pelvis,spine' }
                'hideGloves' { $false }
                'hideBoots' { $false }
                'hideHelmets' { $false }
                'hideWeapons' { $false }
                'hideStockings' { $false }
                'pubicHairStyle' { 'none' }
                'censorshipTier' { 'off' }
                'female3dVagina' { $false }
                'malePenisMode' { 'none' }
                'penisWarrior' { 'none' }
                'penisBerserker' { 'none' }
                'penisMusa' { 'none' }
                'penisWizard' { 'none' }
                'penisNinja' { 'none' }
                'penisStriker' { 'none' }
                default { $null }
            }
            if ($null -eq $val -and $p -notin @('bodySizeMin', 'bodySizeDefault', 'bodySizeMax', 'lastRun')) {
                if ($p -match '^hide') { $val = $false } else { $val = '' }
            }
            Add-Member -InputObject $Script:Config -NotePropertyName $p -NotePropertyValue $val
        }
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
        bodySizeMin     = $Script:Config.bodySizeMin
        bodySizeDefault = $Script:Config.bodySizeDefault
        bodySizeMax     = $Script:Config.bodySizeMax
        hideGloves      = [bool]$Script:Config.hideGloves
        hideBoots       = [bool]$Script:Config.hideBoots
        hideHelmets     = [bool]$Script:Config.hideHelmets
        hideWeapons     = [bool]$Script:Config.hideWeapons
        hideStockings   = [bool]$Script:Config.hideStockings
        pubicHairStyle  = [string]$Script:Config.pubicHairStyle
        censorshipTier  = [string]$Script:Config.censorshipTier
        female3dVagina  = [bool]$Script:Config.female3dVagina
        malePenisMode   = [string]$Script:Config.malePenisMode
        penisWarrior    = [string]$Script:Config.penisWarrior
        penisBerserker  = [string]$Script:Config.penisBerserker
        penisMusa       = [string]$Script:Config.penisMusa
        penisWizard     = [string]$Script:Config.penisWizard
        penisNinja      = [string]$Script:Config.penisNinja
        penisStriker    = [string]$Script:Config.penisStriker
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
    $missing = @()
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
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) {
        Write-Ok ("Python found: " + $py.Source)
        return $true
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
        $py2 = Get-Command python -ErrorAction SilentlyContinue
        if ($py2) { Write-Ok 'Python is available now.'; return $true }
    }
    return $false
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
    } elseif ($paz) {
        Write-Warn ("Game PAZ  : " + $paz + "  (pad00000.meta missing - check path)")
    } else {
        Write-Warn 'Game PAZ  : not set (user game folder only - not bundled)'
    }

    $gfx = Test-GraphicsReady
    if ($gfx.Ok) {
        Write-Ok ("Graphics  : " + $Script:GraphicsDir + "  (3 GameOption profiles)")
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
        $eff = Get-EffectiveBodySizeValues
        Write-Host ("  Body size: {0}  min={1:0.##} def={2:0.##} max={3:0.##}" -f $eff.preset, $eff.min, $eff.def, $eff.max) -ForegroundColor Gray
        Write-Host ("  Body parts: " + $(if ($Script:Config.bodySizeParts) { $Script:Config.bodySizeParts } else { 'all' })) -ForegroundColor Gray
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
    Write-Host '  FULL OPTIONS HUB (Restored + modern)' -ForegroundColor White
    Write-Host '  ------------------------------------' -ForegroundColor DarkGray
    Write-Info 'Combines Midnight 2026 choices + Resorepless-style body size limits.'
    Write-Host ''
    Write-Host '   [1] Gender + armor hide + collections  (Midnight)' -ForegroundColor Cyan
    Write-Host '   [2] Body size LIMITS (raise max breast/hip/etc)' -ForegroundColor Green
    Write-Host '   [3] Apply body size patch now' -ForegroundColor Green
    Write-Host '   [4] Slot hide toggles (gloves/boots/helmets/weapons/stockings)' -ForegroundColor Green
    Write-Host '   [5] Apply slot hide patch now' -ForegroundColor Green
    Write-Host '   [6] Pubic hair style (LEGACY textures, old classes best)' -ForegroundColor Magenta
    Write-Host '   [7] Apply pubic hair now' -ForegroundColor Magenta
    Write-Host '   [C] Censorship tier presets (LEGACY texture packs)' -ForegroundColor Magenta
    Write-Host '   [V] Penis / 3D vagina menus (LEGACY mesh packs)' -ForegroundColor Magenta
    Write-Host '   [8] Show Available vs Legacy option matrix' -ForegroundColor Yellow
    Write-Host '   [9] Launch LEGACY Resorepless.exe (old classes only)' -ForegroundColor DarkYellow
    Write-Host '   [P] Launch PAZ Unpacker' -ForegroundColor Cyan
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
        '8' { Show-OptionsMatrix }
        '9' { Launch-LegacyResorepless }
        'P' { Launch-PazUnpacker }
        default { return }
    }
}

function Configure-CensorshipTier {
    Write-Banner
    Write-Host '  CENSORSHIP TIER PRESETS (LEGACY texture packs)' -ForegroundColor Magenta
    Write-Host '  ----------------------------------------------' -ForegroundColor DarkGray
    Write-Info 'Resorepless armor under-layer / built-in panty texture swaps.'
    Write-Warn 'Best on older outfits (Tamer/Ranger/DK/Kuno). New pearl gear often needs Armor=All instead.'
    Write-Host ''
    Write-Host '    [0] Off' -ForegroundColor DarkGray
    Write-Host '    [1] Minimal  — some Tamer/Ranger built-in panties' -ForegroundColor Cyan
    Write-Host '    [2] Medium   — + upper undercovers / more decals (RECOMMENDED if using)' -ForegroundColor Green
    Write-Host '    [3] High     — same texture set as medium (full armor hide covers pants models)' -ForegroundColor Cyan
    $t = Read-Choice 'Tier' @('0', '1', '2', '3')
    $Script:Config.censorshipTier = switch ($t) {
        '0' { 'off' }
        '1' { 'minimal' }
        '2' { 'medium' }
        '3' { 'high' }
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
    Write-Banner
    Write-Host '  Apply censorship pack' -ForegroundColor Magenta
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) { Write-Err 'Set PAZ first.'; Pause-Any; return }
    $tier = [string]$Script:Config.censorshipTier
    if (-not $tier -or $tier -eq 'off') { Write-Warn 'Tier is off.'; Pause-Any; return }
    if (-not (Test-Path $Script:CensorshipRoot)) { Write-Err "Missing $($Script:CensorshipRoot)"; Pause-Any; return }
    if (-not (Ensure-Python)) { Pause-Any; return }
    $out = Join-Path $Script:Config.pazFolder ("files_to_patch\_censorship_" + $tier)
    Write-Info ("Tier=$tier out=$out")
    if (-not (Read-YesNo 'Copy texture pack?' $true)) { Pause-Any; return }
    & python $Script:CensorshipTool --tier $tier --pack-root $Script:CensorshipRoot --out $out
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Write-Err "Exit $LASTEXITCODE" } else { Write-Ok 'Censorship pack ready. Meta Inject after Midnight.'; Ensure-ToolsInPaz }
    Pause-Any
}

function Read-PenisStyle([string]$label, [string]$current) {
    Write-Host ''
    Write-Host ("  " + $label + " penis style  (current: " + $current + ")") -ForegroundColor White
    Write-Host '    [0] none   [1] normal   [2] hard' -ForegroundColor Cyan
    $c = Read-Choice 'Style' @('0', '1', '2')
    return $(switch ($c) { '0' { 'none' } '1' { 'normal' } '2' { 'hard' } })
}

function Configure-GenitalMenus {
    Write-Banner
    Write-Host '  PENIS / 3D VAGINA (LEGACY mesh packs)' -ForegroundColor Magenta
    Write-Host '  ------------------------------------' -ForegroundColor DarkGray
    Write-Warn 'Resorepless-era only. Missing Seraph/Deadeye/Agent/etc. Penis skin often mismatches body tone.'
    Write-Host ''
    Write-Host '  FEMALE — 3D vagina nude meshes' -ForegroundColor White
    $Script:Config.female3dVagina = Read-YesNo 'Enable 3D vagina nude PAC pack (old female classes)?' ([bool]$Script:Config.female3dVagina)

    Write-Host ''
    Write-Host '  MALE — penis meshes' -ForegroundColor White
    Write-Host '    [1] All male classes same style (easy)' -ForegroundColor Green
    Write-Host '    [2] Per-class styles (Warrior/Berserker/Musa/Wizard/Ninja/Striker)' -ForegroundColor Cyan
    Write-Host '    [3] All off' -ForegroundColor DarkGray
    $m = Read-Choice 'Male mode' @('1', '2', '3')
    if ($m -eq '3') {
        $Script:Config.malePenisMode = 'none'
        foreach ($k in @('penisWarrior', 'penisBerserker', 'penisMusa', 'penisWizard', 'penisNinja', 'penisStriker')) {
            $Script:Config.$k = 'none'
        }
    } elseif ($m -eq '1') {
        $all = Read-PenisStyle 'All males' $(if ($Script:Config.malePenisMode -in @('normal', 'hard')) { $Script:Config.malePenisMode } else { 'normal' })
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
    Write-Host ("  female3dVagina = " + $Script:Config.female3dVagina) -ForegroundColor Gray
    Write-Host ("  malePenisMode  = " + $Script:Config.malePenisMode) -ForegroundColor Gray
    if (Read-YesNo 'Apply genital mesh packs to files_to_patch now?' $true) {
        Apply-GenitalPacks
    } else {
        Pause-Any
    }
}

function Apply-GenitalPacks {
    Write-Banner
    Write-Host '  Apply genital packs (LEGACY)' -ForegroundColor Magenta
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

    $out = Join-Path $Script:Config.pazFolder 'files_to_patch\_genital_legacy'
    Write-Info ("female_3d=$f3d male=$maleArg")
    Write-Info ("out=$out")
    if (-not (Read-YesNo 'Copy legacy genital packs?' $true)) { Pause-Any; return }

    & python $Script:GenitalTool --pack-root $Script:GenitalRoot --out $out --female-3d-vagina $f3d --male-penis $maleArg
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
    Write-Host ''
    $Script:Config.hideGloves = Read-YesNo 'Hide GLOVES / hands gear?' ([bool]$Script:Config.hideGloves)
    $Script:Config.hideBoots = Read-YesNo 'Hide BOOTS / shoes?' ([bool]$Script:Config.hideBoots)
    $Script:Config.hideHelmets = Read-YesNo 'Hide HELMETS (may affect some hair/hel combos)?' ([bool]$Script:Config.hideHelmets)
    $Script:Config.hideWeapons = Read-YesNo 'Hide WEAPONS (main/sub/awakening meshes)?' ([bool]$Script:Config.hideWeapons)
    $Script:Config.hideStockings = Read-YesNo 'Hide STOCKINGS (best-effort name match)?' ([bool]$Script:Config.hideStockings)
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
    Write-Banner
    Write-Host '  Apply slot hide patch' -ForegroundColor White
    Write-Host '  ---------------------' -ForegroundColor DarkGray
    if (-not (Test-IsPazFolder $Script:Config.pazFolder)) {
        Write-Err 'Set PAZ first (menu 1).'
        Pause-Any
        return
    }
    $slots = @(Get-EnabledHideSlots)
    if ($slots.Count -eq 0) {
        Write-Warn 'No slots enabled. Turn some on in menu 2 option 4 first.'
        Pause-Any
        return
    }
    if (-not (Test-Path -LiteralPath $Script:SlotHideTool)) {
        Write-Err ("Missing " + $Script:SlotHideTool)
        Pause-Any
        return
    }
    if (-not (Ensure-Python)) { Pause-Any; return }

    $gender = [string]$Script:Config.gender
    if ($gender -notin @('F', 'M', 'B')) { $gender = 'B' }
    $out = Join-Path $Script:Config.pazFolder 'files_to_patch'
    Write-Info ("Slots  : " + ($slots -join ', '))
    Write-Info ("Gender : " + $gender)
    Write-Info ("Output : " + $out)
    Write-Warn 'Scans full meta (can take a minute). Then run PartCutGen + Meta Injector.'
    if (-not (Read-YesNo 'Run slot hide patcher?' $true)) { Pause-Any; return }

    $pyArgs = @(
        $Script:SlotHideTool,
        '--paz', [string]$Script:Config.pazFolder,
        '--out', $out,
        '--slots', ($slots -join ','),
        '--gender', $gender
    )
    try {
        & python @pyArgs
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Err ("Exit code " + $LASTEXITCODE)
        } else {
            Write-Ok 'Slot hide folders written under files_to_patch\_slot_hide_*'
            Ensure-ToolsInPaz
        }
    } catch {
        Write-Err $_.Exception.Message
    }
    Pause-Any
}

function Configure-PubicHair {
    Write-Banner
    Write-Host '  PUBIC HAIR STYLE (LEGACY)' -ForegroundColor Magenta
    Write-Host '  -------------------------' -ForegroundColor DarkGray
    Write-Warn 'Best on older female nude textures (Tamer/DK/Ranger/Sorc/Witch bins).'
    Write-Warn 'Seraph/Deadeye/etc. skip if no matching base+bin. Not a full new-class system.'
    Write-Host ''
    if (-not (Test-Path -LiteralPath (Join-Path $Script:PubicHairRoot 'offsets.bin'))) {
        Write-Err ("Pubic hair pack missing: " + $Script:PubicHairRoot)
        Write-Info 'Expected tools\pubic_hair\ from Resorepless resources.'
        Pause-Any
        return
    }

    $keys = @($Script:PubicHairStyles.Keys)
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $k = $keys[$i]
        $mark = if ($k -eq 'full_bush') { ' (popular)' } elseif ($k -eq 'none') { '' } else { '' }
        $col = if ($i -eq 0) { 'DarkGray' } else { 'Cyan' }
        Write-Host ("    [{0}] {1}{2}" -f ($i + 1), $Script:PubicHairStyles[$k], $mark) -ForegroundColor $col
    }
    Write-Host '    [P] Open preview image (if present)' -ForegroundColor Yellow
    $pick = (Read-Host '  Select style number').Trim().ToUpperInvariant()
    if ($pick -eq 'P') {
        $prev = Join-Path $Script:PubicHairRoot 'preview.jpg'
        if (Test-Path $prev) { Start-Process $prev } else { Write-Warn 'preview.jpg missing' }
        Pause-Any
        Configure-PubicHair
        return
    }
    if ($pick -notmatch '^\d+$') {
        Write-Warn 'Cancelled.'
        Pause-Any
        return
    }
    $idx = [int]$pick - 1
    if ($idx -lt 0 -or $idx -ge $keys.Count) {
        Write-Warn 'Invalid.'
        Pause-Any
        return
    }
    $Script:Config.pubicHairStyle = $keys[$idx]
    Save-Config
    Write-Ok ("Pubic hair style: " + $Script:PubicHairStyles[$Script:Config.pubicHairStyle])
    if ($Script:Config.pubicHairStyle -ne 'none' -and (Read-YesNo 'Apply pubic hair textures now?' $true)) {
        Apply-PubicHair
    } else {
        Pause-Any
    }
}

function Apply-PubicHair {
    Write-Banner
    Write-Host '  Apply pubic hair' -ForegroundColor Magenta
    Write-Host '  ----------------' -ForegroundColor DarkGray
    $style = [string]$Script:Config.pubicHairStyle
    if (-not $style -or $style -eq 'none') {
        Write-Warn 'Style is none — pick a style first (menu 2 option 6).'
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
    $out = Join-Path $Script:Config.pazFolder ("files_to_patch\_pubic_hair\" + $style)
    Write-Info ("Style : " + $style)
    Write-Info ("Out   : " + $out)
    if (-not (Read-YesNo 'Merge hair bins onto nude DDS and write files_to_patch?' $true)) {
        Pause-Any
        return
    }
    $pyArgs = @(
        $Script:PubicHairTool,
        '--style', $style,
        '--hair-root', $Script:PubicHairRoot,
        '--base-roots', $baseRoots,
        '--out', $out
    )
    try {
        & python @pyArgs
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

function Get-BodySizePresetValues {
    param([string]$Name)
    switch ($Name) {
        'vanilla' { return @{ min = 0.90; def = 1.00; max = 1.25 } }
        'mild'    { return @{ min = 0.85; def = 1.00; max = 1.75 } }
        'high'    { return @{ min = 0.80; def = 1.05; max = 2.50 } }
        'extreme' { return @{ min = 0.70; def = 1.10; max = 3.00 } }
        default   { return @{ min = 0.80; def = 1.05; max = 2.50 } }
    }
}

function Get-EffectiveBodySizeValues {
    $preset = [string]$Script:Config.bodySizePreset
    if (-not $preset) { $preset = 'high' }
    if ($preset -eq 'custom') {
        $min = $Script:Config.bodySizeMin
        $def = $Script:Config.bodySizeDefault
        $max = $Script:Config.bodySizeMax
        if ($null -eq $min) { $min = 0.80 }
        if ($null -eq $def) { $def = 1.05 }
        if ($null -eq $max) { $max = 2.50 }
        return @{
            preset = 'custom'
            min    = [double]$min
            def    = [double]$def
            max    = [double]$max
        }
    }
    $v = Get-BodySizePresetValues $preset
    return @{
        preset = $preset
        min    = $v.min
        def    = $v.def
        max    = $v.max
    }
}

function Test-BodySizeOrder {
    param([double]$Min, [double]$Def, [double]$Max)
    return ($Min -lt $Def -and $Def -lt $Max)
}

function Configure-BodySizeLimits {
    Write-Banner
    Write-Host '  BODY SIZE LIMITS (char create / beauty salon)' -ForegroundColor White
    Write-Host '  ---------------------------------------------' -ForegroundColor DarkGray
    Write-Info 'Raises Min / Default / Max so in-game sliders can go further (Resorepless-style).'
    Write-Warn 'After inject: beauty salon or new character. Tamer breasts often ignore this.'
    Write-Host ''
    Write-Host '  Easy path = recommended presets. Power path = type any custom numbers.' -ForegroundColor Gray
    Write-Host ''

    $cur = Get-EffectiveBodySizeValues
    Write-Host ("  Current: preset={0}  min={1:0.##}  default={2:0.##}  max={3:0.##}" -f $cur.preset, $cur.min, $cur.def, $cur.max) -ForegroundColor DarkCyan
    Write-Host ("  Parts  : " + $(if ($Script:Config.bodySizeParts) { $Script:Config.bodySizeParts } else { 'all' })) -ForegroundColor DarkCyan
    Write-Host ''

    Write-Host '  SIZE VALUES' -ForegroundColor White
    Write-Host '    [1] vanilla   0.90 / 1.00 / 1.25   stock game' -ForegroundColor Cyan
    Write-Host '    [2] mild      0.85 / 1.00 / 1.75' -ForegroundColor Cyan
    Write-Host '    [3] high      0.80 / 1.05 / 2.50   RECOMMENDED (classic)' -ForegroundColor Green
    Write-Host '    [4] extreme   0.70 / 1.10 / 3.00   may clip hard' -ForegroundColor Yellow
    Write-Host '    [5] CUSTOM    type your own Min / Default / Max' -ForegroundColor Magenta
    Write-Host '    [6] Keep current values' -ForegroundColor DarkGray
    $p = Read-Choice 'Choice' @('1', '2', '3', '4', '5', '6')

    switch ($p) {
        '1' {
            $Script:Config.bodySizePreset = 'vanilla'
            $Script:Config.bodySizeMin = $null
            $Script:Config.bodySizeDefault = $null
            $Script:Config.bodySizeMax = $null
        }
        '2' {
            $Script:Config.bodySizePreset = 'mild'
            $Script:Config.bodySizeMin = $null
            $Script:Config.bodySizeDefault = $null
            $Script:Config.bodySizeMax = $null
        }
        '3' {
            $Script:Config.bodySizePreset = 'high'
            $Script:Config.bodySizeMin = $null
            $Script:Config.bodySizeDefault = $null
            $Script:Config.bodySizeMax = $null
        }
        '4' {
            $Script:Config.bodySizePreset = 'extreme'
            $Script:Config.bodySizeMin = $null
            $Script:Config.bodySizeDefault = $null
            $Script:Config.bodySizeMax = $null
        }
        '5' {
            Write-Host ''
            Write-Host '  CUSTOM VALUES' -ForegroundColor Magenta
            Write-Info 'Rule: Min < Default < Max   (examples: min 0.8, default 1.05, max 2.5)'
            Write-Info 'Old Resorepless UI suggested max around 2.5; higher can look extreme/clip.'
            $base = Get-EffectiveBodySizeValues
            while ($true) {
                $min = Read-FloatValue -Prompt 'Min size' -Default $base.min -MinAllowed -2.0 -MaxAllowed 5.0
                $def = Read-FloatValue -Prompt 'Default size (slider middle-ish)' -Default $base.def -MinAllowed -2.0 -MaxAllowed 5.0
                $max = Read-FloatValue -Prompt 'Max size (what you care about most)' -Default $base.max -MinAllowed 0.1 -MaxAllowed 10.0
                if (Test-BodySizeOrder -Min $min -Def $def -Max $max) {
                    $Script:Config.bodySizePreset = 'custom'
                    $Script:Config.bodySizeMin = $min
                    $Script:Config.bodySizeDefault = $def
                    $Script:Config.bodySizeMax = $max
                    Write-Ok ("Custom saved: min={0:0.##} default={1:0.##} max={2:0.##}" -f $min, $def, $max)
                    break
                }
                Write-Err 'Need Min < Default < Max. Try again.'
            }
        }
        '6' {
            Write-Info 'Keeping existing size values.'
        }
    }

    # Optional fine-tune after preset (friendly: ask once)
    if ($p -in @('1', '2', '3', '4')) {
        Write-Host ''
        if (Read-YesNo 'Fine-tune numbers after this preset (custom override)?' $false) {
            $base = Get-EffectiveBodySizeValues
            while ($true) {
                $min = Read-FloatValue -Prompt 'Min size' -Default $base.min -MinAllowed -2.0 -MaxAllowed 5.0
                $def = Read-FloatValue -Prompt 'Default size' -Default $base.def -MinAllowed -2.0 -MaxAllowed 5.0
                $max = Read-FloatValue -Prompt 'Max size' -Default $base.max -MinAllowed 0.1 -MaxAllowed 10.0
                if (Test-BodySizeOrder -Min $min -Def $def -Max $max) {
                    $Script:Config.bodySizePreset = 'custom'
                    $Script:Config.bodySizeMin = $min
                    $Script:Config.bodySizeDefault = $def
                    $Script:Config.bodySizeMax = $max
                    Write-Ok ("Custom override: min={0:0.##} default={1:0.##} max={2:0.##}" -f $min, $def, $max)
                    break
                }
                Write-Err 'Need Min < Default < Max. Try again.'
            }
        }
    }

    Write-Host ''
    Write-Host '  BODY PARTS' -ForegroundColor White
    Write-Host '    [1] Breasts only' -ForegroundColor Cyan
    Write-Host '    [2] Breasts + butt + thighs   (RECOMMENDED for most people)' -ForegroundColor Green
    Write-Host '    [3] ALL parts (breasts, butt, thighs, arms, legs, pelvis, spine)' -ForegroundColor Cyan
    Write-Host '    [4] CUSTOM list (type names yourself)' -ForegroundColor Magenta
    Write-Host '    [5] Keep current parts list' -ForegroundColor DarkGray
    $bp = Read-Choice 'Parts choice' @('1', '2', '3', '4', '5')
    switch ($bp) {
        '1' { $Script:Config.bodySizeParts = 'breasts' }
        '2' { $Script:Config.bodySizeParts = 'breasts,butt,thighs' }
        '3' { $Script:Config.bodySizeParts = 'breasts,butt,thighs,arms,legs,pelvis,spine' }
        '4' {
            Write-Host ''
            Write-Info 'Valid names: breasts, butt, thighs, arms, legs, pelvis, spine'
            Write-Info 'Example: breasts,butt   or   breasts,thighs,arms'
            $legal = @('breasts', 'butt', 'thighs', 'arms', 'legs', 'pelvis', 'spine')
            while ($true) {
                $raw = (Read-Host '  Parts (comma-separated)').Trim().ToLowerInvariant()
                if ([string]::IsNullOrEmpty($raw)) {
                    Write-Warn 'Empty — try again or use a preset choice.'
                    continue
                }
                $tokens = @($raw -split '[,;\s]+' | Where-Object { $_ })
                $bad = @($tokens | Where-Object { $_ -notin $legal })
                if ($bad.Count -gt 0) {
                    Write-Warn ("Unknown: " + ($bad -join ', '))
                    continue
                }
                if ($tokens.Count -eq 0) { continue }
                $Script:Config.bodySizeParts = ($tokens | Select-Object -Unique) -join ','
                Write-Ok ("Parts: " + $Script:Config.bodySizeParts)
                break
            }
        }
        '5' { Write-Info 'Keeping existing parts list.' }
    }

    Save-Config
    $eff = Get-EffectiveBodySizeValues
    Write-Host ''
    Write-Ok 'Body size settings saved.'
    Write-Host ("  Preset : " + $eff.preset) -ForegroundColor Gray
    Write-Host ("  Min    : {0:0.##}" -f $eff.min) -ForegroundColor Gray
    Write-Host ("  Default: {0:0.##}" -f $eff.def) -ForegroundColor Gray
    Write-Host ("  Max    : {0:0.##}" -f $eff.max) -ForegroundColor Gray
    Write-Host ("  Parts  : " + $Script:Config.bodySizeParts) -ForegroundColor Gray
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

    $eff = Get-EffectiveBodySizeValues
    $parts = [string]$Script:Config.bodySizeParts
    if (-not $parts) { $parts = 'breasts,butt,thighs,arms,legs,pelvis,spine' }
    $out = Join-Path $Script:Config.pazFolder 'files_to_patch\_body_size_limits'

    if (-not (Test-BodySizeOrder -Min $eff.min -Def $eff.def -Max $eff.max)) {
        Write-Err 'Invalid sizes (need Min < Default < Max). Re-run menu 2 body size config.'
        Pause-Any
        return
    }

    Write-Info ("PAZ     : " + $Script:Config.pazFolder)
    Write-Info ("Preset  : " + $eff.preset)
    Write-Info ("Min     : {0:0.##}" -f $eff.min)
    Write-Info ("Default : {0:0.##}" -f $eff.def)
    Write-Info ("Max     : {0:0.##}" -f $eff.max)
    Write-Info ("Parts   : " + $parts)
    Write-Info ("Output  : " + $out)
    Write-Warn 'Extracts ~75 customizationboneparamdesc.xml from live game (takes a minute).'
    if (-not (Read-YesNo 'Run body size patcher with these values?' $true)) {
        Pause-Any
        return
    }

    # Always pass explicit numbers so custom + presets both go through the same path
    $pyArgs = @(
        $Script:BodySizeTool,
        '--paz', [string]$Script:Config.pazFolder,
        '--out', $out,
        '--preset', 'high',
        '--min', ("{0}" -f $eff.min),
        '--default', ("{0}" -f $eff.def),
        '--max', ("{0}" -f $eff.max),
        '--parts', $parts
    )
    try {
        & python @pyArgs
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
    Write-Host '  Available vs Legacy options' -ForegroundColor White
    Write-Host '  ---------------------------' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  AVAILABLE IN THIS AIO (2026)' -ForegroundColor Green
    Write-Host '  ----------------------------' -ForegroundColor DarkGray
    Write-Host '  Gender F/M/Both'
    Write-Host '  Armor hide: All / Pearl / Free / Underwear-only'
    Write-Host '  Slot hide toggles: gloves, boots, helmets, weapons, stockings'
    Write-Host '  Underwear hide + nude body (Suzu + TheGreatSage) through Seraph'
    Write-Host '  XYZW outfit collections on/off'
    Write-Host '  Body size LIMITS min/default/max (+ custom numbers)'
    Write-Host '  Pubic hair styles (legacy bins; best on older female nudes)'
    Write-Host '  Censorship tiers minimal/medium/high (legacy texture packs)'
    Write-Host '  3D vagina + penis packs (legacy; old classes; per-class penis styles)'
    Write-Host '  GameOption graphics profiles (menu G)'
    Write-Host '  NVIDIA .nip driver profile (menu N)'
    Write-Host '  PartCutGen + Meta Injector pipeline'
    Write-Host ''
    Write-Host '  STILL LIMITED' -ForegroundColor Yellow
    Write-Host '  -------------' -ForegroundColor DarkGray
    Write-Host '  Genital packs: no Seraph/Deadeye/Agent; penis skin-tone mismatch'
    Write-Host '  Censorship textures: old outfits — prefer Armor=All for modern gear'
    Write-Host ''
    Write-Host '  NOT SUPPORTED' -ForegroundColor Red
    Write-Host '  -------------' -ForegroundColor DarkGray
    Write-Host '  Agent / Wukong full body packs until Midnight updates'
    Write-Host '  Shai nude/underwear (skipped by design)'
    Write-Host '  Anti-cheat stealth for injectors'
    Write-Host ''
    Pause-Any
}

function Launch-LegacyResorepless {
    Write-Banner
    Write-Host '  LEGACY Resorepless 3.6f' -ForegroundColor Yellow
    Write-Host '  -----------------------' -ForegroundColor DarkGray
    Write-Warn 'Abandoned ~2018. Missing modern classes (Seraph, Deadeye, Woosa, …).'
    Write-Warn 'Use only for old-class experiments. Prefer AIO body size + Midnight for 2026.'
    $exe = $Script:ResoreplessExe
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Err ("Not found: " + $exe)
        Write-Info 'Expected under Z:\Backup\BDO\heisha\contrib\resorepless-v3.6f\'
        Pause-Any
        return
    }
    if (Read-YesNo 'Launch resorepless.exe anyway?' $false) {
        Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe)
        Write-Ok 'Launched. Configure sizes there if you insist on the old UI.'
    }
    Pause-Any
}

function Launch-PazUnpacker {
    $exe = $Script:PazUnpackerExe
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Err ("Not found: " + $exe)
        Pause-Any
        return
    }
    Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe)
    Write-Ok 'PAZ Unpacker launched.'
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
    Write-Info ("Args     : -g " + $g + " -a " + $a + " " + $xyzwArg)
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
        [string]$Script:Config.pazFolder
    )

    Write-Host ''
    Write-Info 'Running Midnight deploy (first run can take a while)...'
    try {
        & python @pyArgs
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
    Ensure-ToolsInPaz
    $exe = Join-Path $Script:Config.pazFolder 'Meta Injector.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Err ("Missing: " + $exe)
        Pause-Any
        return
    }
    Write-Info ("Launching: " + $exe)
    Start-Process -FilePath $exe -WorkingDirectory $Script:Config.pazFolder
    Write-Ok 'Meta Injector launched. Use its UI to patch, then start the game.'
    Pause-Any
}

function Run-FullWizard {
    Write-Banner
    Write-Host '  Full easy install wizard' -ForegroundColor White
    Write-Host '  ------------------------' -ForegroundColor DarkGray
    Write-Info 'This walks through everything in order.'
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
    if (Read-YesNo 'Change these choices before deploy?' $false) {
        Configure-ModChoices
    }

    if (-not (Deploy-Midnight)) { return }

    Write-Banner
    Write-Host '  Next: PartCutGen' -ForegroundColor White
    if (Read-YesNo 'Launch PartCutGen now?' $true) {
        $exe = Join-Path $Script:Config.pazFolder 'PartCutGen.exe'
        if (Test-Path -LiteralPath $exe) {
            Start-Process -FilePath $exe -WorkingDirectory $Script:Config.pazFolder
            Write-Ok 'Finish PartCutGen in its window, then come back here.'
            Pause-Any
        }
    }

    Write-Banner
    Write-Host '  Next: Meta Injector' -ForegroundColor White
    Write-Warn 'Game + launcher must be closed.'
    if (Read-YesNo 'Launch Meta Injector now?' $true) {
        $exe = Join-Path $Script:Config.pazFolder 'Meta Injector.exe'
        if (Test-Path -LiteralPath $exe) {
            Start-Process -FilePath $exe -WorkingDirectory $Script:Config.pazFolder
            Write-Ok 'Finish Meta Injector, then start BDO and check in-game.'
        }
    }

    Write-Host ''
    Write-Ok 'Wizard finished.'
    Write-Info 'After every official BDO patch: run this wizard again (or menu 3 then 4 then 5).'
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
    Write-Info 'Applies a max-quality profile to Documents\Black Desert\GameOption.txt'
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
    if ($fileName -match 'Ultra_Screenshot') {
        Write-Host ''
        Write-Warn 'Ultra screenshot profile is VERY expensive - not for normal grinding.'
    }

    Write-Host ''
    if (-not (Read-YesNo 'Apply this profile now? (backs up existing GameOption.txt)' $true)) {
        Write-Warn 'Cancelled.'
        Pause-Any
        return
    }

    try {
        if (-not (Test-Path -LiteralPath $bdoDocs)) {
            New-Item -ItemType Directory -Path $bdoDocs -Force | Out-Null
            Write-Info 'Created Documents\Black Desert folder.'
        }

        if (Test-Path -LiteralPath $target) {
            $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $backup = Join-Path $bdoDocs ("GameOption.backup." + $stamp + ".txt")
            Copy-Item -LiteralPath $target -Destination $backup -Force
            Write-Ok ("Backed up existing file -> " + [IO.Path]::GetFileName($backup))
        }

        Copy-Item -LiteralPath $src -Destination $target -Force
        Write-Ok ("Installed: " + $target)
        Write-Info 'Do NOT mark GameOption.txt read-only (game/patches may update it).'
        Write-Info 'Start the game and verify: Texture High, Remastered/Ultra, TAA, Upscale Off.'
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
    Write-Host '    [1] dlss     (NVIDIA DLSS path — what you want if hardware allows)' -ForegroundColor Cyan
    Write-Host '    [2] auto    (OptiScaler default)' -ForegroundColor Cyan
    Write-Host '    [3] fsr31   (FSR 3.1 — better than game FSR1, no NVIDIA DLSS needed)' -ForegroundColor Cyan
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
    Write-Warn ("Proxy: " + $proxyName + "  |  Upscaler preference: " + $upName)
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
            # skip the long readme noise name if needed; still copy
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

    # If target proxy already is something else, overwrite after backup
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
            $utf8 = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($iniPath, $ini, $utf8)
            Write-Ok ("OptiScaler.ini upscalers set to: " + $upName)
        } catch {
            Write-Warn ("Could not edit OptiScaler.ini: " + $_.Exception.Message)
        }
    }

    # Marker for uninstall awareness
    $marker = Join-Path $gameRoot 'BDO-AIO-EXPERIMENTAL-DLSS.txt'
    @(
        'EXPERIMENTAL / NOT SAFE - installed by BDO-AIO',
        ('Installed: ' + (Get-Date).ToString('s')),
        ('Proxy: ' + $proxyName),
        ('Upscaler: ' + $upName),
        ('Backup: ' + $backupDir),
        'Uninstall via BDO-AIO menu X or delete proxy + OptiScaler/Streamline files.'
    ) | Set-Content -LiteralPath $marker -Encoding UTF8

    Write-Host ''
    Write-Ok 'Experimental install finished.'
    Write-Host '  NEXT STEPS' -ForegroundColor Yellow
    Write-Host '  1. Launch BDO. If it fails to start -> menu X Uninstall immediately.' -ForegroundColor Yellow
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
    Write-Warn 'This deletes OptiScaler proxy DLLs + known Streamline/Opti files from game root.'
    if (-not (Read-YesNo 'Remove experimental DLLs now?' $true)) {
        Pause-Any
        return
    }

    $removed = 0
    foreach ($name in ($Script:OptiProxyNames + $Script:OptiExtraFiles | Select-Object -Unique)) {
        $p = Join-Path $gameRoot $name
        if (Test-Path -LiteralPath $p) {
            # Only remove proxies if they look like OptiScaler (OriginalFilename) when possible
            $isProxy = $Script:OptiProxyNames -contains $name
            $delete = $true
            if ($isProxy) {
                try {
                    $orig = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($p).OriginalFilename
                    if ($orig -and ($orig -ne 'OptiScaler.dll') -and ($name -ne 'version.dll')) {
                        # keep unknown third-party proxy unless user forces - for version we still check
                        if ($orig -notmatch 'OptiScaler') {
                            Write-Warn ("Skipping " + $name + " (OriginalFilename=" + $orig + " — not OptiScaler)")
                            $delete = $false
                        }
                    }
                } catch {}
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
    $marker = Join-Path $gameRoot 'BDO-AIO-EXPERIMENTAL-DLSS.txt'
    if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }

    Write-Ok ("Uninstall pass done. Items removed: " + $removed)
    Write-Info 'If the game still misbehaves, verify/repair game files in the launcher.'
    Write-Info 'Timestamped BDO-AIO-backup-dlss-* folders in game root are left for you to restore manually.'
    Pause-Any
}

function Show-ExperimentalDlssMenu {
    Write-Banner
    Write-Host '  ########################################################' -ForegroundColor Red
    Write-Host '  #  EXPERIMENTAL DLSS / OPTISCALER  —  NOT SAFE         #' -ForegroundColor Red
    Write-Host '  ########################################################' -ForegroundColor Red
    Write-Host ''
    Write-Host '  BDO only ships weak FSR-class upscaling. This section installs' -ForegroundColor Yellow
    Write-Host '  unofficial OptiScaler (+ Streamline) DLLs into the game folder' -ForegroundColor Yellow
    Write-Host '  so you can try DLSS / FSR3 / XeSS. High risk of bans & crashes.' -ForegroundColor Yellow
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
    Write-Host '   [3] INSTALL OptiScaler + Streamline  (EXPERIMENTAL / NOT SAFE)' -ForegroundColor Red
    Write-Host '   [4] UNINSTALL experimental DLLs from game folder' -ForegroundColor Cyan
    Write-Host '   [5] Open optional DLSS Enabler setup EXE (advanced)' -ForegroundColor DarkYellow
    Write-Host '   [6] Open experimental\dlss folder' -ForegroundColor Cyan
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
            Write-Host ''
            Write-Host '  OPTIONAL advanced installer — also EXPERIMENTAL / NOT SAFE.' -ForegroundColor Red
            $setup = Join-Path $Script:ExperimentalDlssDir 'optional\dlss-enabler-setup.exe'
            if (Test-Path -LiteralPath $setup) {
                if (Confirm-ExperimentalDanger) {
                    Start-Process -FilePath $setup
                    Write-Ok 'Launched DLSS Enabler setup. Follow its UI carefully.'
                }
            } else {
                Write-Err ("Missing: " + $setup)
            }
            Pause-Any
        }
        '6' {
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
    Write-Host '  Python 3 on PATH (one-time system install, for mod deploy)'
    Write-Host '  NVIDIA GPU + driver (for .nip import / DLSS path)'
    Write-Host ''
    Write-Host '  NOT needed / not bundled' -ForegroundColor Yellow
    Write-Host '  ------------------------' -ForegroundColor DarkGray
    Write-Host '  Meta Patcher, BDOToolkit, PAZ Browser, PACtool, 3D Converter,'
    Write-Host '  Resorepless, old 0.3.0 pack, SkyrimUpscaler (wrong game)'
    Write-Host ''
    Write-Host '  PIPELINE' -ForegroundColor White
    Write-Host '  --------' -ForegroundColor DarkGray
    Write-Host '  Mods: Deploy (from pack) -> PartCutGen -> Meta Injector -> Launch'
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
        Write-Ok 'All 3 GameOption profiles present.'
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
        Write-Host '  MENU' -ForegroundColor White
        Write-Host '  ----' -ForegroundColor DarkGray
        Write-Host '   [1] Set / find game PAZ folder' -ForegroundColor Cyan
        Write-Host '   [2] FULL OPTIONS (gender/armor + body size max unlock)' -ForegroundColor Cyan
        Write-Host '   [3] Deploy Midnight mods  ->  files_to_patch' -ForegroundColor Cyan
        Write-Host '   [4] Run PartCutGen        (required)' -ForegroundColor Cyan
        Write-Host '   [5] Run Meta Injector     (apply patch)' -ForegroundColor Cyan
        Write-Host '   [6] FULL WIZARD           (easy: all mod steps)' -ForegroundColor Green
        Write-Host '   [7] Open files_to_patch   (add extra mods)' -ForegroundColor Cyan
        Write-Host '   [G] Apply GRAPHICS profile (GameOption pack)' -ForegroundColor Magenta
        Write-Host '   [N] Import NVIDIA .nip    (Profile Inspector)' -ForegroundColor Magenta
        Write-Host '   [X] EXPERIMENTAL DLSS/OptiScaler  *** NOT SAFE ***' -ForegroundColor Red
        Write-Host '   [8] 2026 guide            (what is bundled)' -ForegroundColor Yellow
        Write-Host '   [9] Verify pack integrity (before you publish)' -ForegroundColor Yellow
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
            '7' { Open-FilesToPatch }
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

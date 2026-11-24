# Shared read-only detection helpers. Compatible with Windows PowerShell 5.1.
function Find-Tool([string]$Name) {
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}
function Find-Pix {
    foreach ($root in @("$env:ProgramFiles\Microsoft PIX", "$env:ProgramFiles\Microsoft PIX Preview")) {
        if (Test-Path -LiteralPath $root) {
            $dirs = Get-ChildItem -LiteralPath $root -Directory | Sort-Object LastWriteTime -Descending
            foreach ($dir in $dirs) {
                if (Test-Path -LiteralPath (Join-Path $dir.FullName 'DxDmpMcp.exe')) { return $dir.FullName }
            }
        }
    }
    return $null
}
function Find-SdkTool([string]$Name) {
    $direct = Find-Tool $Name
    if ($direct) { return $direct }
    $pf86 = ${env:ProgramFiles(x86)}
    if (-not $pf86) { return $null }
    $kits = Join-Path $pf86 'Windows Kits\10'
    $candidate = Join-Path $kits "Debuggers\x64\$Name"
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    $bin = Join-Path $kits 'bin'
    if (Test-Path -LiteralPath $bin) {
        foreach ($dir in (Get-ChildItem -LiteralPath $bin -Directory | Sort-Object Name -Descending)) {
            $candidate = Join-Path $dir.FullName "x64\$Name"
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    return $null
}
function Get-VictoryRoot { return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

# PIX 2611.19 uses .NET 10 x64. Inspect the host actually used by PIX,
# not Winget's package inventory or an x86 dotnet on PATH.
function Get-PixRuntimeStatus([string]$PixDir) {
    $minimumAsp = [version]'10.0.0'
    $minimumCore = [version]'10.0.0'
    $supported = $true
    $configPath = Join-Path $PixDir 'DxDmpMcp.runtimeconfig.json'
    if (Test-Path -LiteralPath $configPath) {
        try {
            $options = (Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json).runtimeOptions
            foreach ($framework in (@($options.framework) + @($options.frameworks))) {
                if (-not $framework -or $framework.name -notin @('Microsoft.AspNetCore.App','Microsoft.NETCore.App')) { continue }
                $v = [version]$framework.version
                if ($v.Major -ne 10 -or $v.Minor -ne 0) { $supported = $false; continue }
                if ($framework.name -eq 'Microsoft.AspNetCore.App' -and $v -gt $minimumAsp) { $minimumAsp = $v }
                if ($framework.name -eq 'Microsoft.NETCore.App' -and $v -gt $minimumCore) { $minimumCore = $v }
            }
        } catch { $supported = $false }
    }
    $asp = $null
    $core = $null
    $dotnet = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
    if (Test-Path -LiteralPath $dotnet) {
        $lines = @(& $dotnet --list-runtimes 2>$null)
        if ($LASTEXITCODE -eq 0) {
            foreach ($line in $lines) {
                if ($line -match '^(Microsoft\.AspNetCore\.App|Microsoft\.NETCore\.App) (10\.0\.\d+)\s+\[') {
                    $name = $Matches[1]; $v = [version]$Matches[2]
                    if ($name -eq 'Microsoft.AspNetCore.App') {
                        if (-not $asp -or $v -gt $asp) { $asp = $v }
                    } else {
                        if (-not $core -or $v -gt $core) { $core = $v }
                    }
                }
            }
        }
    }
    # The ASP.NET shared framework can itself require the matching Core patch.
    # This also catches 10.0.15 ASP.NET with only 10.0.5 Core installed.
    if ($asp -and $asp -gt $minimumCore) { $minimumCore = $asp }
    if ($minimumAsp -gt $minimumCore) { $minimumCore = $minimumAsp }
    return [pscustomobject]@{
        Supported = $supported
        AspVersion = $asp
        CoreVersion = $core
        MinimumAsp = $minimumAsp
        MinimumCore = $minimumCore
        AspReady = [bool]($asp -and $asp -ge $minimumAsp)
        CoreReady = [bool]($core -and $core -ge $minimumCore)
    }
}

# Read-only GPU vendor detection. PCI vendor IDs avoid ambiguous adapter names.
function Get-AgentGpuVendors {
    try {
        $adapters = @(Get-CimInstance Win32_VideoController -ErrorAction Stop)
        $vendors = @()
        foreach ($adapter in $adapters) {
            if ($adapter.PNPDeviceID -match 'VEN_10DE' -or $adapter.Name -match 'NVIDIA') { $vendors += 'NVIDIA' }
            if ($adapter.PNPDeviceID -match 'VEN_1002' -or $adapter.Name -match 'AMD|Radeon|Advanced Micro Devices') { $vendors += 'AMD' }
            if ($adapter.PNPDeviceID -match 'VEN_8086' -or $adapter.Name -match 'Intel') { $vendors += 'Intel' }
        }
        return @($vendors | Sort-Object -Unique)
    } catch { return @() }
}
function Find-AgentProgram([string]$Name, [string[]]$Patterns = @()) {
    $tool = Find-Tool $Name
    if ($tool) { return $tool }
    foreach ($pattern in $Patterns) {
        $file = Get-Item -Path $pattern -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1
        if ($file) { return $file.FullName }
    }
    return $null
}
function Get-AgentExtendedTools {
    $pf = $env:ProgramFiles
    $local = $env:LOCALAPPDATA
    $pf86 = ${env:ProgramFiles(x86)}
    $cdb = Find-SdkTool 'cdb.exe'
    $dxc = Find-SdkTool 'dxc.exe'
    if (-not $dxc) { $dxc = Find-AgentProgram 'dxc.exe' @("$local\Microsoft\WinGet\Packages\Microsoft.DirectX.ShaderCompiler*\bin\x64\dxc.exe", "$pf\WinGet\Packages\Microsoft.DirectX.ShaderCompiler*\bin\x64\dxc.exe") }
    $renderdoc = Find-AgentProgram 'renderdoccmd.exe' @("$pf\RenderDoc\renderdoccmd.exe", "$pf86\RenderDoc\renderdoccmd.exe")
    $procmon = Find-AgentProgram 'Procmon64.exe' @("$local\Microsoft\WinGet\Packages\Microsoft.Sysinternals.ProcessMonitor*\Procmon64.exe", "$pf\WinGet\Packages\Microsoft.Sysinternals.ProcessMonitor*\Procmon64.exe")
    if (-not $procmon) { $procmon = Find-Tool 'Procmon.exe' }
    $nsight = Find-AgentProgram 'ngfx-capture.exe' @("$pf\NVIDIA Corporation\Nsight Graphics*\host\windows-desktop-nomad-x64\ngfx-capture.exe", "$pf\NVIDIA Corporation\Nsight Graphics*\host\windows-desktop-x64\ngfx-capture.exe", "$pf\NVIDIA Corporation\Nsight Graphics*\ngfx-capture.exe")
    $rgp = Find-AgentProgram 'RadeonGPUProfiler.exe' @("$pf\AMD\Radeon Developer Tool Suite*\RadeonGPUProfiler.exe", "$pf\AMD\Radeon Developer Tool Suite*\RadeonGPUProfiler\RadeonGPUProfiler.exe", "$pf\AMD\Radeon GPU Profiler*\RadeonGPUProfiler.exe")
    return [ordered]@{ CDB = $cdb; DXC = $dxc; RenderDoc = $renderdoc; ProcessMonitor = $procmon; NsightGraphics = $nsight; RadeonGPUProfiler = $rgp }
}

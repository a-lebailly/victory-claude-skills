[CmdletBinding()]
param([switch]$SessionStart)
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'common.ps1')
$root = Get-VictoryRoot
$names = @('git','rustup','cargo','rustc','rust-analyzer','claude','gh','winget')
$missing = @()
Write-Output '[VIctory agent preflight] Read-only inventory; no installations or network requests.'
Write-Output 'WORKSPACE: local VIctory fork (intended private). All development stays in this checkout.'
Write-Output 'UPSTREAM: Marvisak/VIctory is a public read-only reference, not the working repository. Verify local remotes and HEAD; do not auto-sync or publish.'
foreach ($name in $names) {
    if (Find-Tool $name) { Write-Output "OK: $name on PATH" }
    else { Write-Output "MISSING: $name on PATH"; $missing += $name }
}
$pix = Find-Pix
if ($pix) {
    Write-Output 'OK: PIX with DxDmp MCP executable found (not a connection test)'
    $runtime = Get-PixRuntimeStatus $pix
    if (-not $runtime.Supported) { Write-Output 'SETUP: unsupported/unreadable PIX runtime configuration; review its requirements manually.' }
    elseif ($runtime.AspReady -and $runtime.CoreReady) { Write-Output "OK: PIX x64 .NET 10 runtimes detected (ASP.NET $($runtime.AspVersion), Core $($runtime.CoreVersion))" }
    else {
        Write-Output "SETUP: PIX MCP needs x64 ASP.NET Core >= $($runtime.MinimumAsp) and .NET Runtime >= $($runtime.MinimumCore) in the 10.0 series. Found ASP.NET '$($runtime.AspVersion)', Core '$($runtime.CoreVersion)'."
        Write-Output 'For PIX MCP, ask approval to run scripts/agent/bootstrap.ps1 -Install -EnablePixMcp.'
    }
}
else { Write-Output 'OPTIONAL: PIX with DxDmp MCP not detected' }
$extended = Get-AgentExtendedTools
foreach ($name in @('CDB','DXC','RenderDoc','ProcessMonitor')) {
    if ($extended[$name]) { Write-Output "OK: ${name}: $($extended[$name])" }
    else { Write-Output "FULLSTACK: $name not detected; may be installed in a custom location." }
}
if (Test-Path -LiteralPath (Join-Path $root 'victory.toml')) { Write-Output 'OK: victory.toml exists (paths not checked)' }
else { Write-Output 'SETUP: copy victory.example.toml to victory.toml and configure authorized external test files.' }
if (-not $SessionStart) {
    try {
        Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object { Write-Output ('GPU: ' + $_.Name + '; driver ' + $_.DriverVersion) }
    } catch { Write-Output 'GPU: inventory unavailable' }
    $vendors = @(Get-AgentGpuVendors)
    if ('NVIDIA' -in $vendors) {
        if ($extended.NsightGraphics) { Write-Output "OK: Nsight Graphics: $($extended.NsightGraphics)" }
        else { Write-Output 'FULLSTACK: NVIDIA detected; Nsight Graphics / Aftermath may need vendor installation.' }
    }
    if ('AMD' -in $vendors) {
        if ($extended.RadeonGPUProfiler) { Write-Output "OK: Radeon GPU Profiler: $($extended.RadeonGPUProfiler)" }
        else { Write-Output 'FULLSTACK: AMD detected; Radeon GPU Profiler may need vendor installation.' }
    }
}
Write-Output 'FullStack is opt-in: ask approval for scripts/agent/bootstrap.ps1 -Install -FullStack if needed.'
Write-Output 'Plugin activation, Rust components, GPU capabilities and MCP connectivity require separate verification.'
if ($missing.Count -gt 0) { Write-Output 'Before development, report missing tools and ask approval for scripts/agent/bootstrap.ps1 -Install.' }
else { Write-Output 'Core PATH tools detected; verify actual build and tests before claiming readiness.' }
Write-Output 'Never expose raw proprietary data or diagnostics to the model. Read AGENTS.md and docs/agent-tooling.md.'
exit 0

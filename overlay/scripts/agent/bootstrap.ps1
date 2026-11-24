[CmdletBinding()]
param([switch]$Install,[switch]$EnablePixMcp,[switch]$Launch)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$root = Get-VictoryRoot
Push-Location $root
try {
    if (-not $Install) {
        & (Join-Path $PSScriptRoot 'preflight.ps1')
        Write-Host 'Dry run. To approve core installations: .\scripts\agent\bootstrap.ps1 -Install'
        return
    }
    $failed = New-Object 'System.Collections.Generic.List[string]'
    function Invoke-Step([string]$Label,[scriptblock]$Action) {
        Write-Host "== $Label =="
        try { & $Action; if ($LASTEXITCODE -ne 0) { throw "Exit $LASTEXITCODE" } }
        catch { Write-Warning "$Label : $_"; $failed.Add($Label) }
    }
    function Ensure-Winget([string]$Id) {
        if (-not (Find-Tool 'winget')) { Write-Warning "Install $Id manually (winget unavailable)."; $failed.Add($Id); return }
        & winget list --id $Id --exact --accept-source-agreements --disable-interactivity | Out-Host
        if ($LASTEXITCODE -eq 0) { Write-Host "$Id already installed"; return }
        Invoke-Step "Install $Id" { & winget install --id $Id --exact --source winget }
    }
    function Install-PixRuntime([string]$Id) {
        if (-not (Find-Tool 'winget')) {
            Write-Warning "Install $Id (x64) from https://dotnet.microsoft.com/download/dotnet/10.0."
            $failed.Add($Id); return
        }
        # Do not use `winget list` as a readiness check: a registered package
        # may be outdated, or the runtime may have come from another installer.
        # `install` also requests an upgrade if Winget recognizes an older package.
        Invoke-Step "Install or update $Id (x64)" { & winget install --id $Id --exact --source winget --architecture x64 }
    }
    if (-not (Find-Tool 'gh')) { Ensure-Winget 'GitHub.cli' }
    if (-not (Find-Pix)) { Ensure-Winget 'Microsoft.PIX' }
    if (-not (Find-Tool 'windbg.exe')) { Ensure-Winget 'Microsoft.WinDbg' }
    if (Find-Tool 'rustup') {
        Invoke-Step 'Pinned Rust toolchain' { & rustup toolchain install }
        Invoke-Step 'Rust analyzer and sources' { & rustup component add rust-analyzer rust-src }
    } else { Write-Warning 'Install Rust from https://rustup.rs/ and MSVC C++ Build Tools + Windows SDK, then rerun.'; $failed.Add('Rust') }
    if (Find-Tool 'claude') {
        # CLI commands use project scope. No blanket tool permissions or automatic authentication.
        $installed = & claude plugin list 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Plugin inventory failed; open Claude Code and check /plugin.'; $failed.Add('Claude plugin inventory') }
        else {
            $marketplaces = & claude plugin marketplace list 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $marketplaces -notmatch 'claude-plugins-official') {
                Invoke-Step 'Official Claude marketplace' { & claude plugin marketplace add anthropics/claude-plugins-official }
            }
            foreach ($plugin in @('superpowers@claude-plugins-official','rust-analyzer-lsp@claude-plugins-official')) {
                if ($installed -match [regex]::Escape($plugin)) { Write-Host "$plugin already listed; verify active scope in /plugin." }
                else { Invoke-Step "Plugin $plugin" { & claude plugin install $plugin --scope project } }
            }
        }
        if ($EnablePixMcp) {
            $pix = Find-Pix
            if ($pix) {
                $runtime = Get-PixRuntimeStatus $pix
                if (-not $runtime.Supported) {
                    Write-Warning 'PIX runtime configuration is not recognized as .NET 10. Review its runtimeconfig.json and install the required runtimes manually.'
                    $failed.Add('PIX runtime configuration')
                } else {
                    if (-not $runtime.AspReady) { Install-PixRuntime 'Microsoft.DotNet.AspNetCore.10' }
                    # Recheck after ASP.NET installation: it can raise the Core patch requirement.
                    $runtime = Get-PixRuntimeStatus $pix
                    if (-not $runtime.CoreReady) { Install-PixRuntime 'Microsoft.DotNet.Runtime.10' }
                    $runtime = Get-PixRuntimeStatus $pix
                    if (-not ($runtime.AspReady -and $runtime.CoreReady)) {
                        Write-Warning "PIX requires x64 ASP.NET Core >= $($runtime.MinimumAsp) and .NET Runtime >= $($runtime.MinimumCore) in the 10.0 series. Found ASP.NET '$($runtime.AspVersion)' and Core '$($runtime.CoreVersion)'. Reopen PowerShell or install missing runtimes manually."
                        $failed.Add('PIX .NET runtimes')
                    } else {
                        Write-Host "PIX x64 runtime check: ASP.NET $($runtime.AspVersion); Core $($runtime.CoreVersion)"
                        $list = & claude mcp list 2>&1 | Out-String
                        if ($LASTEXITCODE -ne 0) { Write-Warning 'MCP list failed; register PIX manually.'; $failed.Add('PIX MCP list') }
                        else {
                            if ($list -notmatch '(?m)^pix-dxdmp\s*:') {
                                Invoke-Step 'PIX local MCP' { & claude mcp add --transport stdio --scope local pix-dxdmp -- (Join-Path $pix 'DxDmpMcp.exe') }
                            }
                            # Preserve any existing registration and verify connectivity after repair.
                            $list = & claude mcp list 2>&1 | Out-String
                            if ($LASTEXITCODE -ne 0 -or $list -notmatch '(?im)^pix-dxdmp\s*:[^\r\n]*\bConnected\s*$') {
                                Write-Warning 'PIX MCP connection not confirmed. Check claude mcp get pix-dxdmp and run DxDmpMcp.exe --help. Existing configuration was not overwritten.'
                                $failed.Add('PIX MCP connection')
                            } else { Write-Host 'PIX MCP connected.' }
                        }
                    }
                }
                $skill = Join-Path $pix 'Tools\DxDmp\agent-kit\skills\pix-diagnose'
                $config = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
                $skills = Join-Path $config 'skills'
                if ((Test-Path -LiteralPath (Join-Path $skill 'SKILL.md')) -and -not (Test-Path -LiteralPath (Join-Path $skills 'pix-diagnose'))) {
                    New-Item -ItemType Directory -Force -Path $skills | Out-Null
                    Copy-Item -LiteralPath $skill -Destination $skills -Recurse
                } elseif (-not (Test-Path -LiteralPath (Join-Path $skills 'pix-diagnose\SKILL.md'))) {
                    Write-Warning 'PIX diagnose skill not found in the expected source or user location. See docs/agent-tooling.md.'
                    $failed.Add('PIX diagnose skill')
                }
            } else { Write-Warning 'PIX version with DxDmp not detected. Install compatible PIX then rerun.'; $failed.Add('PIX MCP') }
        }
    } else { Write-Warning 'Install Claude Code via https://code.claude.com/docs/en/setup, open a new terminal, then rerun.'; $failed.Add('Claude Code') }
    if (Find-Tool 'cargo') {
        $existingHooks = & git config --get core.hooksPath 2>$null
        if ($LASTEXITCODE -eq 0 -and $existingHooks -and $existingHooks -ne '.githooks') {
            Write-Warning 'Custom Git hooksPath is configured; preserve it and integrate the asset-policy hook manually.'
            $failed.Add('Asset-policy Git hook')
        } elseif ($existingHooks -ne '.githooks') { Invoke-Step 'VIctory asset-policy Git hook' { & cargo xtask install-hooks } }
        else { Write-Host 'VIctory asset-policy Git hook already configured.' }
    }
    Write-Host 'Manual next steps: approve project MCP in Claude, check /plugin and /mcp; gh auth login if needed. SDK/CDB/DXC and vendor tools: docs/agent-tooling.md.'
    if ($failed.Count) { Write-Warning ('Incomplete: ' + ($failed -join ', ')); Write-Host 'Open a fresh terminal after installers and rerun. No readiness claim.'; return }
    if ($Launch -and (Find-Tool 'claude')) { & claude }
} finally { Pop-Location }

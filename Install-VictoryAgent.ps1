[CmdletBinding()]
param(
    [string]$Target = (Join-Path (Split-Path -Parent $PSScriptRoot) 'VIctory'),
    [string]$RepoUrl = 'https://github.com/Marvisak/VIctory.git',
    [switch]$InstallTools,
    [switch]$EnablePixMcp,
    [switch]$UpdateExisting
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Install Git for Windows first: https://git-scm.com/download/win' }
$targetPath = [IO.Path]::GetFullPath($Target)
$overlay = Join-Path $PSScriptRoot 'overlay'
if (-not (Test-Path -LiteralPath $overlay)) { throw 'Extract the entire ZIP first.' }
if (-not (Test-Path -LiteralPath $targetPath)) {
    & git clone -- $RepoUrl $targetPath
    if ($LASTEXITCODE -ne 0) { throw 'Clone failed. No overlay installed.' }
}
foreach ($marker in @('.victory-root','Cargo.toml','README.md','docs/asset-policy.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $targetPath $marker))) { throw "Target is not a VIctory checkout: missing $marker" }
}
$files = @(Get-ChildItem -LiteralPath $overlay -Recurse -File -Force)
# Only known, unchanged previous overlay versions can be replaced with explicit consent.
$previousHashes = @{
    'scripts\agent\common.ps1' = '7D6849C8049360297060851F61AACFDF0DE86405E95F9B579E5F72A13DC49583'
    'scripts\agent\bootstrap.ps1' = '3557615CBA7B2080D4637A005EBB3295EC4BEE112CE2862765D127DCD19A18F9'
    'scripts\agent\preflight.ps1' = 'A4D8E6F5CF99C96ED66841E0C3689C1A548F06079B42529FD6CAFD11773DD994'
    'docs\agent-tooling.md' = '44A4C8B2EBB3F5F1CB1FD91191FF7B82D71B436EB9050BEA8DA86C55B622FFAA'
    'AGENTS.md' = '0D612E702329FE3A51AF5B909562298A6F71887FA9EAD78F851B4B304AD13136'
}
# Git may convert LF to CRLF on Windows. Compare text after normalizing
# line endings so that a clean checkout is not mistaken for a customization.
function Get-OverlayHash([string]$Path) {
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))).Replace('-', '') }
    finally { $sha.Dispose() }
}
$updates = @{}
# Check every conflict before copying. Preserve upstream and existing local files.
foreach ($file in $files) {
    $relative = $file.FullName.Substring($overlay.Length).TrimStart([char[]]@('\','/'))
    $dest = Join-Path $targetPath $relative
    if (Test-Path -LiteralPath $dest) {
        $currentHash = (Get-OverlayHash $dest)
        $newHash = (Get-OverlayHash $file.FullName)
        if ($currentHash -ne $newHash) {
            $key = $relative.Replace('/', '\')
            # Claude can add enabledPlugins and other project settings after setup.
            # This release does not change the supplied settings.json template.
            # Preserve the user's entire configuration on update, including hooks.
            if ($UpdateExisting -and $key -eq '.claude\settings.json') {
                try { $null = Get-Content -LiteralPath $dest -Raw | ConvertFrom-Json -ErrorAction Stop }
                catch { throw "Invalid JSON in $relative. Repair it before updating; no overlay files copied." }
                Write-Warning 'Preserving existing .claude/settings.json. Verify that the SessionStart preflight hook is still present using /hooks in Claude Code.'
                continue
            }
            if ($UpdateExisting -and $previousHashes.ContainsKey($key) -and $currentHash -eq $previousHashes[$key]) {
                $updates[$relative] = $true
            } else {
                throw "Conflict: $relative. Use -UpdateExisting for unchanged files from the previous release, or review and merge customized files manually; no overlay files copied."
            }
        }
    }
}
foreach ($file in $files) {
    $relative = $file.FullName.Substring($overlay.Length).TrimStart([char[]]@('\','/'))
    $dest = Join-Path $targetPath $relative
    if (-not (Test-Path -LiteralPath $dest)) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $dest
    } elseif ($updates.ContainsKey($relative)) {
        Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
        Write-Host "Updated unchanged previous toolkit file: $relative"
    }
}
$readme = Join-Path $targetPath 'README.md'
$marker = '<!-- victory-claude-skills -->'
$content = [IO.File]::ReadAllText($readme)
if (-not $content.Contains($marker) -and -not $content.Contains('<!-- victory-agent-fork -->')) {
    $text = "`n`n$marker`n## AI-assisted development`n`nToolkit: [victory-claude-skills](https://github.com/a-lebailly/victory-claude-skills). See [agent setup](docs/agent-tooling.md). Run the approved bootstrap once, then start Claude Code from the repository root. SessionStart checks installed tools without changing the machine.`n"
    [IO.File]::AppendAllText($readme, $text, (New-Object Text.UTF8Encoding($false)))
}
Write-Host "Overlay installed: $targetPath"
Write-Host 'No commit, push, fork creation or runtime code change was performed.'
if ($InstallTools) { & (Join-Path $targetPath 'scripts\agent\bootstrap.ps1') -Install -EnablePixMcp:$EnablePixMcp }
Write-Host "Next: cd '$targetPath'; claude"

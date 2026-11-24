[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Target,
    [string]$RepoUrl,
    [switch]$InstallTools,
    [switch]$EnablePixMcp,
    [switch]$UpdateExisting,
    [switch]$FullStack
)
$ErrorActionPreference = 'Stop'
# FullStack explicitly opts into all core installations and PIX MCP.
if ($FullStack) { $InstallTools = $true; $EnablePixMcp = $true }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Install Git for Windows first: https://git-scm.com/download/win' }
$targetPath = [IO.Path]::GetFullPath($Target)
$overlay = Join-Path $PSScriptRoot 'overlay'
if (-not (Test-Path -LiteralPath $overlay)) { throw 'Extract the entire ZIP first.' }
if (-not (Test-Path -LiteralPath $targetPath)) {
    if ([string]::IsNullOrWhiteSpace($RepoUrl)) { throw 'Target does not exist. Specify your private fork URL with -RepoUrl, or select an existing private fork checkout. Public upstream is not cloned by default.' }
    & git clone -- $RepoUrl $targetPath
    if ($LASTEXITCODE -ne 0) { throw 'Clone failed. No overlay installed.' }
}
foreach ($marker in @('.victory-root','Cargo.toml','README.md','docs/asset-policy.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $targetPath $marker))) { throw "Target is not a VIctory checkout: missing $marker" }
}
$gitRoot = & git -C $targetPath rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0 -or -not $gitRoot -or [IO.Path]::GetFullPath($gitRoot).TrimEnd([char[]]@('\','/')) -ne $targetPath.TrimEnd([char[]]@('\','/'))) { throw 'Target must be the root of your local VIctory fork Git checkout.' }
Write-Host 'Workspace: selected local VIctory fork. Public Marvisak/VIctory is a read-only reference; no remotes or branches will be changed.'
$files = @(Get-ChildItem -LiteralPath $overlay -Recurse -File -Force)
# Only known, unchanged previous overlay versions can be replaced with explicit consent.
$previousHashes = @{
    '.claude\skills\victory-gpu-debug\SKILL.md' = @('14F97A16CFA2E38EA81EDA9B6A8BE61AB85EE37280FC1E438395940FE8DB9F28')
    '.claude\skills\victory-triage\SKILL.md' = @('74BD65AA2E50BE15FC7E34ABF3140662ECCA19558F2EEE660F1FC9DDDFA705EC')
    '.claude\skills\victory-shader-debug\SKILL.md' = @('7DAD17C5F8791AAE8DE9A803CA6CD5133B4F9ACF921606BFFAA08681191A2087')
    '.claude\skills\victory-validate\SKILL.md' = @('E4B33D01C02AFA14DFD51BC68ED18876B8FAB43AA1D2FF21F3C66A5557ED0B05')
    'scripts\agent\common.ps1' = @('2F5E8032DB1B369EFB6C8C3FD24C6B6022D11D8358547EE86C4E0B9D05BC7E43', '7D6849C8049360297060851F61AACFDF0DE86405E95F9B579E5F72A13DC49583')
    'scripts\agent\bootstrap.ps1' = @('0F6F87DF66D1BC3B4E76FA2A40B0AE1DCB3DAA3006041DE45596E6076AAC2F30', '3557615CBA7B2080D4637A005EBB3295EC4BEE112CE2862765D127DCD19A18F9')
    'scripts\agent\preflight.ps1' = @('8B56F6D1C15F7348BCFC95D91C358376E4093BA93D81FED37D3B36778BCBC02E', 'A4D8E6F5CF99C96ED66841E0C3689C1A548F06079B42529FD6CAFD11773DD994', 'D66E2FC0C9BEEDBBEE0DDF49E0F53AD863729B25A06595E22D2D1D1DFAE7304E')
    'docs\agent-tooling.md' = @('44A4C8B2EBB3F5F1CB1FD91191FF7B82D71B436EB9050BEA8DA86C55B622FFAA', '5E01B7525FC28B0339F296E5BF03CD381E296727F4DC32812A3CD9412280F661', 'A95C5ABB2EAD952127A71CCEA9E5CF6B14745DE8B665596AAD3284DFD8CA1126')
    'AGENTS.md' = @('0D612E702329FE3A51AF5B909562298A6F71887FA9EAD78F851B4B304AD13136', 'C24ACE1026C96F85CAD46BBD19CD179A8093657643D86A7EEC36FAD43767D4F0', '09A7722A27D39ADD8FF7A1D4C6E9888E688D7D15F22F98292AD3B8417D2D8F3E')
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
            if ($UpdateExisting -and $previousHashes.ContainsKey($key) -and $currentHash -in $previousHashes[$key]) {
                $updates[$relative] = $true
            } else {
                throw "Conflict: $relative. Use -UpdateExisting for unchanged files from the supported previous releases, or review and merge customized files manually; no overlay files copied."
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
    $text = "`n`n$marker`n## AI-assisted development`n`nToolkit: [victory-claude-skills](https://github.com/a-lebailly/victory-claude-skills). See [agent setup](docs/agent-tooling.md). Work in this local private fork; [Marvisak/VIctory](https://github.com/Marvisak/VIctory) is public upstream for read-only reference only. Run the approved bootstrap once, then start Claude Code from the private fork root. SessionStart checks installed tools without changing the machine.`n"
    [IO.File]::AppendAllText($readme, $text, (New-Object Text.UTF8Encoding($false)))
}
Write-Host "Overlay installed: $targetPath"
Write-Host 'No commit, push, fork creation or runtime code change was performed.'
if ($InstallTools) { & (Join-Path $targetPath 'scripts\agent\bootstrap.ps1') -Install -EnablePixMcp:$EnablePixMcp -FullStack:$FullStack }
Write-Host "Next: cd '$targetPath'; claude"

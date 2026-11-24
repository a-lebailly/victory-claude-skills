# victory-claude-skills

A community toolkit for AI-assisted development on [VIctory](https://github.com/Marvisak/VIctory), designed for Claude Code Desktop, Claude Code CLI and Codex. It provides project instructions, four specialized skills, MCP integration, development tools and a read-only startup check.

This is a standalone tooling repository, not the VIctory runtime. It contains no game files or credentials.

## Installation (Windows)

### Prerequisites (install before running the script)

| Dependency | Purpose / setup |
|---|---|
| Windows 10/11 x64 + Windows PowerShell 5.1 | Runs VIctory and the toolkit scripts; PowerShell 5.1 is built into Windows. |
| [Git for Windows](https://git-scm.com/download/win) | Clone the repositories; provides Git Bash for Claude Code. |
| [WinGet / App Installer](https://learn.microsoft.com/windows/package-manager/winget/) | Installs the Windows packages listed below. Without it, install them manually. |
| [Rustup](https://rustup.rs/) | Installs and manages the Rust toolchain pinned by VIctory. |
| [Visual Studio C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) | Select Desktop development with C++, x64 MSVC compiler/linker and Windows SDK to build the Rust workspace. |
| [Claude Code CLI](https://code.claude.com/docs/en/setup) | Required for automated plugin and MCP setup; `claude --version` must work in PowerShell. Authenticate as needed. |
| [Claude Desktop](https://claude.com/download) (optional) | Graphical interface for local Code sessions; the CLI is still used by this installer. |

Review the scripts before running them. Internet access is required for downloads and remote services. Some installers may request administrator approval. Running VIctory itself also requires a compatible AVX2 CPU and DirectX 12 GPU with shader model 6.6 (mesh shaders for world rendering), sufficient memory/commit, and authorized game files kept outside the repository. Check current upstream requirements.

### 1. Download the toolkit

```powershell
git clone https://github.com/a-lebailly/victory-claude-skills.git
cd victory-claude-skills
```

Alternatively, download and extract the [ZIP](https://github.com/a-lebailly/victory-claude-skills/archive/refs/heads/main.zip), then open PowerShell in the extracted folder.

### 2. Install the tools and configuration

> [!WARNING]
> Windows PowerShell may block the installer with an error stating that script execution is disabled (`PSSecurityException` / `UnauthorizedAccess`). If this happens, review the scripts and verify that they come from this trusted repository, then run the following command in the same PowerShell window:
>
> ```powershell
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ```
>
> This temporarily disables execution-policy checks for the current PowerShell session only. It does not require administrator privileges or permanently change your execution policy. Close the window when finished. Do not override an organization-managed security policy.
>
> Retry the installation command below. If the preflight script in step 3 is blocked in a new PowerShell window, repeat this temporary step after reviewing that script as well.

Replace `C:\path\to\VIctory` with the actual path to your VIctory checkout, or the location where you want it to be cloned.

```powershell
$VictoryPath = 'C:\path\to\VIctory' # Replace with your own path
.\Install-VictoryAgent.ps1 -Target $VictoryPath -InstallTools -EnablePixMcp
```

The installer clones VIctory if necessary, copies the toolkit into the checkout, installs the core tools and plugins, and attempts to configure PIX MCP when supported. Existing conflicting configuration files are not overwritten. No manual copying is required.

- Omit `-InstallTools` to copy the configuration only.
- Omit `-EnablePixMcp` to skip PIX MCP setup.
- To clone your own VIctory fork instead, add `-RepoUrl 'https://github.com/YOUR-USERNAME/YOUR-VICTORY-FORK.git'` and replace the URL with your fork's actual URL.

### Updating an existing installation

From the **new toolkit folder**, after replacing the example path:

```powershell
$VictoryPath = 'C:\path\to\VIctory' # Replace with your own path
.\Install-VictoryAgent.ps1 -Target $VictoryPath -InstallTools -EnablePixMcp -UpdateExisting
```

`-UpdateExisting` replaces only unchanged files from the previous toolkit release (ignoring Git line-ending conversion). Customized files or unknown versions cause a conflict before copying; review and merge those files manually. Exception: with `-UpdateExisting`, a valid existing `.claude/settings.json` is preserved as-is, because Claude may have added plugin settings since installation. Check `/hooks` to confirm the SessionStart preflight hook is still enabled; if it is missing, merge the hook from `overlay/.claude/settings.json` manually. Existing MCP registrations are preserved. If you installed the old kit already, this also repairs the missing PIX runtimes without reinstalling everything. Close and reopen Claude sessions afterwards.

### 3. Verify the installation

Open a fresh PowerShell window. Replace the example path again with your actual VIctory folder.

```powershell
Set-Location 'C:\path\to\VIctory' # Replace with your own path
.\scripts\agent\preflight.ps1
```

Review any warnings and complete missing prerequisites or authentication steps before continuing. Check `claude mcp list`, `/plugin`, `/mcp` and `/hooks` in Claude as appropriate. Run `gh auth login` manually if authenticated GitHub operations are needed. A detected executable is not proof of a working tool. If the startup hook is blocked by execution policy in a fresh session, run preflight manually from a trusted PowerShell session; the installer does not change permanent policy.

### 4. Start Claude Code

**Desktop (GUI):**

1. Open Claude Desktop and select the **Code** tab.
2. Start a **Local** session and select your configured VIctory folder (not the toolkit folder).
3. Approve the project configuration and MCP servers if prompted. Verify that the skills, plugins and startup hook are available.

The CLI is used by the installer for automated setup; you do not need to use the terminal interface for everyday development. Local Desktop sessions and the CLI share [Claude Code configuration files](https://code.claude.com/docs/en/settings).

**CLI:** From the VIctory folder opened in step 3, run:

```powershell
claude
```

For Codex, open the same VIctory checkout and follow `AGENTS.md`.

## What is included

### Project skills (copied automatically)

| Skill | Purpose |
|---|---|
| `/victory-triage` | Checks upstream issues and pull requests, chooses a reproducible high-impact problem and avoids duplicate work. |
| `/victory-gpu-debug` | Investigates black frames, GPU hangs, D3D12 resource states, barriers, descriptors and synchronization with local evidence. |
| `/victory-shader-debug` | Diagnoses RDNA2 instruction semantics, SSA, wave/lane behavior and DXIL translation, using synthetic shader tests. |
| `/victory-validate` | Compares baseline and patched builds, runs regression tests and CI-equivalent checks, and prepares an evidence-based report. |

`AGENTS.md` contains shared engineering rules; `CLAUDE.md` imports them. The `SessionStart` hook runs a read-only inventory, not an automatic installation. Codex can use the same instructions and run preflight manually.

### Claude plugins

| Plugin / skill | Purpose | Setup |
|---|---|---|
| [Superpowers](https://github.com/obra/superpowers) | Systematic debugging, planning, test-driven development and verification. | Official marketplace; installed by `-InstallTools` if missing. |
| [Rust Analyzer LSP](https://github.com/anthropics/claude-plugins-official) | Rust-aware navigation, definitions, references and diagnostics. | Official marketplace; installed by `-InstallTools`. |
| [PIX Diagnose](https://learn.microsoft.com/windows/pix/directx-dump-files/analyze-dump-files-with-ai-agents) | Microsoft's workflow for diagnosing compatible DirectX GPU dumps. | Copied from a compatible PIX installation to user skills when `-EnablePixMcp` is supplied with `-InstallTools`. |

### MCP servers

| Server | Purpose | Setup |
|---|---|---|
| [Microsoft Learn](https://github.com/MicrosoftDocs/mcp) | Search official documentation for D3D12, DXGI, Win32 and related APIs. | Project `.mcp.json`; approve in Claude. Remote HTTP service. |
| [PIX DxDmp](https://learn.microsoft.com/windows/pix/directx-dump-files/dxdmp-tools-reference) | Analyze compatible `.dxdmp` GPU crash dumps with local protocol tools. Not a general GUI controller or CPU debugger. | `-InstallTools -EnablePixMcp`; local `DxDmpMcp.exe` over stdio. Requires both x64 .NET 10 runtimes below. |

GitHub CLI is used for upstream research. GitHub MCP is optional and is not registered automatically; see the [official server](https://github.com/github/github-mcp-server). Prefer read-only access. No tokens are stored in this repository.

### Software and runtime dependencies installed by the bootstrap

| Tool | Purpose | Install method |
|---|---|---|
| Pinned Rust toolchain, Cargo, Clippy, Rustfmt | Build, test and lint VIctory with its checked-in toolchain. | `rustup toolchain install`; follows `rust-toolchain.toml`. |
| Rust Analyzer and Rust Source | Language server executable and standard-library sources for code analysis. | `rustup component add rust-analyzer rust-src` |
| [GitHub CLI](https://cli.github.com/) | Inspect public issues, PRs, branches and commits. | `winget install --id GitHub.cli -e` |
| [Microsoft PIX](https://devblogs.microsoft.com/pix/download/) | Inspect D3D12 frames, resources, GPU timing and graphics faults; includes DxDmp tools in compatible versions. | `winget install --id Microsoft.PIX -e` |
| [.NET Runtime 10 x64](https://dotnet.microsoft.com/download/dotnet/10.0) | Provides `Microsoft.NETCore.App` for PIX MCP. | `winget install --id Microsoft.DotNet.Runtime.10 -e --architecture x64` (PIX MCP option only) |
| [ASP.NET Core Runtime 10 x64](https://dotnet.microsoft.com/download/dotnet/10.0) | Provides `Microsoft.AspNetCore.App` for PIX MCP. | `winget install --id Microsoft.DotNet.AspNetCore.10 -e --architecture x64` (PIX MCP option only) |
| [WinDbg](https://learn.microsoft.com/windows-hardware/drivers/debugger/) | Inspect native crashes, call stacks and CPU-side state. | `winget install --id Microsoft.WinDbg -e` |

The bootstrap attempts missing installations; it does not silently upgrade unrelated packages or replace existing custom configurations. PIX runtime checks use the x64 .NET host and installed framework versions, not just Winget registration. It installs or updates an insufficient 10.0 runtime when PIX MCP is explicitly enabled. Authentication, UAC prompts, missing installers and driver/hardware support may require manual action. The VIctory asset-policy Git hook is also configured if no conflicting hook exists.

### Optional tools (manual installation, not installed by the script)

| Tool | Purpose / install |
|---|---|
| [CDB](https://developer.microsoft.com/windows/downloads/windows-sdk/) | Command-line native debugger; choose Debugging Tools for Windows in Windows SDK setup. |
| [DXC](https://github.com/microsoft/DirectXShaderCompiler/releases) | Compile synthetic HLSL references and inspect/validate DXIL; use the SDK or official binaries. VIctory itself emits DXIL directly. |
| [RenderDoc](https://github.com/baldurk/renderdoc/releases) | Inspect supported frame captures and resources; use the Windows installer. |
| [Process Monitor](https://learn.microsoft.com/sysinternals/downloads/procmon) | Investigate file and DLL access; download and extract Sysinternals tool. |
| [Windows Performance Toolkit](https://learn.microsoft.com/windows-hardware/test/wpt/) | CPU, memory and I/O profiling; install through Windows ADK. |
| [Ghidra](https://github.com/NationalSecurityAgency/ghidra/releases) | Authorized static binary/ABI analysis; download release and its required JDK. |
| [NVIDIA Nsight Graphics / Aftermath](https://developer.nvidia.com/nsight-graphics) | NVIDIA GPU captures and crash analysis; use vendor installer, Aftermath integration as needed. |
| [NVIDIA Nsight Systems](https://developer.nvidia.com/nsight-systems) | NVIDIA CPU/GPU timeline and performance profiling; vendor installer. |
| [AMD Radeon GPU Profiler](https://gpuopen.com/rgp/) | AMD-specific performance profiling; vendor download. |
| [WinDbg skills](https://github.com/microsoft/win-dev-skills) | Optional debugger-oriented agent workflows; follow the current upstream plugin instructions. |

## PIX MCP troubleshooting

If `pix-dxdmp` shows `CONNECTION_CLOSED`, verify both x64 runtimes (not .NET Desktop Runtime alone):

```powershell
winget install --id Microsoft.DotNet.AspNetCore.10 -e --architecture x64
winget install --id Microsoft.DotNet.Runtime.10 -e --architecture x64
dotnet --list-runtimes
claude mcp list
```

PIX 2611.19 was observed requiring ASP.NET Core 10.0 and, after installing ASP.NET 10.0.15, .NET Core 10.0.15. Use the current compatible 10.0 patch: both shared frameworks must be present and the Core version must satisfy the selected ASP.NET framework. If `winget upgrade` cannot find an installed package, use `winget install` as above or the [official x64 installers](https://dotnet.microsoft.com/download/dotnet/10.0). Do not remove other .NET major versions. See [Microsoft's .NET installation guide](https://learn.microsoft.com/dotnet/core/install/windows).

If the error persists, use the actual path reported by `claude mcp get pix-dxdmp` and run `DxDmpMcp.exe --help` to diagnose the startup error. PIX does not need to be open for its MCP server. Check the [official PIX agent documentation](https://learn.microsoft.com/windows/pix/directx-dump-files/analyze-dump-files-with-ai-agents). Restart Claude after setup. A successful runtime check is not a guarantee of a working MCP connection.

## More information

See [agent-tooling.md](overlay/docs/agent-tooling.md) for the full tool list, optional GPU-specific tools, manual setup and technical references.

Keep proprietary game files and diagnostics outside the repository. No automatic commits, pushes, driver changes or game launches are performed. Keep toolkit changes separate from upstream runtime PRs. Windows installation and Desktop integration have not been tested end to end; verify the setup and run VIctory's tests and asset-policy checks before contributing.

[Issues and feedback](https://github.com/a-lebailly/victory-claude-skills/issues)

# Agent development setup

Windows native x64, Git, Claude Code and Rust are prerequisites. This is tooling from [victory-claude-skills](https://github.com/a-lebailly/victory-claude-skills), not an upstream VIctory requirement. Review the scripts before running them. Use a valid authorized test title outside the repository. Do not use agent tooling to acquire proprietary files or bypass DRM.

## First run

From the repository root:

```powershell
.\scripts\agent\preflight.ps1
.\scripts\agent\bootstrap.ps1 -Install
```

Optional local PIX MCP and its official skill, with explicit consent:

```powershell
.\scripts\agent\bootstrap.ps1 -Install -EnablePixMcp
```

Reopen PowerShell if a newly installed tool is not on PATH. Run `claude` from the repository root and review the project MCP trust prompt. Use `/plugin`, `/mcp` and `/hooks` to inspect loaded configuration. The bootstrap can be rerun; it avoids reinstalling detected tools; the optional PIX setup repairs missing or insufficient .NET runtime versions, but does not perform unrelated upgrades. An incomplete step is reported, not silently treated as success. `-Launch` optionally starts Claude after an approved successful bootstrap. No script changes drivers, TDR, execution policy, page file, firewall, or security settings. Do not bypass organizational policy. If a downloaded script is blocked, inspect it and follow your organization's trusted-script procedure.

Each session runs a read-only PowerShell preflight via `.claude/settings.json`. For Codex, read `AGENTS.md` and run preflight directly. Missing components are proposed to the user before installation, never silently installed by a session hook. See [Claude hooks](https://code.claude.com/docs/en/hooks) and [PIX diagnostics](https://learn.microsoft.com/windows/pix/directx-dump-files/analyze-dump-files-with-ai-agents).

## Stack

| Component | Source | Setup |
|---|---|---|
| Claude Code | https://code.claude.com/docs/en/setup | Install and authenticate yourself |
| Rust + MSVC | https://rustup.rs/ | Rustup + VS C++ Build Tools and Windows SDK; bootstrap installs pinned toolchain/components |
| Superpowers | https://github.com/obra/superpowers | Bootstrap installs official marketplace plugin |
| Rust Analyzer LSP | https://github.com/anthropics/claude-plugins-official | Bootstrap installs official marketplace plugin and Rust components |
| GitHub CLI | https://cli.github.com/ | Bootstrap installs; `gh auth login` manually |
| Microsoft Learn MCP | https://github.com/MicrosoftDocs/mcp | Project `.mcp.json`, user approves |
| PIX | https://devblogs.microsoft.com/pix/download/ | Bootstrap via Winget |
| PIX DxDmp MCP + pix-diagnose | https://learn.microsoft.com/windows/pix/directx-dump-files/analyze-dump-files-with-ai-agents | Optional `-EnablePixMcp`; compatible PIX version required |
| .NET Runtime 10 (x64) | https://dotnet.microsoft.com/download/dotnet/10.0 | Required for PIX MCP; bootstrap installs/updates via Winget when needed |
| ASP.NET Core Runtime 10 (x64) | https://dotnet.microsoft.com/download/dotnet/10.0 | Required for PIX MCP; bootstrap installs/updates via Winget when needed |
| WinDbg | https://learn.microsoft.com/windows-hardware/drivers/debugger/ | Bootstrap via Winget |
| CDB | https://developer.microsoft.com/windows/downloads/windows-sdk/ | Select Debugging Tools for Windows in SDK installer |
| DXC | https://github.com/microsoft/DirectXShaderCompiler/releases | Windows SDK or official release; check path |
| RenderDoc | https://github.com/baldurk/renderdoc/releases | Optional GUI/CLI installer; verify capture support |
| Process Monitor | https://learn.microsoft.com/sysinternals/downloads/procmon | Optional standalone download |
| Windows Performance Toolkit | https://learn.microsoft.com/windows-hardware/test/wpt/ | Optional via Windows ADK |
| Ghidra | https://github.com/NationalSecurityAgency/ghidra/releases | Optional, JDK per release; authorized binary analysis only |
| NVIDIA Nsight Graphics / Aftermath | https://developer.nvidia.com/nsight-graphics | NVIDIA only; optional vendor installer; check edition/capture support |
| NVIDIA Nsight Systems | https://developer.nvidia.com/nsight-systems | NVIDIA only, optional CPU/GPU profiling |
| Radeon GPU Profiler | https://gpuopen.com/rgp/ | AMD only, optional vendor profiling |
| GitHub MCP | https://github.com/github/github-mcp-server | Optional official guide; prefer read-only; no token in Git |
| WinDbg skills | https://github.com/microsoft/win-dev-skills | Optional; inspect marketplace and current installation docs |

### PIX MCP troubleshooting

If `claude mcp list` reports `CONNECTION_CLOSED`, invoke `DxDmpMcp.exe --help` from the installed PIX directory to see the actual startup error. The observed PIX 2611.19 build needs ASP.NET Core 10 x64 and the matching .NET Core runtime patch. A Desktop Runtime alone is not enough. If ASP.NET Core is 10.0.15 but Core is 10.0.5, Core must be updated. The bootstrap checks the x64 runtime inventory before registration and again after installation, and verifies MCP connectivity separately. For manual repair:

```powershell
winget install --id Microsoft.DotNet.AspNetCore.10 -e --architecture x64
winget install --id Microsoft.DotNet.Runtime.10 -e --architecture x64
dotnet --list-runtimes
claude mcp list
```

Use a current 10.0 servicing release compatible with your PIX version; the observed patch is not a permanent pin. If Winget reports a package is already installed but the runtime check fails, use Microsoft's official x64 runtime installers. Do not remove other .NET major versions. See https://learn.microsoft.com/dotnet/core/install/windows and https://learn.microsoft.com/windows/pix/directx-dump-files/dxdmp-tools-reference. PIX need not be open for the MCP server.

Do not install the entire Vulkan toolchain for native Windows D3D12 work. Use the optional vendor tools when a specific investigation calls for them. PIX DxDmp supports actual `.dxdmp` files, not generic CPU dumps; DRED and WinDbg remain useful independently. Do not expose raw dumps or proprietary data to the model, even through a local MCP; use sanitized metrics and synthetic data. No remote file-system, debugger or unrestricted desktop MCP is enabled by default.

## References for the agent

- AMD RDNA2 ISA: https://docs.amd.com/v/u/en-US/rdna2-shader-instruction-set-architecture
- DXIL: https://github.com/microsoft/DirectXShaderCompiler/blob/main/docs/DXIL.rst
- D3D12 specs: https://microsoft.github.io/DirectX-Specs/
- D3D12 samples: https://github.com/microsoft/DirectX-Graphics-Samples
- DirectX headers: https://github.com/microsoft/DirectX-Headers
- LLVM IR: https://llvm.org/docs/LangRef.html
- DRED: https://learn.microsoft.com/windows/win32/direct3d12/use-dred
- WARP: https://learn.microsoft.com/windows/win32/direct3darticles/directx-warp
- DirectXTex: https://github.com/microsoft/DirectXTex
- D3D12 Memory Allocator: https://github.com/GPUOpen-LibrariesAndSDKs/D3D12MemoryAllocator
- NVIDIA Blackwell: https://images.nvidia.com/aem-dam/Solutions/geforce/blackwell/nvidia-rtx-blackwell-gpu-architecture.pdf
- NVIDIA NVAPI: https://github.com/NVIDIA/nvapi
- Proton research only: https://github.com/HansKristian-Work/dxil-spirv and https://github.com/HansKristian-Work/vkd3d-proton
- Community reference list: https://github.com/a-lebailly/leonida-claude-skills/issues/1

Use references to understand semantics, not to copy incompatible implementations. The main VIctory pipeline emits DXIL directly. See `AGENTS.md` and current upstream source for actual behavior. Maintain a clean separate branch/worktree for upstream PRs; do not mix AI-fork configuration with runtime changes.

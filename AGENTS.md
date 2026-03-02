# AGENTS.md

## Cursor Cloud specific instructions

This is a **PowerToys Command Palette extension** (`command-palette-obsidian`) that searches and opens Obsidian notes.

### Tech stack
- **Language:** C# (.NET 9 / Windows App SDK)
- **Extension API:** `Microsoft.CommandPalette.Extensions` (WinRT)
- **Package format:** MSIX
- **Test framework:** xUnit

### Key commands
| Task | Command |
|------|---------|
| Restore packages | `dotnet restore` |
| Build (main project) | `dotnet build` (Windows only) |
| Run tests | `dotnet test` (cross-platform) |

### Important notes
- **Full build requires Windows.** The main project (`src/CommandPaletteObsidian`) uses WinRT COM server APIs and CsWinRT code generation (`cswinrt.exe`) which only runs on Windows. On Linux, `dotnet restore` succeeds but `dotnet build` fails at the CsWinRT step.
- **Tests run cross-platform.** The test project (`tests/CommandPaletteObsidian.Tests`) targets `net9.0` (not Windows-specific) and validates core logic (vault discovery, note enumeration, search filtering, URI encoding).
- Central Package Version Management is enabled via `Directory.Packages.props`. All NuGet package versions must be specified there, not in individual `.csproj` files.
- The `ICommandProvider` and `IExtension` implementations use `partial` classes because CsWinRT generates the remaining interface members at build time.

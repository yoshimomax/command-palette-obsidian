# Command Palette Obsidian

PowerToys Command Palette extension for searching and opening [Obsidian](https://obsidian.md/) notes.

## Features

- Automatically discovers Obsidian vaults from `%APPDATA%\obsidian\obsidian.json`
- Searches notes by title and folder path across all vaults
- Opens notes directly in Obsidian via the `obsidian://` URI scheme
- Multi-term search (space-separated keywords)

## Prerequisites

- Windows 11 with [PowerToys](https://github.com/microsoft/PowerToys) installed (Command Palette enabled)
- [Obsidian](https://obsidian.md/) installed with at least one vault
- Visual Studio 2022+ with:
  - .NET desktop development workload
  - Windows application development workload
- Developer Mode enabled on Windows

## Build & Deploy

1. Open `CommandPaletteObsidian.sln` in Visual Studio
2. Set the platform to **x64**
3. Build the solution (`Ctrl+Shift+B`)
4. Deploy via **Build > Deploy Solution**
5. Open Command Palette and run **Reload Command Palette Extension**

## Development

```
dotnet restore
dotnet build
dotnet test
```

> **Note:** Full build requires Windows due to WinRT/CsWinRT dependencies.
> On Linux/macOS, only the test project (`tests/CommandPaletteObsidian.Tests`) can be built and run.

## Project Structure

```
├── src/CommandPaletteObsidian/
│   ├── CommandPaletteObsidian.cs          # IExtension implementation
│   ├── CommandPaletteObsidianCommandsProvider.cs  # ICommandProvider
│   ├── Program.cs                         # COM server entry point
│   ├── Pages/
│   │   └── ObsidianSearchPage.cs          # DynamicListPage for note search
│   ├── Helpers/
│   │   ├── ObsidianVaultDiscovery.cs      # Vault/note discovery
│   │   └── OpenNoteCommand.cs             # obsidian:// URI opener
│   └── Package.appxmanifest               # MSIX manifest
├── tests/CommandPaletteObsidian.Tests/
│   └── ObsidianVaultDiscoveryTests.cs     # Unit tests for core logic
├── Directory.Build.props
├── Directory.Packages.props
└── CommandPaletteObsidian.sln
```

## How It Works

1. On search page open, reads `%APPDATA%\obsidian\obsidian.json` to discover vaults
2. Enumerates all `.md` files in each vault (excluding `.obsidian/` config folder)
3. Filters notes by search query (matches title and relative path)
4. Opens selected note via `obsidian://open?vault={vault}&file={file}`

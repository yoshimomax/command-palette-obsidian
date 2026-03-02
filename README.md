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
- Developer Mode enabled (Settings → System → For developers → ON)

## Install

### 方法A: GitHub Actions からダウンロード (Visual Studio 不要)

1. [Actions タブ](../../actions) から最新の成功したビルドを開く
2. ページ下部の **Artifacts** から `CommandPaletteObsidian-x64` をダウンロード
3. ZIP を展開し、`.msix` ファイルをダブルクリックしてインストール
4. Command Palette を開いて `Search Obsidian Notes` を検索

### 方法B: ローカルビルド (dotnet CLI のみ・Visual Studio 不要)

必要なもの: [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)

```powershell
git clone https://github.com/yoshimomax/command-palette-obsidian.git
cd command-palette-obsidian

# 管理者権限の PowerShell で実行
.\scripts\install.ps1
```

スクリプトが自動で以下を実行します:
- 開発者モードの確認
- `dotnet restore` & `dotnet build`
- MSIX パッケージのインストール

### 方法C: Visual Studio

1. `CommandPaletteObsidian.sln` を Visual Studio 2022+ で開く
   - ワークロード: .NET デスクトップ開発 + Windows アプリケーション開発
2. プラットフォームを **x64** に設定
3. **ビルド → ソリューションの配置** (Build → Deploy Solution)

## Usage

1. **Win + Alt + Space** で Command Palette を開く
2. `Search Obsidian Notes` と入力
3. ノートのタイトルやフォルダ名で検索
4. 選択すると Obsidian でノートが開く

## Uninstall

```powershell
.\scripts\uninstall.ps1
```

または Windows の **設定 → アプリ → インストール済みアプリ** から `Command Palette - Obsidian Notes` を削除。

## Development

```
dotnet restore
dotnet build
dotnet test
```

> **Note:** フルビルドには Windows が必要です (WinRT/CsWinRT)。
> Linux/macOS ではテストプロジェクトのみビルド・実行可能です。

## Project Structure

```
├── src/CommandPaletteObsidian/
│   ├── CommandPaletteObsidian.cs          # IExtension implementation
│   ├── CommandPaletteObsidianCommandsProvider.cs  # CommandProvider
│   ├── Program.cs                         # COM server entry point
│   ├── Pages/
│   │   └── ObsidianSearchPage.cs          # DynamicListPage for note search
│   ├── Helpers/
│   │   ├── ObsidianVaultDiscovery.cs      # Vault/note discovery
│   │   └── OpenNoteCommand.cs             # obsidian:// URI opener
│   └── Package.appxmanifest               # MSIX manifest
├── tests/CommandPaletteObsidian.Tests/
│   └── ObsidianVaultDiscoveryTests.cs     # Unit tests for core logic
├── scripts/
│   ├── install.ps1                        # Build & install script
│   └── uninstall.ps1                      # Uninstall script
├── Directory.Build.props
├── Directory.Packages.props
└── CommandPaletteObsidian.sln
```

## How It Works

1. On search page open, reads `%APPDATA%\obsidian\obsidian.json` to discover vaults
2. Enumerates all `.md` files in each vault (excluding `.obsidian/` config folder)
3. Filters notes by search query (matches title and relative path)
4. Opens selected note via `obsidian://open?vault={vault}&file={file}`

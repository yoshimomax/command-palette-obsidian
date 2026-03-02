using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;
using CommandPaletteObsidian.Pages;

namespace CommandPaletteObsidian;

public partial class CommandPaletteObsidianCommandsProvider : ICommandProvider
{
    public string DisplayName => "Obsidian Notes";

    public IconInfo Icon => new("\uE70B"); // Segoe Fluent: Document

    #pragma warning disable CS0067
    public event EventHandler? CommandsChanged;
    #pragma warning restore CS0067

    public ICommandItem[] TopLevelCommands()
    {
        return [new CommandItem(new ObsidianSearchPage())
        {
            Title = "Search Obsidian Notes",
            Subtitle = "Search and open notes from your Obsidian vaults",
        }];
    }

    public void Dispose() { }
}

using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;
using CommandPaletteObsidian.Pages;

namespace CommandPaletteObsidian;

public sealed partial class CommandPaletteObsidianCommandsProvider : CommandProvider
{
    private readonly ICommandItem[] _commands;

    public CommandPaletteObsidianCommandsProvider()
    {
        DisplayName = "Obsidian Notes";
        Icon = new IconInfo("\uE70B"); // Segoe Fluent: Document

        _commands = [
            new CommandItem(new ObsidianSearchPage())
            {
                Title = "Search Obsidian Notes",
                Subtitle = "Search and open notes from your Obsidian vaults",
            }
        ];
    }

    public override ICommandItem[] TopLevelCommands() => _commands;
}

using System.Diagnostics;
using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;

namespace CommandPaletteObsidian.Helpers;

/// <summary>
/// Command that opens an Obsidian note via the obsidian:// URI scheme.
/// </summary>
public partial class OpenNoteCommand : InvokableCommand
{
    private readonly ObsidianVaultDiscovery.NoteInfo _note;

    public OpenNoteCommand(ObsidianVaultDiscovery.NoteInfo note)
    {
        _note = note;
        Name = "Open";
        Icon = new IconInfo("\uE8A7"); // Segoe Fluent: OpenFile
    }

    public override ICommandResult Invoke()
    {
        try
        {
            var filePathWithoutExtension = Path.ChangeExtension(_note.RelativePath, null);
            var encodedVault = Uri.EscapeDataString(_note.VaultName);
            var encodedFile = Uri.EscapeDataString(filePathWithoutExtension.Replace('\\', '/'));
            var uri = $"obsidian://open?vault={encodedVault}&file={encodedFile}";

            Process.Start(new ProcessStartInfo(uri)
            {
                UseShellExecute = true,
            });
        }
        catch (Exception)
        {
            // Failed to open the URI; silently ignore
        }

        return CommandResult.Hide();
    }
}

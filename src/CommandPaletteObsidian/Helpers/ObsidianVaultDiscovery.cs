using System.Text.Json;

namespace CommandPaletteObsidian.Helpers;

/// <summary>
/// Discovers Obsidian vaults by reading the application config at %APPDATA%\obsidian\obsidian.json.
/// </summary>
public static class ObsidianVaultDiscovery
{
    public record VaultInfo(string Name, string Path);

    public record NoteInfo(string Title, string RelativePath, string VaultName, string VaultPath)
    {
        public string FullPath => System.IO.Path.Combine(VaultPath, RelativePath);
    }

    private static string GetObsidianConfigPath()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        return Path.Combine(appData, "obsidian", "obsidian.json");
    }

    /// <summary>
    /// Reads the Obsidian config file and returns a list of discovered vaults.
    /// </summary>
    public static List<VaultInfo> DiscoverVaults()
    {
        var vaults = new List<VaultInfo>();
        var configPath = GetObsidianConfigPath();

        if (!File.Exists(configPath))
        {
            return vaults;
        }

        try
        {
            var json = File.ReadAllText(configPath);
            using var doc = JsonDocument.Parse(json);

            if (!doc.RootElement.TryGetProperty("vaults", out var vaultsElement))
            {
                return vaults;
            }

            foreach (var vaultEntry in vaultsElement.EnumerateObject())
            {
                if (vaultEntry.Value.TryGetProperty("path", out var pathElement))
                {
                    var vaultPath = pathElement.GetString();
                    if (!string.IsNullOrEmpty(vaultPath) && Directory.Exists(vaultPath))
                    {
                        var vaultName = Path.GetFileName(vaultPath);
                        vaults.Add(new VaultInfo(vaultName, vaultPath));
                    }
                }
            }
        }
        catch (Exception)
        {
            // Config file is unreadable or malformed; return empty list
        }

        return vaults;
    }

    /// <summary>
    /// Enumerates all markdown (.md) notes in the given vault, excluding the .obsidian config folder.
    /// </summary>
    public static List<NoteInfo> EnumerateNotes(VaultInfo vault)
    {
        var notes = new List<NoteInfo>();

        try
        {
            var mdFiles = Directory.EnumerateFiles(vault.Path, "*.md", SearchOption.AllDirectories);

            foreach (var filePath in mdFiles)
            {
                var relativePath = Path.GetRelativePath(vault.Path, filePath);

                if (relativePath.StartsWith(".obsidian", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                var title = Path.GetFileNameWithoutExtension(filePath);
                notes.Add(new NoteInfo(title, relativePath, vault.Name, vault.Path));
            }
        }
        catch (Exception)
        {
            // Access denied or other I/O errors; skip this vault
        }

        return notes;
    }

    /// <summary>
    /// Discovers all vaults and returns all notes across all vaults.
    /// </summary>
    public static List<NoteInfo> DiscoverAllNotes()
    {
        var allNotes = new List<NoteInfo>();

        foreach (var vault in DiscoverVaults())
        {
            allNotes.AddRange(EnumerateNotes(vault));
        }

        return allNotes;
    }
}

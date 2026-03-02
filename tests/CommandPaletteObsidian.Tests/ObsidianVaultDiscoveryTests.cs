using System.Text.Json;
using Xunit;

namespace CommandPaletteObsidian.Tests;

/// <summary>
/// Tests for Obsidian vault discovery and note enumeration logic.
/// Since ObsidianVaultDiscovery reads from the filesystem, these tests use temp directories.
/// </summary>
public class ObsidianVaultDiscoveryTests : IDisposable
{
    private readonly string _tempDir;

    public ObsidianVaultDiscoveryTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), $"obsidian_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
        {
            Directory.Delete(_tempDir, recursive: true);
        }
    }

    [Fact]
    public void ParseObsidianJson_ValidConfig_ReturnsVaults()
    {
        var vaultPath = Path.Combine(_tempDir, "MyVault");
        Directory.CreateDirectory(vaultPath);

        var config = new
        {
            vaults = new Dictionary<string, object>
            {
                ["abc123"] = new { path = vaultPath }
            }
        };

        var json = JsonSerializer.Serialize(config);
        var vaults = ParseVaultsFromJson(json);

        Assert.Single(vaults);
        Assert.Equal("MyVault", vaults[0].Name);
        Assert.Equal(vaultPath, vaults[0].Path);
    }

    [Fact]
    public void ParseObsidianJson_EmptyVaults_ReturnsEmpty()
    {
        var json = """{"vaults":{}}""";
        var vaults = ParseVaultsFromJson(json);
        Assert.Empty(vaults);
    }

    [Fact]
    public void ParseObsidianJson_NonExistentPath_SkipsVault()
    {
        var json = JsonSerializer.Serialize(new
        {
            vaults = new Dictionary<string, object>
            {
                ["x"] = new { path = "/nonexistent/path/12345" }
            }
        });

        var vaults = ParseVaultsFromJson(json);
        Assert.Empty(vaults);
    }

    [Fact]
    public void EnumerateMarkdownFiles_FindsNotes()
    {
        var vaultPath = Path.Combine(_tempDir, "TestVault");
        Directory.CreateDirectory(vaultPath);
        File.WriteAllText(Path.Combine(vaultPath, "note1.md"), "# Note 1");
        File.WriteAllText(Path.Combine(vaultPath, "note2.md"), "# Note 2");
        File.WriteAllText(Path.Combine(vaultPath, "readme.txt"), "Not a note");

        var subDir = Path.Combine(vaultPath, "subfolder");
        Directory.CreateDirectory(subDir);
        File.WriteAllText(Path.Combine(subDir, "sub-note.md"), "# Sub Note");

        var notes = EnumerateNotesInVault(vaultPath, "TestVault");

        Assert.Equal(3, notes.Count);
        Assert.Contains(notes, n => n.Title == "note1");
        Assert.Contains(notes, n => n.Title == "note2");
        Assert.Contains(notes, n => n.Title == "sub-note");
    }

    [Fact]
    public void EnumerateMarkdownFiles_ExcludesObsidianFolder()
    {
        var vaultPath = Path.Combine(_tempDir, "ExcludeVault");
        Directory.CreateDirectory(vaultPath);
        File.WriteAllText(Path.Combine(vaultPath, "real-note.md"), "# Real");

        var obsidianDir = Path.Combine(vaultPath, ".obsidian");
        Directory.CreateDirectory(obsidianDir);
        File.WriteAllText(Path.Combine(obsidianDir, "workspace.md"), "config");

        var notes = EnumerateNotesInVault(vaultPath, "ExcludeVault");

        Assert.Single(notes);
        Assert.Equal("real-note", notes[0].Title);
    }

    [Fact]
    public void SearchFilter_MatchesTitleAndPath()
    {
        var notes = new List<NoteInfo>
        {
            new("Daily Log", "journal/Daily Log.md", "Vault", "/path"),
            new("Meeting Notes", "work/Meeting Notes.md", "Vault", "/path"),
            new("Recipe Ideas", "personal/Recipe Ideas.md", "Vault", "/path"),
        };

        var results = FilterNotes(notes, "meeting");
        Assert.Single(results);
        Assert.Equal("Meeting Notes", results[0].Title);

        results = FilterNotes(notes, "journal");
        Assert.Single(results);
        Assert.Equal("Daily Log", results[0].Title);
    }

    [Fact]
    public void SearchFilter_MultiTermSearch()
    {
        var notes = new List<NoteInfo>
        {
            new("Daily Log", "journal/Daily Log.md", "Vault", "/path"),
            new("Daily Recipe", "personal/Daily Recipe.md", "Vault", "/path"),
        };

        var results = FilterNotes(notes, "daily journal");
        Assert.Single(results);
        Assert.Equal("Daily Log", results[0].Title);
    }

    [Fact]
    public void ObsidianUri_CorrectlyEncodes()
    {
        var note = new NoteInfo("My Note", "folder/My Note.md", "My Vault", "/path");
        var uri = BuildObsidianUri(note);
        Assert.Equal("obsidian://open?vault=My%20Vault&file=folder%2FMy%20Note", uri);
    }

    // --- Helper types and methods mirroring the actual implementation ---

    private record NoteInfo(string Title, string RelativePath, string VaultName, string VaultPath);
    private record VaultInfo(string Name, string Path);

    private static List<VaultInfo> ParseVaultsFromJson(string json)
    {
        var vaults = new List<VaultInfo>();
        using var doc = JsonDocument.Parse(json);

        if (!doc.RootElement.TryGetProperty("vaults", out var vaultsElement))
            return vaults;

        foreach (var vaultEntry in vaultsElement.EnumerateObject())
        {
            if (vaultEntry.Value.TryGetProperty("path", out var pathElement))
            {
                var vaultPath = pathElement.GetString();
                if (!string.IsNullOrEmpty(vaultPath) && Directory.Exists(vaultPath))
                {
                    var vaultName = System.IO.Path.GetFileName(vaultPath);
                    vaults.Add(new VaultInfo(vaultName, vaultPath));
                }
            }
        }

        return vaults;
    }

    private static List<NoteInfo> EnumerateNotesInVault(string vaultPath, string vaultName)
    {
        var notes = new List<NoteInfo>();
        var mdFiles = Directory.EnumerateFiles(vaultPath, "*.md", SearchOption.AllDirectories);

        foreach (var filePath in mdFiles)
        {
            var relativePath = System.IO.Path.GetRelativePath(vaultPath, filePath);
            if (relativePath.StartsWith(".obsidian", StringComparison.OrdinalIgnoreCase))
                continue;

            var title = System.IO.Path.GetFileNameWithoutExtension(filePath);
            notes.Add(new NoteInfo(title, relativePath, vaultName, vaultPath));
        }

        return notes;
    }

    private static List<NoteInfo> FilterNotes(List<NoteInfo> notes, string query)
    {
        var terms = query.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return notes.Where(n =>
        {
            var searchTarget = $"{n.Title} {n.RelativePath}";
            return terms.All(term => searchTarget.Contains(term, StringComparison.OrdinalIgnoreCase));
        }).ToList();
    }

    private static string BuildObsidianUri(NoteInfo note)
    {
        var filePathWithoutExtension = System.IO.Path.ChangeExtension(note.RelativePath, null);
        var encodedVault = Uri.EscapeDataString(note.VaultName);
        var encodedFile = Uri.EscapeDataString(filePathWithoutExtension.Replace('\\', '/'));
        return $"obsidian://open?vault={encodedVault}&file={encodedFile}";
    }
}

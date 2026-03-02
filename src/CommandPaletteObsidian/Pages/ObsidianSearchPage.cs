using Microsoft.CommandPalette.Extensions;
using Microsoft.CommandPalette.Extensions.Toolkit;
using CommandPaletteObsidian.Helpers;

namespace CommandPaletteObsidian.Pages;

/// <summary>
/// A dynamic list page that searches Obsidian notes by title across all discovered vaults.
/// Notes are cached on first load and refreshed when the page is shown.
/// </summary>
public partial class ObsidianSearchPage : DynamicListPage
{
    private List<ObsidianVaultDiscovery.NoteInfo> _allNotes = [];
    private string _searchText = string.Empty;
    private bool _loaded;

    public ObsidianSearchPage()
    {
        Icon = new IconInfo("\uE8B7"); // Segoe Fluent: Search
        Title = "Search Obsidian Notes";
        Name = "Open";
        PlaceholderText = "Type to search notes...";
        ShowDetails = true;
    }

    public override void UpdateSearchText(string oldSearch, string newSearch)
    {
        if (!_loaded)
        {
            LoadNotes();
        }

        _searchText = newSearch;
        RaiseItemsChanged();
    }

    public override IListItem[] GetItems()
    {
        if (!_loaded)
        {
            LoadNotes();
        }

        var filtered = string.IsNullOrWhiteSpace(_searchText)
            ? _allNotes
            : _allNotes.Where(n => MatchesSearch(n, _searchText)).ToList();

        var maxResults = 50;
        return filtered
            .Take(maxResults)
            .Select(NoteToListItem)
            .ToArray();
    }

    private void LoadNotes()
    {
        _allNotes = ObsidianVaultDiscovery.DiscoverAllNotes();
        _loaded = true;
    }

    private static bool MatchesSearch(ObsidianVaultDiscovery.NoteInfo note, string query)
    {
        var terms = query.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var searchTarget = $"{note.Title} {note.RelativePath}";

        return terms.All(term =>
            searchTarget.Contains(term, StringComparison.OrdinalIgnoreCase));
    }

    private static ListItem NoteToListItem(ObsidianVaultDiscovery.NoteInfo note)
    {
        var folderPath = Path.GetDirectoryName(note.RelativePath)?.Replace('\\', '/');
        var subtitle = string.IsNullOrEmpty(folderPath)
            ? note.VaultName
            : $"{note.VaultName}/{folderPath}";

        return new ListItem(new OpenNoteCommand(note))
        {
            Title = note.Title,
            Subtitle = subtitle,
            Tags = [new Tag(note.VaultName)],
        };
    }
}

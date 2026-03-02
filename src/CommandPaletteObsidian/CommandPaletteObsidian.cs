using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.CommandPalette.Extensions;

namespace CommandPaletteObsidian;

[ComVisible(true)]
[Guid("B8E5F4A2-9C3D-4E7F-A1B6-2D8F0E3C5A9B")]
[ComDefaultInterface(typeof(IExtension))]
public sealed partial class CommandPaletteObsidian : IExtension, IDisposable
{
    private readonly ManualResetEvent _extensionDisposedEvent;
    private readonly CommandPaletteObsidianCommandsProvider _provider = new();

    public CommandPaletteObsidian(ManualResetEvent extensionDisposedEvent)
    {
        _extensionDisposedEvent = extensionDisposedEvent;
    }

    public object? GetProvider(ProviderType providerType)
    {
        return providerType switch
        {
            ProviderType.Commands => _provider,
            _ => null,
        };
    }

    public void Dispose()
    {
        _extensionDisposedEvent.Set();
    }
}

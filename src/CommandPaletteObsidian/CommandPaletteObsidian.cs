using Microsoft.CommandPalette.Extensions;
using System.Runtime.InteropServices;

namespace CommandPaletteObsidian;

[ComVisible(true)]
[Guid("B8E5F4A2-9C3D-4E7F-A1B6-2D8F0E3C5A9B")]
[ComDefaultInterface(typeof(IExtension))]
public sealed partial class CommandPaletteObsidian : IExtension
{
    private readonly ManualResetEvent _extensionDisposedEvent = new(false);
    private IExtensionHost? _host;

    public object? GetProvider(ProviderType providerType)
    {
        return providerType switch
        {
            ProviderType.Commands => new CommandPaletteObsidianCommandsProvider(),
            _ => null,
        };
    }

    public void Initialize(IExtensionHost host)
    {
        _host = host;
    }

    public void Dispose()
    {
        _extensionDisposedEvent.Set();
    }
}

using System.Threading;
using Microsoft.CommandPalette.Extensions;
using Shmuelie.WinRTServer;
using Shmuelie.WinRTServer.CsWinRT;

namespace CommandPaletteObsidian;

public class Program
{
    [MTAThread]
    public static void Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "-RegisterProcessAsComServer")
        {
            using var server = new ComServer();
            var extensionDisposedEvent = new ManualResetEvent(false);

            var extensionInstance = new CommandPaletteObsidian(extensionDisposedEvent);
            server.RegisterClass<CommandPaletteObsidian, IExtension>(() => extensionInstance);
            server.Start();

            extensionDisposedEvent.WaitOne();
            server.Stop();
        }
    }
}

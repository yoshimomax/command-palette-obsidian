using Microsoft.CommandPalette.Extensions;

namespace CommandPaletteObsidian;

public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "-RegisterProcessAsComServer")
        {
            ComServer.RegisterAndRun<CommandPaletteObsidian>(() => new CommandPaletteObsidian());
        }
    }
}

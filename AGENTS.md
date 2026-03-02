# AGENTS.md

## Cursor Cloud specific instructions

This is an **Obsidian plugin** project (`command-palette-obsidian`). The plugin provides a command palette with greeting modal and notice commands.

### Tech stack
- **Language:** TypeScript
- **Bundler:** esbuild
- **Linter:** ESLint with `@typescript-eslint`
- **Runtime:** Obsidian desktop app (plugin cannot run standalone)

### Key commands
| Task | Command |
|------|---------|
| Install dependencies | `npm install` |
| Lint | `npm run lint` |
| Type check | `npx tsc -noEmit -skipLibCheck` |
| Build (production) | `npm run build` |
| Dev (watch mode) | `npm run dev` |

### Important notes
- `npm run dev` starts esbuild in **watch mode** — it does not exit and watches for file changes. Use `timeout` or run in the background when scripting.
- The plugin requires the Obsidian desktop app to run. In a headless cloud environment, verification is limited to lint, type check, and build. The build output (`main.js`, `manifest.json`, `styles.css`) can be validated structurally.
- The built `main.js` is gitignored — always run `npm run build` to regenerate it.

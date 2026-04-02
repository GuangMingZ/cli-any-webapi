# /cli-any-webapi list

List all generated CLI packages in a directory, showing module counts, endpoint counts, and build status.

## Usage

```bash
/cli-any-webapi list [--path <search-dir>] [--depth <n>] [--json]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--path <search-dir>` | No | Directory to search for generated CLI packages. Default: current working directory |
| `--depth <n>` | No | How many directory levels to search. Default: 2 |
| `--json` | No | Output as JSON array instead of human-readable table |

## Examples

```bash
# List in current directory
/cli-any-webapi list

# List in specific directory, deeper search
/cli-any-webapi list --path ~/projects --depth 3

# Machine-readable output for AI Agent consumption
/cli-any-webapi list --json
```

## What this command does

### Step 1 — Find generated packages

Search `--path` up to `--depth` levels for directories that:
- Contain a `package.json` with a `bin` field pointing to `./dist/index.js`
- Contain a `SKILL.md` file
- Contain a `src/` directory with `commands/` and `types/` subdirectories

### Step 2 — Collect metadata for each package

For each found package:

| Field | How to determine |
|-------|-----------------|
| Package name | `package.json` → `name` field |
| Version | `package.json` → `version` field |
| CLI command | `package.json` → `bin` key name |
| Modules | Count of files in `src/commands/` (excluding `index.ts`) |
| Endpoints | Sum of command registrations across all `src/commands/*.ts` |
| Build status | Check if `dist/index.js` exists |
| Auth type | Check if `src/auth/` directory exists |
| Last generated | File modification time of `SKILL.md` |

### Step 3 — Output

**Human-readable (default):**

```
cli-any-webapi — Generated CLI Packages
Found 2 package(s) in /Users/me/projects (depth: 2)

┌─────────────────────┬─────────┬─────────┬───────────┬──────────┬──────┬────────────────────┐
│ Package             │ Version │ Modules │ Endpoints │ Built    │ Auth │ Last Generated     │
├─────────────────────┼─────────┼─────────┼───────────┼──────────┼──────┼────────────────────┤
│ my-app-api-cli      │ 1.0.0   │ 4       │ 18        │ ✅ Yes   │ ✅   │ 2026-03-15 14:32   │
│ another-app-api-cli │ 1.0.0   │ 2       │ 7         │ ❌ No    │ ✅   │ 2026-03-10 09:11   │
└─────────────────────┴─────────┴─────────┴───────────┴──────────┴──────┴────────────────────┘

To use: cd <package-dir> && npm run build && node dist/index.js --help
Config: project-local config.json
```

**JSON output (--json):**

```json
[
  {
    "name": "my-app-api-cli",
    "version": "1.0.0",
    "cliCommand": "my-app-api-cli",
    "path": "/Users/me/projects/my-app-api-cli",
    "modules": ["user", "order", "product", "auth"],
    "endpointCount": 18,
    "built": true,
    "hasAuth": true,
    "lastGenerated": "2026-03-15T14:32:00.000Z",
    "skillMdPath": "/Users/me/projects/my-app-api-cli/SKILL.md"
  }
]
```

## Notes

- A package with `built: false` can be built by running `npm install && npm run build` inside its directory
- For AI Agent usage, prefer `--json` output for programmatic consumption
- To see all available commands for a package, read its `SKILL.md` file

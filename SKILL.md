---
name: "cli-any-webapi"
description: "This skill converts Web system HTTP REST APIs into type-safe TypeScript CLI packages. It analyzes backend source code and API request logs (HAR, CSV, JSON Lines) to auto-generate a complete CLI with three-level commands (module → method → path), config-driven auth (Bearer Token + Cookie Session), and AI-Agent-friendly JSON output. Use this when the user wants to generate CLI commands for their API, convert API to CLI, or enable programmatic API access."
allowed-tools: "read_file, write_to_file, replace_in_file, execute_command, list_dir, search_file, search_content"
disable: false
---

# cli-any-webapi

A CodeBuddy / Claude Code skill & slash command plugin that converts Web system HTTP APIs into type-safe TypeScript CLI packages. AI Agents use the generated CLI to call APIs directly via shell commands instead of simulating browser interactions.

## When To Use

Trigger conditions:
- User wants to turn a Web API into a CLI tool
- User provides a backend source code path and wants CLI access to its APIs
- User has a HAR/CSV/JSONL capture file and wants typed CLI commands from it
- User wants AI Agent to be able to call their Web APIs via shell
- User says "generate CLI for my API", "convert API to CLI", "create CLI commands for my backend"

## Slash Commands

### `/cli-any-webapi generate` — Full generation

```bash
/cli-any-webapi generate <source-path> [--logs <log-file>] [--out <output-dir>] [--name <project-name>]
```

Analyze source code + API logs → generate complete TypeScript CLI package.

### `/cli-any-webapi add` — Add single endpoint

```bash
/cli-any-webapi add <cli-path> <module> <method> <api-path> [--params-schema <json>] [--response-schema <json>]
```

Add one endpoint to an existing CLI package without regenerating.

### `/cli-any-webapi sync` — Incremental re-sync

```bash
/cli-any-webapi sync <cli-path> [--source <source-path>] [--logs <log-file>]
```

Re-sync after source/logs are updated. Preserves manual edits; deprecated endpoints are commented out, never deleted.

### `/cli-any-webapi list` — List generated packages

```bash
/cli-any-webapi list [--path <search-dir>] [--depth <n>] [--json]
```

List all generated CLI packages in a directory with metadata.

## Execution Process

**Before doing anything else, read `./HARNESS.md`** — it defines the complete methodology for API extraction, log parsing, module naming, and TypeScript code generation standards. Do not improvise; follow the harness specification exactly.

### Phases

| Phase | Description |
|-------|-------------|
| 0 | Input validation: verify source path, log file, environment (Node >= 18), output dir conflict check |
| 1 | Source code analysis: discover all HTTP endpoints from backend source |
| 2 | Log shape analysis: infer TypeScript types from HAR/CSV/JSONL logs |
| 3 | Module grouping: resolve naming conflicts, produce final APISpec |
| 4 | Type generation: create `src/types/<module>.ts` with typed interfaces |
| 5 | Command generation: create `src/commands/<module>.ts` with Commander.js |
| 6 | Package config: `package.json`, `tsconfig.json`, `SKILL.md` |
| 7 | Validation: build, `--help` output, SKILL.md completeness, TEST.md |

## Templates Reference

All templates live in the `templates/` directory alongside this SKILL.md:

| Template | Purpose |
|----------|---------|
| `package.json.template` | npm package config with commander + tsup (zero-dep HTTP via native fetch) |
| `tsconfig.json.template` | TypeScript strict mode config (ESM + Bundler) |
| `config.ts.template` | Config loader from project-local `config.json` |
| `http-client.ts.template` | Native fetch client with config headers injection + AbortController timeout |
| `auth-bearer.ts.template` | Bearer Token → `config.headers.Authorization` |
| `auth-cookie.ts.template` | Cookie Session → `config.headers.Cookie` |
| `auth-index.ts.template` | Auth command group (login/logout/status) |
| `index.ts.template` | CLI entry point with `outputResult` + `resolvePath` |
| `common.types.ts.template` | APIResponse, RequestOptions, CliConfig types |
| `module.types.ts.template` | Per-module request/response type declarations |
| `module.command.ts.template` | Per-module Commander command with all HTTP methods |
| `SKILL.md.template` | SKILL.md for the generated CLI (with per-endpoint examples) |

## Generated CLI Usage

### Command Structure

```
<project>-api-cli <module> <method> <path> [options]

Options:
  --params <json>       Query params (GET/DELETE) or request body (POST/PUT/PATCH)
  --path-params <json>  Path parameter values, e.g. {"id":"123"}
  --headers <json>      Additional request headers
  --base-url <url>      Override base URL from config.json
  --output <format>     Output format: json | table | raw  [default: json]
```

### Configuration

Config file is located at the project root: `<project>-api-cli/config.json` (project-local).

```json
{
  "baseUrl": "http://localhost:3000",
  "headers": {
    "Authorization": "Bearer <your-token>"
  },
  "timeout": 30000
}
```

### Authentication

Two equivalent ways to configure auth:

```bash
# Option 1: Auth commands (recommended for interactive use)
<project>-api-cli auth login --token <bearer-token>
<project>-api-cli auth login --cookie "session=abc; csrf=xyz"
<project>-api-cli auth status
<project>-api-cli auth logout

# Option 2: Edit project-local config file directly (recommended for AI Agents)
cat > <project>-api-cli/config.json << 'EOF'
{
  "baseUrl": "http://localhost:3000",
  "headers": { "Authorization": "Bearer <token>" }
}
EOF
```

### Example API Calls

```bash
# Query a list with pagination
<project>-api-cli user get /api/v1/users --params='{"page":1,"pageSize":20}'

# Get a single record by ID
<project>-api-cli user get /api/v1/users/:id --path-params='{"id":"123"}'

# Create a record
<project>-api-cli user post /api/v1/users --params='{"name":"Alice","email":"alice@example.com"}'

# Update a record
<project>-api-cli user put /api/v1/users/:id --path-params='{"id":"123"}' --params='{"email":"new@example.com"}'

# Delete a record
<project>-api-cli user delete /api/v1/users/:id --path-params='{"id":"123"}'

# Use table output for human readability
<project>-api-cli user get /api/v1/users --output=table

# Override auth header for single request
<project>-api-cli order get /api/v1/orders --headers='{"Authorization":"Bearer <other-token>"}'
```

### Output Format

All commands output JSON to stdout by default. Errors are written to stderr as:
```json
{ "error": true, "status": 401, "data": { "message": "Unauthorized" } }
```

Exit code is `1` on error, `0` on success.

## Success Criteria

The command succeeds when:
1. `API_SPEC.md` documents all discovered API routes
2. `npm run build` passes with zero TypeScript errors
3. `--help` shows all module commands at every level
4. `SKILL.md` generated with YAML frontmatter + complete command docs
5. Output directory matches the structure defined in HARNESS.md

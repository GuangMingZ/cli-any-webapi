# cli-any-webapi

[English](./README.md) | [中文](./README_ZH.md)

> A Claude Code / CodeBuddy plugin that converts Web system HTTP REST APIs into fully-typed TypeScript CLI packages, enabling AI Agents to call APIs directly via CLI commands.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://code.claude.com/docs/en/plugins)
[![CodeBuddy Plugin](https://img.shields.io/badge/CodeBuddy-Plugin-green)](https://www.codebuddy.ai)
[![Node.js >= 18](https://img.shields.io/badge/node-%3E%3D18-brightgreen)](https://nodejs.org)

---

## Why cli-any-webapi?

CLI is the "primitive" of AI Agents. Instead of simulating browser interactions, AI Agents should call APIs directly through CLI commands. `cli-any-webapi` bridges that gap:

- Analyzes your backend **source code** (NestJS, Express, Fastify, Koa, Hono, Spring Boot, Gin, Django) to discover all API endpoints
- Analyzes **API request logs** (HAR, CSV, JSON Lines, JSON array) to infer TypeScript types for every parameter and response
- Generates a **complete TypeScript CLI package** with multi-level commands, full type safety, and AI-friendly JSON output
- Supports **Bearer Token + Cookie Session** dual authentication out of the box

The generated CLI follows a consistent three-level structure:

```
<project>-api-cli <module> <method> <path> [options]

my-app-api user get /api/v1/user --params='{"page":1}'
my-app-api order post /api/v1/order --params='{"productId":1,"qty":2}'
my-app-api user delete /api/v1/user/:id --path-params='{"id":"123"}'
```

---

## Installation

### Option 1: Claude Code Plugin Directory (Recommended)

```bash
/plugin install cli-any-webapi
```

### Option 2: From GitHub

```bash
cd ~/.claude/plugins
git clone https://github.com/GuangMingZ/cli-any-webapi.git
```

### Option 3: From npm

```bash
cd ~/.claude/plugins
npm install @GuangMingZ/cli-any-webapi
```

### Option 4: CodeBuddy Skill (Project-Level)

Copy the plugin to your project's CodeBuddy skills directory:

```bash
mkdir -p .codebuddy/skills
cp -r /path/to/cli-any-webapi .codebuddy/skills/cli-any-webapi
```

Or for global access (all projects):

```bash
mkdir -p ~/.codebuddy/skills
cp -r /path/to/cli-any-webapi ~/.codebuddy/skills/cli-any-webapi
```

### Option 5: Local (Development)

```bash
cp -r /path/to/cli-any-webapi ~/.claude/plugins/cli-any-webapi
```

Reload plugins after installation:

```bash
/reload-plugins
```

---

## Prerequisites

- **Node.js >= 18** — for the generated CLI runtime
- **npm** — package manager

Run the setup checker to verify your environment:

```bash
bash ~/.claude/plugins/cli-any-webapi/scripts/setup.sh
```

---

## Quick Start

**5-minute walkthrough:** See [QUICKSTART.md](./QUICKSTART.md)

```bash
# 1. Generate a CLI from your backend source + API logs
/cli-any-webapi generate ./my-backend --logs ./api-logs.har

# 2. Build and install the generated CLI
cd my-backend-api-cli
npm install && npm run build && npm link

# 3. Configure authentication (project-local config)
cat > my-backend-api-cli/config.json << 'EOF'
{
  "baseUrl": "http://localhost:3000",
  "headers": {
    "Authorization": "Bearer <your-token>"
  },
  "timeout": 30000
}
EOF

# 4. Use it!
my-backend-api user get /api/v1/user --params='{"page":1,"pageSize":10}'
```

---

## Slash Commands

### `/cli-any-webapi generate`

Full generation: analyze source code + API logs → TypeScript CLI package.

```bash
/cli-any-webapi generate <source-path> [--logs <log-file>] [--out <output-dir>] [--name <project-name>]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `source-path` | Yes | Path to the Web system source code directory |
| `--logs <log-file>` | Recommended | API request log file (`.har`, `.csv`, `.jsonl`, `.json`) |
| `--out <output-dir>` | No | Output directory. Default: `./<source-name>-api-cli` |
| `--name <project-name>` | No | Override CLI package name |

**Supported log formats:**
- **HAR** (`.har`) — browser-exported HTTP archive
- **CSV** (`.csv`) — first row is header; column names define field semantics (auto-mapped)
- **JSON Lines** (`.jsonl`) — one JSON request object per line
- **JSON Array** (`.json`) — array of request objects

### `/cli-any-webapi add`

Add a single endpoint to an existing CLI package without regenerating.

```bash
/cli-any-webapi add <cli-path> <module> <method> <api-path> [--params-schema <json>] [--response-schema <json>]
```

### `/cli-any-webapi sync`

Incrementally re-sync after source code or logs are updated. Preserves manual edits.

```bash
/cli-any-webapi sync <cli-path> [--source <source-path>] [--logs <log-file>]
```

### `/cli-any-webapi list`

List all generated CLI packages in a directory.

```bash
/cli-any-webapi list [--path <search-dir>] [--depth <n>] [--json]
```

---

## Generated CLI

### Command Structure

```
<project>-api-cli <module> <method> <path> [options]
```

| Level | Example | Description |
|-------|---------|-------------|
| Module | `user` | Backend module or domain (from Controller name or URL segment) |
| Method | `get` | HTTP method: `get` / `post` / `put` / `patch` / `delete` |
| Path | `/api/v1/user` | Full API path (supports `:param` placeholders) |

### Options (all commands)

| Option | Description |
|--------|-------------|
| `--params <json>` | Query params (GET/DELETE) or request body (POST/PUT/PATCH) |
| `--path-params <json>` | Path parameter values, e.g. `{"id":"123"}` |
| `--headers <json>` | Additional request headers |
| `--base-url <url>` | Override base URL from config file |
| `--output <format>` | Output format: `json` (default) / `table` / `raw` |

### Authentication

The generated CLI supports **config-driven authentication**. Credentials are stored in the project-local `<project>-api-cli/config.json` as HTTP headers. Each CLI project has its own independent config file.

**Option 1: Edit config file directly (recommended for AI Agents)**

```bash
cat > <project>-api-cli/config.json << 'EOF'
{
  "baseUrl": "http://localhost:3000",
  "headers": {
    "Authorization": "Bearer <your-token>",
    "Cookie": "session=abc; csrf=xyz"
  },
  "timeout": 30000
}
EOF
```

**Option 2: Auth commands (recommended for interactive use)**

```bash
# Login with Bearer Token (saves to config.json headers.Authorization)
my-app-api auth login --token <bearer-token>

# Login with Cookie Session (saves to config.json headers.Cookie)
my-app-api auth login --cookie "session=abc123; csrf=xyz"

# Check auth status (shows configured credentials with truncated preview)
my-app-api auth status

# Check auth status as JSON (for AI Agent consumption)
my-app-api auth status --json

# Logout (clears auth headers from config.json)
my-app-api auth logout
```

### Configuration

Create `<project>-api-cli/config.json` for persistent settings:

```json
{
  "baseUrl": "http://localhost:3000",
  "headers": {
    "Authorization": "Bearer <your-token>"
  },
  "timeout": 30000
}
```

Each generated CLI reads from its own project-local config. You can also override per-request:

```bash
# Override base URL
my-app-api user get /api/v1/user --base-url http://staging.example.com

# Override headers
my-app-api user get /api/v1/user --headers='{"X-Custom":"value"}'
```

### Example Usage

```bash
# List users with pagination
my-app-api user get /api/v1/user --params='{"page":1,"pageSize":20}'

# Get user by ID (explicit path params)
my-app-api user get /api/v1/user/:id --path-params='{"id":"42"}'

# Create a user
my-app-api user post /api/v1/user --params='{"username":"alice","email":"alice@example.com"}'

# Update a user
my-app-api user put /api/v1/user/:id --path-params='{"id":"42"}' --params='{"email":"new@example.com"}'

# Delete a user
my-app-api user delete /api/v1/user/:id --path-params='{"id":"42"}'

# Use table output
my-app-api user get /api/v1/user --output=table

# Use custom auth header for this request
my-app-api order get /api/v1/order --headers='{"Authorization":"Bearer eyJ..."}'
```

---

## Generated Package Structure

```
<project>-api-cli/
├── package.json          # CLI package config (commander + tsup, zero-dep HTTP via native fetch)
├── tsconfig.json         # TypeScript strict mode
├── src/
│   ├── index.ts          # Commander.js root program
│   ├── client.ts         # Native fetch client with config integration
│   ├── config.ts         # Project-local config.json loader
│   ├── auth/
│   │   ├── index.ts      # Auth command group (login/logout/status → config.json)
│   │   ├── bearer.ts     # Bearer Token → config.headers.Authorization
│   │   └── cookie.ts     # Cookie Session → config.headers.Cookie
│   ├── types/
│   │   ├── index.ts      # Barrel export
│   │   ├── common.ts     # APIResponse, RequestOptions, CliConfig
│   │   ├── user.ts       # User module TypeScript interfaces
│   │   └── order.ts      # Order module TypeScript interfaces
│   └── commands/
│       ├── index.ts      # Command registration
│       ├── user.ts       # User module commands
│       └── order.ts      # Order module commands
├── dist/                 # tsup build output (ESM + .d.ts)
├── TEST.md               # Discovered endpoints + validation results
└── SKILL.md              # AI discoverability document
```

---

## Supported Backend Frameworks

| Framework | Route Detection |
|-----------|----------------|
| NestJS | `@Controller()` + `@Get/Post/Put/Patch/Delete()` decorators |
| Express | `router.get/post/put/patch/delete()` calls |
| Fastify | `fastify.get/post/put/patch/delete()` calls |
| Koa Router | `router.get/post()` calls |
| Hono | `app.get/post/put/patch/delete()` calls |
| Spring Boot | `@RestController` + `@GetMapping/@PostMapping` annotations |
| Gin (Go) | `r.GET/POST/PUT/DELETE()` calls |
| Django | `urlpatterns` + `path()`/`re_path()` definitions |
| Any (Log-only) | No source code needed — generate from logs alone |

---

## Design Principles

- **TypeScript strict mode**: Generated code passes `strict: true` with zero type errors
- **AI Agent friendly**: JSON output by default (`--output json`), non-zero exit on error
- **Config-driven auth**: All credentials in project-local `config.json` headers, never hardcoded
- **Project-local config**: Each CLI project has its own independent config file, no cross-project interference
- **Incremental sync**: `sync` command adds/deprecates endpoints without destroying manual edits
- **Full .d.ts**: Type declarations are published alongside the package via `tsup`
- **Dual auth**: Both Bearer Token and Cookie Session supported, stored as config headers
- **Explicit path params**: Separate `--path-params` option prevents confusion with query params

---

## How It Works

```
Source Code + API Logs
        │
        ▼
  Agent reads HARNESS.md
  (Phase 0-7 methodology)
        │
   ┌────▼────────────────────────────────────────┐
   │  Phase 1: Route discovery (source code)     │
   │  Phase 2: Shape inference (API logs)        │
   │  Phase 3: Module grouping + merge           │
   │  Phase 4: TypeScript type generation        │
   │  Phase 5: Commander.js command generation   │
   │  Phase 6: Package config + SKILL.md         │
   │  Phase 7: Build + validation                │
   └─────────────────────────────────────────────┘
        │
        ▼
  <project>-api-cli/ package
  (TypeScript + Commander.js + axios + auth)
```

Full methodology details in [HARNESS.md](./HARNESS.md).

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -m "feat: add my feature"`
4. Push: `git push origin feature/my-feature`
5. Open a Pull Request

Please ensure `bash verify-plugin.sh` passes before submitting.

---

## License

MIT — see [LICENSE](./LICENSE) for details.

---

## Resources

- [Claude Code Plugin Docs](https://code.claude.com/docs/en/plugins)
- [CodeBuddy Docs](https://www.codebuddy.ai/docs)
- [Report an Issue](https://github.com/GuangMingZ/cli-any-webapi/issues)

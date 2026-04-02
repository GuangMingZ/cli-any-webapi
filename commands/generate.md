# /cli-any-webapi generate

Convert a Web system's HTTP REST APIs into a fully-typed TypeScript CLI package.

## Usage

```bash
/cli-any-webapi generate <source-path> [--logs <log-file>] [--out <output-dir>] [--name <project-name>]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `source-path` | Yes | Absolute or relative path to the Web system source code directory |
| `--logs <log-file>` | Recommended | Path to API request log file. Supported formats: HAR (`.har`), CSV (`.csv`), JSON Lines (`.jsonl`), JSON array (`.json`) |
| `--out <output-dir>` | No | Output directory for the generated CLI package. Default: `./<source-dir-name>-api-cli` |
| `--name <project-name>` | No | Override the CLI package name. Default: derived from source directory name |

## Examples

```bash
# Source code only (NestJS backend)
/cli-any-webapi generate ./my-nestjs-app

# Source code + HAR log (recommended for precise TypeScript types)
/cli-any-webapi generate ./my-backend --logs ./api-logs.har

# Source code + CSV log (auto-identify column names)
/cli-any-webapi generate ./my-backend --logs ./api-access-log.csv

# Custom output dir and name
/cli-any-webapi generate /projects/backend --logs /tmp/requests.jsonl --out ./my-app-cli --name my-app

# Spring Boot (Java) project
/cli-any-webapi generate /home/user/spring-service --logs ./api-logs.har
```

## What this command does

You MUST follow these steps **in order**. Do not skip any phase. Read HARNESS.md first.

### Step 1 — Read HARNESS.md

Before doing anything else, read the full contents of `HARNESS.md` from this plugin directory. All generation rules are defined there.

### Step 2 — Environment Check (Phase 0)

- Verify `node >= 18` and `npm` are available
- Confirm source path exists and is readable
- If `--logs` provided, confirm log file exists and validate format by extension (`.har` → JSON + `log.entries`; `.csv` → header + data rows; `.jsonl` → line-delimited JSON; `.json` → root array)
- Print a summary of inputs before proceeding

### Step 3 — Discover API Endpoints (Phase 1)

- Identify the backend framework (NestJS, Express, Fastify, Koa, Hono, Spring Boot, Gin, Django)
- Extract all HTTP routes with their method, path, and handler
- Infer module groupings from controller names or route file names
- Write the discovered endpoint table to `TEST.md` Part 1

### Step 4 — Analyze Log Shapes (Phase 2)

- If `--logs` was provided: parse the log file and infer TypeScript types for each endpoint
- If no logs: generate `Record<string, unknown>` with TODO comments
- Normalize paths (replace numeric/UUID segments with `:param`)

### Step 5 — Design Module Groups (Phase 3)

- Finalize module → endpoint mapping
- Resolve naming conflicts and ambiguities
- Print the final mapping table for user review

### Step 6 — Generate TypeScript Types (Phase 4)

- Create `src/types/<module>.ts` for every module
- Follow naming convention: `<Method><Module>Params`, `<Method><Module>Response`
- Extract shared nested interfaces

### Step 7 — Generate CLI Commands (Phase 5)

- Create `src/commands/<module>.ts` for every module
- Create `src/client.ts` with axios + config integration
- Create `src/config.ts` for project-local `config.json` loading
- Create `src/auth/` with Bearer + Cookie modules
- Create `src/index.ts` as the Commander.js root program
- Create `src/types/index.ts` as barrel export

### Step 8 — Generate Package Config (Phase 6)

- Create `package.json` with correct `bin` entry, `tsup` build, dependencies
- Create `tsconfig.json` with strict mode
- Create `SKILL.md` for AI discoverability
- Create `TEST.md` with discovered endpoints

### Step 9 — Validate (Phase 7)

- Run `npm install && npm run build` in the output directory
- Run `node dist/index.js --help` to verify root command
- Run `node dist/index.js <module> --help` for 2-3 modules
- Update `TEST.md` Part 2 with validation results

## Success Criteria

- [ ] `dist/index.js` exists after build
- [ ] Zero TypeScript compilation errors
- [ ] All discovered endpoints have corresponding CLI commands
- [ ] `SKILL.md` contains "For AI Agents" section
- [ ] `TEST.md` documents all discovered endpoints and validation results

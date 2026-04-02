# /cli-any-webapi add

Add a single API endpoint to an existing generated CLI package without regenerating everything.

## Usage

```bash
/cli-any-webapi add <cli-path> <module> <method> <api-path> [--params-schema <json>] [--response-schema <json>]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `cli-path` | Yes | Path to an existing generated CLI package directory |
| `module` | Yes | Module name (e.g. `user`, `order`) |
| `method` | Yes | HTTP method: `get`, `post`, `put`, `patch`, `delete` |
| `api-path` | Yes | API path (e.g. `/api/v1/user/:id/profile`) |
| `--params-schema <json>` | No | JSON object describing request params shape (field names and types) |
| `--response-schema <json>` | No | JSON object describing response shape |

## Examples

```bash
# Add a new GET endpoint with inline schema
/cli-any-webapi add ./my-app-api-cli user get /api/v1/user/:id/profile \
  --params-schema '{}' \
  --response-schema '{"id":"number","username":"string","bio":"string"}'

# Add a POST endpoint
/cli-any-webapi add ./my-app-api-cli order post /api/v1/order/bulk \
  --params-schema '{"items":{"type":"array","items":{"productId":"number","qty":"number"}}}'

# Add endpoint to a new module (auto-creates module files)
/cli-any-webapi add ./my-app-api-cli payment post /api/v1/payment/charge \
  --params-schema '{"amount":"number","currency":"string"}'
```

## What this command does

### Step 1 — Validate inputs

- Confirm `cli-path` is a valid generated CLI package (has `package.json` with correct `bin` field, `src/` directory)
- Confirm `module` matches an existing module OR is a new module name
- Confirm `method` is one of: `get`, `post`, `put`, `patch`, `delete`
- Confirm `api-path` doesn't already exist in the module (would be a duplicate)

### Step 2 — Determine if module exists

**If module already exists (`src/commands/<module>.ts` exists):**
- Add the new method command to the existing module command file
- Add new type interfaces to `src/types/<module>.ts`

**If module is new:**
- Create `src/commands/<module>.ts` from scratch
- Create `src/types/<module>.ts` from scratch
- Register new command in `src/index.ts`
- Add export to `src/types/index.ts`

### Step 3 — Generate types

If `--params-schema` provided:
- Parse JSON schema and generate TypeScript interface
- Name as `<Method><Module>Params` following HARNESS.md convention

If `--response-schema` provided:
- Generate TypeScript interface named `<Method><Module>Response`

If neither provided:
- Generate `Record<string, unknown>` with TODO comment

### Step 4 — Generate command code

Add the new command block to the appropriate method subcommand in `src/commands/<module>.ts`.

### Step 5 — Rebuild

```bash
cd <cli-path>
npm run build
```

Verify the new command appears in `--help` output.

### Step 6 — Update SKILL.md

Add the new endpoint to the corresponding module section in `SKILL.md`.

## Success Criteria

- [ ] Build succeeds with no errors
- [ ] `node dist/index.js <module> <method> --help` shows the new path
- [ ] Types are correctly named per HARNESS.md convention
- [ ] `SKILL.md` updated with new endpoint

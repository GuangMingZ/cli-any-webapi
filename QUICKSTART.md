# cli-any-webapi — Quick Start

Get from zero to a working CLI in under 5 minutes.

---

## Prerequisites

- Claude Code or CodeBuddy with `cli-any-webapi` plugin installed
- Node.js >= 18
- A Web backend project (NestJS / Express / Fastify / Koa / Hono / Spring Boot / Gin / Django)

---

## Step 1 — Check Your Environment (30 seconds)

```bash
bash ~/.claude/plugins/cli-any-webapi/scripts/setup.sh
```

Expected output:
```
✓ Node.js v20.x.x
✓ npm 10.x.x
✓ Environment ready
```

---

## Step 2 — Generate the CLI (2 minutes)

Open Claude Code (or CodeBuddy) in your project, then run:

```bash
# Minimum: source code only
/cli-any-webapi generate ./my-backend

# Better: source code + API logs (get precise TypeScript types)
/cli-any-webapi generate ./my-backend --logs ./api-logs.har
```

**What the Agent does automatically:**
1. Detects your backend framework
2. Scans all route definitions
3. Parses API logs to infer TypeScript types
4. Groups endpoints by module
5. Generates a complete TypeScript package with auth support
6. Builds and validates the output

The generated package appears at `./my-backend-api-cli/`.

---

## Step 3 — Install the CLI (1 minute)

```bash
cd my-backend-api-cli
npm install
npm run build
npm link   # registers the command globally
```

---

## Step 4 — Configure Authentication (30 seconds)

### Option A: Config file (recommended)

```bash
cat > <project>-api-cli/config.json << 'EOF'
{
  "baseUrl": "http://localhost:3000",
  "headers": {
    "Authorization": "Bearer <your-token>"
  },
  "timeout": 30000
}
EOF
```

### Option B: Auth command

```bash
# Bearer Token
my-backend-api auth login --token eyJhbGciOiJIUzI1NiJ9...

# Cookie Session
my-backend-api auth login --cookie "session=abc123; csrf=xyz"

# Verify
my-backend-api auth status
```

---

## Step 5 — Start Using It (30 seconds)

```bash
# See all available modules
my-backend-api --help

# See all HTTP methods for the "user" module
my-backend-api user --help

# List users
my-backend-api user get /api/v1/user --params='{"page":1,"pageSize":10}'

# Get a user by ID
my-backend-api user get /api/v1/user/:id --path-params='{"id":"42"}'

# Create a user
my-backend-api user post /api/v1/user --params='{"username":"alice","email":"alice@example.com"}'

# Table output (human-readable)
my-backend-api user get /api/v1/user --output=table
```

---

## Log File Formats

If you have API request logs, pass them with `--logs` for accurate TypeScript types.

### HAR (Browser DevTools Export)

1. Open Chrome DevTools → Network tab
2. Right-click any request → "Save all as HAR with content"
3. Pass the `.har` file:

```bash
/cli-any-webapi generate ./my-backend --logs ./devtools-export.har
```

### CSV

Create a CSV where the **first row is the header** defining column semantics. Column names are auto-mapped:

```csv
method,url,request_body,response_body,status_code
GET,/api/v1/user,,"{""total"":100,""list"":[{""id"":1,""username"":""alice""}]}",200
POST,/api/v1/user,"{""username"":""bob"",""email"":""bob@x.com""}","{""id"":2}",201
```

```bash
/cli-any-webapi generate ./my-backend --logs ./api-logs.csv
```

### JSON Lines

One JSON object per line:

```jsonl
{"method":"GET","url":"/api/v1/user","status":200,"response":{"total":100,"list":[...]}}
{"method":"POST","url":"/api/v1/user","body":{"username":"bob"},"status":201,"response":{"id":2}}
```

```bash
/cli-any-webapi generate ./my-backend --logs ./api-logs.jsonl
```

---

## Keep It Up to Date

When your API changes, sync instead of regenerating from scratch:

```bash
/cli-any-webapi sync ./my-backend-api-cli --source ./my-backend --logs ./new-logs.har
```

This adds new endpoints, deprecates removed ones, and refines types — without touching your manual edits.

---

## Next Steps

- Read [HARNESS.md](./HARNESS.md) to understand the full generation methodology
- See [README.md](./README.md) for complete command reference
- File issues at https://github.com/GuangMingZ/cli-any-webapi/issues

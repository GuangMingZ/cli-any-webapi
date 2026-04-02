# Changelog

All notable changes to `cli-any-webapi` are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Version numbers follow [Semantic Versioning](https://semver.org/).

---

## [1.0.0] — 2026-03-26

### Added

- `/cli-any-webapi generate` — full generation from source code + API logs
- `/cli-any-webapi add` — add a single endpoint to an existing CLI package
- `/cli-any-webapi sync` — incremental sync without destroying manual edits
- `/cli-any-webapi list` — inventory of all generated CLI packages
- `HARNESS.md` — Phase 0-7 complete Agent execution methodology
- Support for NestJS, Express, Fastify, Koa, Hono, Spring Boot, Gin, Django route discovery
- Log format support: HAR, CSV (header-defined columns), JSON Lines, JSON array
- TypeScript strict mode generated packages with full `.d.ts` output via `tsup`
- Commander.js three-level command structure: `module method path`
- Unified config via project-local `config.json` (baseUrl + headers + timeout + auth)
- Output formats: `json` (default), `table`, `raw` via `--output` flag
- Separate `--path-params` option for explicit path parameter handling
- Bearer Token + Cookie Session dual authentication support
- `.claude-plugin/plugin.json` — supports both Claude Code and CodeBuddy
- `scripts/setup.sh` — environment checker
- `verify-plugin.sh` — pre-publish structural validation
- Complete template set: `package.json`, `tsconfig.json`, `index.ts`, `client.ts`, `config.ts`, `auth-bearer.ts`, `auth-cookie.ts`, `auth-index.ts`, `common.types.ts`, `module-command.ts`, `types-module.ts`, `SKILL.md`

---

## Versioning Policy

- **Patch** (`1.0.x`): Bug fixes in templates or HARNESS.md corrections
- **Minor** (`1.x.0`): New backend framework support, new log formats, new command options
- **Major** (`x.0.0`): Breaking changes to generated CLI structure or command API

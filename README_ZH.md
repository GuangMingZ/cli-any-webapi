# cli-any-webapi

[English](./README.md) | [中文](./README_ZH.md)

> 一个 Claude Code / CodeBuddy 插件，可将 Web 系统 HTTP REST API 转换为完全类型化的 TypeScript CLI 工具包，让 AI Agent 能够通过 CLI 命令直接调用 API。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://code.claude.com/docs/en/plugins)
[![CodeBuddy Plugin](https://img.shields.io/badge/CodeBuddy-Plugin-green)](https://www.codebuddy.ai)
[![Node.js >= 18](https://img.shields.io/badge/node-%3E%3D18-brightgreen)](https://nodejs.org)

---

## 为什么选择 cli-any-webapi？

CLI 是 AI Agent 的"原语"。AI Agent 应当通过 CLI 命令直接调用 API，而非模拟浏览器交互操作。`cli-any-webapi` 正是为此而生：

- 分析后端**源代码**（NestJS、Express、Fastify、Koa、Hono、Spring Boot、Gin、Django）以发现所有 API 端点
- 分析 **API 请求日志**（HAR、CSV、JSON Lines、JSON 数组）以推断每个参数和响应的 TypeScript 类型
- 生成**完整的 TypeScript CLI 工具包**，具备多级命令结构、完整类型安全和 AI 友好的 JSON 输出
- 内置支持 **Bearer Token + Cookie Session** 双重认证

生成的 CLI 遵循统一的三级命令结构：

```
<project>-api-cli <module> <method> <path> [options]

my-app-api user get /api/v1/user --params='{"page":1}'
my-app-api order post /api/v1/order --params='{"productId":1,"qty":2}'
my-app-api user delete /api/v1/user/:id --path-params='{"id":"123"}'
```

---

## 安装

### 方式一：Claude Code 插件目录（推荐）

```bash
/plugin install cli-any-webapi
```

### 方式二：从 GitHub 安装

```bash
cd ~/.claude/plugins
git clone https://github.com/GuangMingZ/cli-any-webapi.git
```

### 方式三：从 npm 安装

```bash
cd ~/.claude/plugins
npm install @GuangMingZ/cli-any-webapi
```

### 方式四：CodeBuddy Skill（项目级）

将插件复制到项目的 CodeBuddy skills 目录：

```bash
mkdir -p .codebuddy/skills
cp -r /path/to/cli-any-webapi .codebuddy/skills/cli-any-webapi
```

或全局安装（所有项目可用）：

```bash
mkdir -p ~/.codebuddy/skills
cp -r /path/to/cli-any-webapi ~/.codebuddy/skills/cli-any-webapi
```

### 方式五：本地安装（开发用）

```bash
cp -r /path/to/cli-any-webapi ~/.claude/plugins/cli-any-webapi
```

安装后重新加载插件：

```bash
/reload-plugins
```

---

## 前置条件

- **Node.js >= 18** — 生成的 CLI 运行时环境要求
- **npm** — 包管理器

运行环境检查脚本验证你的环境：

```bash
bash ~/.claude/plugins/cli-any-webapi/scripts/setup.sh
```

---

## 快速开始

**5 分钟上手指南：** 请参阅 [QUICKSTART.md](./QUICKSTART.md)

```bash
# 1. 从后端源码 + API 日志生成 CLI
/cli-any-webapi generate ./my-backend --logs ./api-logs.har

# 2. 构建并安装生成的 CLI
cd my-backend-api-cli
npm install && npm run build && npm link

# 3. 配置认证信息（项目本地配置）
cat > my-backend-api-cli/config.json << 'EOF'
{
  "baseUrl": "http://localhost:3000",
  "headers": {
    "Authorization": "Bearer <your-token>"
  },
  "timeout": 30000
}
EOF

# 4. 开始使用！
my-backend-api user get /api/v1/user --params='{"page":1,"pageSize":10}'
```

---

## 斜杠命令

### `/cli-any-webapi generate`

全量生成：分析源代码 + API 日志 → TypeScript CLI 工具包。

```bash
/cli-any-webapi generate <source-path> [--logs <log-file>] [--out <output-dir>] [--name <project-name>]
```

| 参数 | 是否必填 | 说明 |
|------|----------|------|
| `source-path` | 是 | Web 系统源代码目录路径 |
| `--logs <log-file>` | 推荐 | API 请求日志文件（`.har`、`.csv`、`.jsonl`、`.json`） |
| `--out <output-dir>` | 否 | 输出目录，默认：`./<source-name>-api-cli` |
| `--name <project-name>` | 否 | 覆盖 CLI 包名称 |

**支持的日志格式：**
- **HAR**（`.har`）— 浏览器导出的 HTTP 归档格式
- **CSV**（`.csv`）— 首行为表头，列名定义字段语义（自动映射）
- **JSON Lines**（`.jsonl`）— 每行一个 JSON 请求对象
- **JSON 数组**（`.json`）— 请求对象数组

### `/cli-any-webapi add`

向已有 CLI 包添加单个端点，无需重新生成。

```bash
/cli-any-webapi add <cli-path> <module> <method> <api-path> [--params-schema <json>] [--response-schema <json>]
```

### `/cli-any-webapi sync`

源代码或日志更新后增量同步。保留手动修改的内容。

```bash
/cli-any-webapi sync <cli-path> [--source <source-path>] [--logs <log-file>]
```

### `/cli-any-webapi list`

列出目录下所有生成的 CLI 包。

```bash
/cli-any-webapi list [--path <search-dir>] [--depth <n>] [--json]
```

---

## 生成的 CLI

### 命令结构

```
<project>-api-cli <module> <method> <path> [options]
```

| 层级 | 示例 | 说明 |
|------|------|------|
| 模块 | `user` | 后端模块或业务域（来自 Controller 名称或 URL 路径段） |
| 方法 | `get` | HTTP 方法：`get` / `post` / `put` / `patch` / `delete` |
| 路径 | `/api/v1/user` | 完整 API 路径（支持 `:param` 占位符） |

### 选项（所有命令通用）

| 选项 | 说明 |
|------|------|
| `--params <json>` | 查询参数（GET/DELETE）或请求体（POST/PUT/PATCH） |
| `--path-params <json>` | 路径参数值，例如 `{"id":"123"}` |
| `--headers <json>` | 附加请求头 |
| `--base-url <url>` | 覆盖配置文件中的 base URL |
| `--output <format>` | 输出格式：`json`（默认）/ `table` / `raw` |

### 认证

生成的 CLI 支持**配置驱动的认证**。凭证以 HTTP 头的形式存储在项目本地的 `<project>-api-cli/config.json` 中。每个 CLI 项目拥有独立的配置文件。

**方式一：直接编辑配置文件（推荐 AI Agent 使用）**

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

**方式二：Auth 命令（推荐交互式使用）**

```bash
# 使用 Bearer Token 登录（保存至 config.json 的 headers.Authorization）
my-app-api auth login --token <bearer-token>

# 使用 Cookie Session 登录（保存至 config.json 的 headers.Cookie）
my-app-api auth login --cookie "session=abc123; csrf=xyz"

# 检查认证状态（显示已配置的凭证，截断预览）
my-app-api auth status

# 以 JSON 格式检查认证状态（供 AI Agent 消费）
my-app-api auth status --json

# 登出（清除 config.json 中的认证头）
my-app-api auth logout
```

### 配置

创建 `<project>-api-cli/config.json` 以持久化设置：

```json
{
  "baseUrl": "http://localhost:3000",
  "headers": {
    "Authorization": "Bearer <your-token>"
  },
  "timeout": 30000
}
```

每个生成的 CLI 读取各自项目本地的配置文件。也可按请求覆盖：

```bash
# 覆盖 base URL
my-app-api user get /api/v1/user --base-url http://staging.example.com

# 覆盖请求头
my-app-api user get /api/v1/user --headers='{"X-Custom":"value"}'
```

### 使用示例

```bash
# 分页列出用户
my-app-api user get /api/v1/user --params='{"page":1,"pageSize":20}'

# 通过 ID 获取用户（显式路径参数）
my-app-api user get /api/v1/user/:id --path-params='{"id":"42"}'

# 创建用户
my-app-api user post /api/v1/user --params='{"username":"alice","email":"alice@example.com"}'

# 更新用户
my-app-api user put /api/v1/user/:id --path-params='{"id":"42"}' --params='{"email":"new@example.com"}'

# 删除用户
my-app-api user delete /api/v1/user/:id --path-params='{"id":"42"}'

# 使用表格输出
my-app-api user get /api/v1/user --output=table

# 本次请求使用自定义认证头
my-app-api order get /api/v1/order --headers='{"Authorization":"Bearer eyJ..."}'
```

---

## 生成的包结构

```
<project>-api-cli/
├── package.json          # CLI 包配置（commander + tsup，使用原生 fetch 零依赖 HTTP）
├── tsconfig.json         # TypeScript 严格模式
├── src/
│   ├── index.ts          # Commander.js 根程序
│   ├── client.ts         # 原生 fetch 客户端，集成配置
│   ├── config.ts         # 项目本地 config.json 加载器
│   ├── auth/
│   │   ├── index.ts      # Auth 命令组（login/logout/status → config.json）
│   │   ├── bearer.ts     # Bearer Token → config.headers.Authorization
│   │   └── cookie.ts     # Cookie Session → config.headers.Cookie
│   ├── types/
│   │   ├── index.ts      # 统一导出
│   │   ├── common.ts     # APIResponse、RequestOptions、CliConfig
│   │   ├── user.ts       # User 模块 TypeScript 接口
│   │   └── order.ts      # Order 模块 TypeScript 接口
│   └── commands/
│       ├── index.ts      # 命令注册
│       ├── user.ts       # User 模块命令
│       └── order.ts      # Order 模块命令
├── dist/                 # tsup 构建产物（ESM + .d.ts）
├── TEST.md               # 端点发现记录 + 验证结果
└── SKILL.md              # AI 可发现性文档
```

---

## 支持的后端框架

| 框架 | 路由检测方式 |
|------|-------------|
| NestJS | `@Controller()` + `@Get/Post/Put/Patch/Delete()` 装饰器 |
| Express | `router.get/post/put/patch/delete()` 调用 |
| Fastify | `fastify.get/post/put/patch/delete()` 调用 |
| Koa Router | `router.get/post()` 调用 |
| Hono | `app.get/post/put/patch/delete()` 调用 |
| Spring Boot | `@RestController` + `@GetMapping/@PostMapping` 注解 |
| Gin (Go) | `r.GET/POST/PUT/DELETE()` 调用 |
| Django | `urlpatterns` + `path()`/`re_path()` 定义 |
| 任意（仅日志） | 无需源代码 — 仅从日志生成 |

---

## 设计原则

- **TypeScript 严格模式**：生成的代码在 `strict: true` 下零类型错误
- **AI Agent 友好**：默认 JSON 输出（`--output json`），错误时非零退出码
- **配置驱动认证**：所有凭证存储在项目本地 `config.json` 的 headers 中，绝不硬编码
- **项目本地配置**：每个 CLI 项目拥有独立的配置文件，项目间互不干扰
- **增量同步**：`sync` 命令添加/弃用端点，不破坏手动修改
- **完整 .d.ts**：类型声明通过 `tsup` 与包一同发布
- **双重认证**：同时支持 Bearer Token 和 Cookie Session，以配置头形式存储
- **显式路径参数**：独立的 `--path-params` 选项，避免与查询参数混淆

---

## 工作原理

```
源代码 + API 日志
        │
        ▼
  Agent 读取 HARNESS.md
  （Phase 0-7 方法论）
        │
   ┌────▼────────────────────────────────────────┐
   │  Phase 1：路由发现（源代码）                │
   │  Phase 2：类型推断（API 日志）              │
   │  Phase 3：模块分组 + 合并                   │
   │  Phase 4：TypeScript 类型生成               │
   │  Phase 5：Commander.js 命令生成             │
   │  Phase 6：包配置 + SKILL.md                 │
   │  Phase 7：构建 + 验证                       │
   └─────────────────────────────────────────────┘
        │
        ▼
  <project>-api-cli/ 工具包
  （TypeScript + Commander.js + 原生 fetch + auth）
```

完整方法论详见 [HARNESS.md](./HARNESS.md)。

---

## 贡献

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/my-feature`
3. 提交更改：`git commit -m "feat: add my feature"`
4. 推送：`git push origin feature/my-feature`
5. 提交 Pull Request

提交前请确保 `bash verify-plugin.sh` 通过。

---

## 许可证

MIT — 详见 [LICENSE](./LICENSE)。

---

## 相关资源

- [Claude Code 插件文档](https://code.claude.com/docs/en/plugins)
- [CodeBuddy 文档](https://www.codebuddy.ai/docs)
- [提交 Issue](https://github.com/GuangMingZ/cli-any-webapi/issues)

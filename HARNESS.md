# cli-any-webapi Harness Methodology

> **重要**：每次执行 `/cli-any-webapi generate` 或 `/cli-any-webapi sync` 时，Agent **必须先完整阅读本文档**，再开始任何代码生成工作。HARNESS.md 是所有生成行为的唯一权威规范。

---

## 概览

`cli-any-webapi` 将 Web 系统的 HTTP REST API 转换为 TypeScript CLI 命令包，使 AI Agent 可通过 CLI 直接调用 API，而无需模拟用户界面操作。

**生成产物的核心调用格式：**

```
<project>-api-cli <module> <method> <path> [options]

示例：
  my-app-api user get /api/v1/user --params='{"page":1}'
  my-app-api order post /api/v1/order --params='{"product_id":1,"qty":2}'
  my-app-api user delete /api/v1/user/:id --path-params='{"id":"123"}'
```

**⚠️ 三项硬性约束（贯穿全文）：**

1. **原生 fetch**：生成的 CLI 必须使用 Node.js >= 18 内置的全局 `fetch` API 实现所有 HTTP 请求。**严禁引入任何第三方 HTTP 库**（axios、got、node-fetch、undici、ky、superagent 等），违反此规则视为生成失败。
2. **项目本地配置**：配置文件 `config.json` 放在 CLI 项目根目录下（`<project>-api-cli/config.json`），**不使用公共路径** `~/.cli-any-webapi/`。多个 CLI 项目各自独享配置，互不覆盖。
3. **详细的 SKILL.md**：生成的 `SKILL.md` 必须对每一个 API 端点给出独立的、带完整参数的 CLI 调用示例（包含请求参数表、响应示例），不允许省略或合并。

---

## 生成产物目录结构

每次生成，输出到 `<project>-api-cli/` 目录，结构如下：

```
<project>-api-cli/
├── package.json            # name: "<project>-api-cli", bin 入口
├── tsconfig.json           # strict mode
├── src/
│   ├── index.ts            # 主入口，注册所有模块命令
│   ├── client.ts           # 基于 Node.js 原生 fetch 的 HTTP 客户端封装
│   ├── config.ts           # 配置读取（项目本地 config.json）
│   ├── auth/
│   │   ├── index.ts        # auth login/logout/status 命令（读写项目本地 config.json）
│   │   ├── bearer.ts       # Bearer Token → config.headers.Authorization
│   │   └── cookie.ts       # Cookie Session → config.headers.Cookie
│   ├── types/
│   │   ├── index.ts        # barrel export
│   │   ├── common.ts       # APIResponse, RequestOptions, CliConfig
│   │   └── <module>.ts     # 每个模块的 request/response 类型
│   └── commands/
│       ├── index.ts        # Commander.js 根 program
│       └── <module>.ts     # 每个模块的命令组
├── dist/                   # tsup 编译输出（ESM + .d.ts）
├── TEST.md                 # 测试记录
└── SKILL.md                # AI 可发现性文档
```

---

## Phase 0 — 初始化与输入确认

**执行前检查：**

1. 确认 `source-path`：包含系统源代码的目录路径
2. 确认 `log-file`：API 请求日志文件路径（可选，但强烈建议提供）
3. 确认输出目录名：默认为 `<source-dir-name>-api-cli`，可由用户指定
4. 确认目标 `baseUrl`：生成的 CLI 默认请求地址（写入 config，不硬编码到代码）

**输出目录冲突检测（第 3 步细化）：**

确定输出目录名后，**必须检查该目录是否已存在**。处理流程：

```
候选目录名 = 用户指定 || `<source-dir-name>-api-cli`

if (候选目录已存在) {
  // 追加日期后缀，格式 YYYYMMDD
  候选目录名 = `${候选目录名}-${当前日期}`   // 例如: my-app-api-cli-20260327

  if (加日期后缀后仍存在) {
    // 追加时分秒，格式 YYYYMMDD-HHmmss
    候选目录名 = `${原始名}-${当前日期}-${当前时分秒}`  // 例如: my-app-api-cli-20260327-164500
  }
}

最终输出目录 = 候选目录名
```

**日期格式规范：**
- 日期部分：`YYYYMMDD`（如 `20260327`）
- 时间部分：`HHmmss`（如 `164500`，24 小时制）
- 使用本地时区

**示例：**

| 场景 | 候选目录名 | 检查结果 | 最终目录名 |
|------|-----------|---------|-----------|
| 目录不存在 | `my-app-api-cli` | ✅ 可用 | `my-app-api-cli` |
| 目录已存在 | `my-app-api-cli` | ❌ 冲突 → 加日期 | `my-app-api-cli-20260327` |
| 日期后缀也冲突 | `my-app-api-cli` | ❌ 二次冲突 → 加时间 | `my-app-api-cli-20260327-164500` |

> **注意**：在 TEST.md 中记录最终使用的输出目录名，便于追溯。

**日志文件验证（按扩展名分支）：**

| 扩展名 | 验证方式 |
|--------|---------|
| `.har` | 可解析为 JSON，含 `log.entries` 字段 |
| `.csv` | 含有表头行（第一行非空），至少有一行数据 |
| `.jsonl` | 至少一行可解析为 JSON 对象，含 `method` 和 `url` 字段 |
| `.json` | 可解析为 JSON 数组，元素含 HTTP 请求信息 |
| 其他 | 报错退出，提示支持的格式 |

**环境检查：**

```bash
node --version   # 要求 >= 18
npm --version
npx tsup --version  # 若未安装则在 package.json devDependencies 中声明
```

若环境不满足，输出明确错误并停止，**不要继续生成**。

---

## Phase 1 — 源码端点发现

**目标：** 从系统源码中枚举所有 HTTP 端点，得到 `(module, method, path)` 三元组列表。

### 1.1 识别框架类型

按以下顺序检测：

| 检测依据 | 框架 |
|---------|------|
| `package.json` 含 `@nestjs/core` | NestJS |
| `package.json` 含 `express` | Express |
| `package.json` 含 `fastify` | Fastify |
| `package.json` 含 `koa` | Koa |
| `package.json` 含 `hono` | Hono |
| 含 `@RestController` 注解（Java） | Spring Boot |
| 含 `gin.Default()` 调用（Go） | Gin |
| 含 `urlpatterns` 列表（Python） | Django |

### 1.2 按框架提取路由

**NestJS（优先）：**
- 扫描含 `@Controller()`、`@Get()`、`@Post()`、`@Put()`、`@Patch()`、`@Delete()` 装饰器的文件
- 提取 `@Controller('prefix')` 作为路径前缀
- 提取每个 handler 上的方法装饰器和路径
- 从文件名或类名提取 module 名（`UserController` → `user`）

**Express：**
- 扫描 `router.get()`、`router.post()`、`app.get()` 等调用
- 从路由文件名或路由前缀推断 module 名

**Spring Boot：**
- 扫描 `@RestController` + `@GetMapping`/`@PostMapping`/`@PutMapping`/`@DeleteMapping` 注解
- 提取 `@RequestMapping` 的路径前缀
- 从类名提取 module 名（`UserController` → `user`）

**通用兜底：**
- 搜索形如 `/api/v*/` 的字符串字面量，结合相邻的 HTTP method 关键词

### 1.3 输出端点映射表

以 Markdown 表格形式记录（写入 `TEST.md` Part 1）：

```
| Module | Method | Path                    | Handler / Source         |
|--------|--------|-------------------------|--------------------------|
| user   | GET    | /api/v1/user            | UserController.findAll   |
| user   | POST   | /api/v1/user            | UserController.create    |
| user   | GET    | /api/v1/user/:id        | UserController.findOne   |
| order  | GET    | /api/v1/order           | OrderController.findAll  |
```

**处理规则：**
- 路径参数统一使用 `:param` 形式（即使源码用 `{param}` NestJS 风格，也转换为 `:param`）
- 相同路径不同方法视为不同端点
- 忽略中间件路由（无明确业务含义的 `*`、`/health`、`/metrics` 等）

---

## Phase 2 — 日志 Shape 分析

**目标：** 从 API 请求日志推断每个端点的 TypeScript 类型 shape。

> 若无日志文件，跳过本 Phase，所有参数类型生成为 `Record<string, unknown>`，并在类型文件顶部注释 `// TODO: 提供 API 日志以获得精确类型`。

### 2.1 支持的日志格式

根据文件扩展名自动选择解析器：

| 格式 | 识别方式 |
|------|---------|
| **HAR** (HTTP Archive) | 文件扩展名 `.har`，JSON 根含 `log.entries[]` |
| **CSV** | 文件扩展名 `.csv`，**第一行为表头**，表头列名即字段语义 |
| **JSON Lines** | 文件扩展名 `.jsonl`，每行一个 JSON 对象，含 `method`、`url` 字段 |
| **JSON Array** | 文件扩展名 `.json`，根是数组，元素含 HTTP 信息 |

---

#### 2.A HAR 格式解析（`.har` 文件）

HAR 文件是标准 JSON，直接 `JSON.parse` 读取：

```
har.log.entries[] → {
  request: { method, url, headers[], queryString[], postData? }
  response: { status, headers[], content? }
}
```

**过滤规则：**
- 静态资源请求（`.js`、`.css`、`.png`、`.ico` 等后缀）
- 非 HTTP 成功状态（`response.status` < 200 或 ≥ 400 中的非业务错误）
- 第三方域名请求（通过与源码推断的 baseURL 对比域名过滤）

**baseURL 推断：**
1. 统计过滤后请求的 `origin`（`scheme://host:port`）
2. 选取出现频率最高的 origin 作为候选 baseURL
3. 与源码环境变量对比（搜索 `BASE_URL`、`API_URL`、`VITE_API_URL` 等）
4. 最终 baseURL 写入生成的 config

---

#### 2.B CSV 格式解析（`.csv` 文件）

##### 解析流程

1. 读取文件，按行分割，第一行为表头
2. 对表头每列执行**列名语义映射**，建立 `列索引 → 目标字段` 的映射表
3. 逐行解析数据，按映射表提取各字段值
4. 必须字段校验：`method` 和 `path` 均必须映射成功，否则跳过该行并打印警告
5. 输出统一 `LogEntry[]`

##### 列名语义映射规则

字段名不固定，采用**三级优先级**匹配（大小写不敏感）：

1. **精确匹配**：列名 === 预定义别名
2. **包含匹配**：列名 contains 关键词
3. **兜底**：无法映射的列忽略，打印警告

**字段映射表：**

| 目标字段 | 精确匹配别名（不区分大小写） | 包含匹配关键词 |
|----------|---------------------------|--------------|
| `method` | `method`, `http_method`, `verb`, `request_method` | `method`, `verb` |
| `path` | `path`, `url`, `endpoint`, `uri`, `request_url`, `api_path` | `url`, `path`, `endpoint`, `uri` |
| `status` | `status`, `status_code`, `http_status`, `response_code`, `code` | `status`, `code` |
| `queryParams` | `query`, `query_params`, `query_string`, `params`, `search` | `query`, `param` |
| `body` | `body`, `request_body`, `payload`, `data`, `post_data` | `body`, `payload` |
| `responseBody` | `response`, `response_body`, `response_data`, `result` | `response` |
| `contentType` | `content_type`, `content-type`, `mime_type` | `content_type`, `mime` |

##### path 字段特殊处理

`path` 列的原始值可能是完整 URL，需自动拆分：

```
原始值: "https://api.example.com/api/v1/users?page=1&size=10"
→ path        = "/api/v1/users"
→ queryParams 合并 { page: "1", size: "10" }
→ baseURL 候选 = "https://api.example.com"
```

##### queryParams 字段特殊处理

单元格值按以下顺序尝试解析：
1. 合法 JSON 对象字符串 → 解析后合并
2. URL query string 格式（`page=1&size=10`）→ 解析后合并
3. 两者均失败 → 作为原始字符串存入，打印警告

---

#### 2.C JSON Lines 格式解析（`.jsonl` 文件）

每行一个 JSON 对象，必须含 `method` 和 `url`（或 `path`）字段：

```json
{"method":"GET","url":"/api/v1/user","status":200,"response":{"total":100,"list":[...]}}
{"method":"POST","url":"/api/v1/user","body":{"username":"bob"},"status":201,"response":{"id":2}}
```

**字段映射：**
- `method` → `method`
- `url` / `path` → `path`（同 CSV 的 path 特殊处理）
- `body` / `request_body` / `payload` → `body`
- `response` / `response_body` → `responseBody`
- `status` / `status_code` → `responseStatus`
- `query` / `query_params` → `queryParams`

---

#### 2.D JSON Array 格式解析（`.json` 文件）

根是数组，元素结构与 JSON Lines 相同，字段映射规则一致。

---

#### 2.E 统一 LogEntry 数据结构

无论来自哪种日志格式，解析结果统一为：

```typescript
interface LogEntry {
  method: string;
  path: string;             // URL path 部分，去掉 query string
  queryParams: Record<string, string>;
  body?: unknown;           // 请求体解析结果
  responseBody?: unknown;   // 响应体解析结果
  responseStatus: number;
  contentType?: string;
}
```

### 2.2 日志类型推断步骤

1. **按 `(method, normalizedPath)` 分组**
   - 将 `/api/v1/user/123` 规范化为 `/api/v1/user/:id`（数字段替换为 `:id`，UUID 段替换为 `:uuid`）
   - 与 Phase 1 的路径列表做匹配

2. **请求 shape 提取**
   - 收集所有该端点的 request query params（GET）或 request body（POST/PUT/PATCH）
   - 同一字段在**所有**请求中均出现 → `required`；部分出现 → `optional`
   - 推断基本类型：`string | number | boolean | null`；数组标记为 `T[]`；嵌套对象递归处理

3. **响应 shape 提取**
   - 收集所有该端点的 response body（仅处理 2xx 响应）
   - 同上规则推断类型

4. **多样本合并规则**
   - 同字段多次出现类型不一致时，生成联合类型 `string | number`
   - 数组元素取所有样本的并集 shape

### 2.3 Path 参数提取

- 匹配路径中 `:param` 片段
- 在日志 URL 中验证对应位置的实际值，推断类型（数字 → `number`，UUID → `string`，其他 → `string`）

---

## Phase 3 — 模块分组设计

**目标：** 确定最终的 module 分组方案，解决歧义和冲突。

### 3.1 Module 命名规则（优先级从高到低）

1. NestJS `@Controller()` 的类名前缀（`UserController` → `user`）
2. Spring `@RestController` 的类名前缀
3. 路由文件名（`user.router.ts`、`user.routes.ts` → `user`）
4. API 路径第一有效段（`/api/v1/user/...` → `user`，跳过 `api`、`v1`、`v2` 等版本前缀）

### 3.2 冲突处理

| 情形 | 处理方式 |
|------|---------|
| 两个文件产生相同 module 名 | 合并到同一 module |
| 路径前缀与类名不一致 | 优先使用类名 |
| module 名为保留关键字（`list`、`add` 等） | 追加 `Api` 后缀（`listApi`） |

### 3.3 最终输出

生成 `<module> × <method> × <path>` 完整映射表，确认后进入代码生成。

---

## Phase 4 — TypeScript 类型生成

**目标：** 为每个 module 生成 `src/types/<module>.ts`。

### 4.1 接口命名规范

```
<PascalMethod><PascalModule><Suffix>
```

- Params：请求参数（query 或 body）
- PathParams：路径参数
- Response：响应体

示例：
- `GET /api/v1/user` → `GetUserParams`、`GetUserResponse`
- `GET /api/v1/user/:id` → `GetUserByIdPathParams`、`GetUserByIdResponse`
- `POST /api/v1/user` → `PostUserParams`、`PostUserResponse`

### 4.2 文件结构

```typescript
// Auto-generated by cli-any-webapi — DO NOT EDIT MANUALLY
// Re-generate: /cli-any-webapi sync --source <path> --logs <path>
// Generated: <ISO timestamp>

// ─── GET /api/v1/user ────────────────────────────────────────────────────────

export interface GetUserParams {
  page?: number;
  pageSize?: number;
  keyword?: string;
}

export interface GetUserResponse {
  total: number;
  list: UserItem[];
}

export interface UserItem {
  id: number;
  username: string;
  email: string;
  createdAt: string;
}

// ─── POST /api/v1/user ───────────────────────────────────────────────────────

export interface PostUserParams {
  username: string;
  email: string;
  password: string;
  role?: string;
}

export interface PostUserResponse {
  id: number;
  username: string;
  createdAt: string;
}
```

### 4.3 共享类型

- 若多个端点的 response 中含相同 shape 的嵌套对象，提取为独立接口
- 命名为 `<PascalModule>Item`（列表项）或 `<PascalModule>Detail`（详情）

---

## Phase 5 — Commander.js CLI 代码生成

### 5.1 `src/commands/<module>.ts` 结构

```typescript
import { Command } from 'commander';
import { client } from '../client.js';
import { outputResult, resolvePath } from '../index.js';
import type {
  GetUserParams, GetUserResponse,
  PostUserParams, PostUserResponse,
} from '../types/user.js';

export const userCommand = new Command('user');
userCommand.description('User module — /api/v1/user');

// ─── GET ─────────────────────────────────────────────────────────────────────

const userGetCmd = new Command('get');
userGetCmd.description('HTTP GET endpoints for user module');

userGetCmd
  .argument('<path>', 'API path (e.g. /api/v1/user, /api/v1/user/:id)')
  .option('--params <json>', 'Query parameters as JSON string', '{}')
  .option('--path-params <json>', 'Path parameters as JSON string', '{}')
  .option('--headers <json>', 'Additional request headers as JSON string', '{}')
  .option('--base-url <url>', 'Override base URL from config.json')
  .option('--output <format>', 'Output format: json | table | raw', 'json')
  .action(async (path: string, options) => {
    const params = JSON.parse(options.params) as Record<string, unknown>;
    const pathParams = JSON.parse(options.pathParams) as Record<string, string>;
    const headers = JSON.parse(options.headers) as Record<string, string>;
    const resolvedPath = resolvePath(path, pathParams);
    const data = await client.request<GetUserResponse>({
      method: 'GET',
      path: resolvedPath,
      params,
      headers,
      baseUrl: options.baseUrl,
    });
    outputResult(data, options.output);
  });

userCommand.addCommand(userGetCmd);
```

**关键约束：**
- 每个 method（get/post/put/patch/delete）对应一个子命令
- `<path>` 始终为第一个位置参数
- `--params` 接收 JSON 字符串，对 GET 请求作为 query params，对 POST/PUT/PATCH 作为 request body
- 路径参数通过 `--path-params` 传入，在发请求前做替换
- `--output` 支持 `json`（默认）、`table`、`raw` 三种格式

### 5.2 `src/client.ts` 结构

> **⚠️ 强制要求：必须使用 Node.js >= 18 内置的全局 `fetch` API 实现所有 HTTP 请求。严禁引入任何第三方 HTTP 库（包括但不限于 axios、got、node-fetch、undici、ky、superagent 等）。** 这是本项目的硬性约束，目的是实现零外部 HTTP 依赖、减少包体积、简化维护。如果生成的代码中出现 `import ... from 'axios'` 或任何第三方 HTTP 库的 import 语句，视为生成失败，必须修正。

```typescript
import { loadConfig, type CliConfig } from './config.js';

const cfg = loadConfig();

export interface ClientRequestOptions {
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  path: string;
  params?: Record<string, unknown>;
  body?: Record<string, unknown>;
  headers?: Record<string, string>;
  baseUrl?: string;
}

/**
 * 基于 Node.js 原生 fetch 的 HTTP 客户端。
 * - baseUrl 从 config 读取，可通过 --base-url 覆盖
 * - 认证 headers 从 config.headers 注入
 * - 超时使用 AbortController 实现
 */
export const client = {
  async request<T = unknown>(options: ClientRequestOptions): Promise<T> {
    const baseUrl = options.baseUrl ?? cfg.baseUrl;
    let url = `${baseUrl.replace(/\/+$/, '')}${options.path}`;

    // GET/DELETE 请求将 params 拼接为 query string
    if (options.params && Object.keys(options.params).length > 0) {
      const qs = new URLSearchParams();
      for (const [k, v] of Object.entries(options.params)) {
        if (v !== undefined && v !== null) qs.append(k, String(v));
      }
      url += `?${qs.toString()}`;
    }

    const controller = new AbortController();
    const timeout = cfg.timeout ?? 30000;
    const timer = setTimeout(() => controller.abort(), timeout);

    try {
      const res = await fetch(url, {
        method: options.method,
        headers: {
          'Content-Type': 'application/json',
          ...cfg.headers,
          ...options.headers,
        },
        body: options.body ? JSON.stringify(options.body) : undefined,
        signal: controller.signal,
      });

      clearTimeout(timer);

      const text = await res.text();
      let data: unknown;
      try {
        data = JSON.parse(text);
      } catch {
        data = text;
      }

      if (!res.ok) {
        console.error(JSON.stringify({ error: true, status: res.status, data }, null, 2));
        process.exit(1);
      }

      return data as T;
    } catch (err: unknown) {
      clearTimeout(timer);
      if (err instanceof DOMException && err.name === 'AbortError') {
        console.error(JSON.stringify({ error: true, status: 0, data: `Request timeout after ${timeout}ms` }, null, 2));
      } else {
        console.error(JSON.stringify({ error: true, status: 0, data: String(err) }, null, 2));
      }
      process.exit(1);
    }
  },
};
```

**为什么选择原生 fetch 而非 axios（决策记录）：**

| 特性 | ✅ 原生 fetch（本项目选择） | ❌ axios（禁止使用） |
|------|---------------------------|---------------------|
| 外部依赖 | **0**（Node.js >= 18 内置） | 1（axios + 传递依赖） |
| 包体积 | **无额外体积** | ~40KB (gzip) |
| 超时控制 | `AbortController` | `timeout` 选项 |
| 类型安全 | 自定义 `ClientRequestOptions` | `AxiosRequestConfig` |
| Query 序列化 | 内置 `URLSearchParams` | axios 内置 |

> **再次强调**：`package.json` 的 `dependencies` 中只允许 `commander`，不得出现任何 HTTP 客户端库。`devDependencies` 中只允许 `typescript`、`tsup`、`@types/node`。

### 5.3 `src/config.ts` 结构

> **配置路径设计**：配置文件 `config.json` 放在 CLI 项目根目录下（即 `<project>-api-cli/config.json`），而非公共路径 `~/.cli-any-webapi/`。原因：用户可能在本地创建多个 CLI 项目，使用公共路径会导致不同项目的配置互相覆盖。每个 CLI 项目独享自己的配置文件。

```typescript
import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

export interface CliConfig {
  baseUrl: string;
  headers?: Record<string, string>;
  timeout?: number;
}

/**
 * 获取配置文件路径：项目根目录下的 config.json。
 * 查找逻辑：从当前可执行文件位置向上找到项目根目录（含 package.json 的目录）。
 */
function getConfigPath(): string {
  // 从编译产物位置（dist/）向上一级即为项目根目录
  const __dirname = dirname(fileURLToPath(import.meta.url));
  const projectRoot = resolve(__dirname, '..');
  return resolve(projectRoot, 'config.json');
}

const CONFIG_PATH = getConfigPath();
const DEFAULT_CONFIG: CliConfig = { baseUrl: 'http://localhost:3000' };

export function loadConfig(): CliConfig {
  if (!existsSync(CONFIG_PATH)) return DEFAULT_CONFIG;
  try {
    const raw = readFileSync(CONFIG_PATH, 'utf-8');
    return { ...DEFAULT_CONFIG, ...(JSON.parse(raw) as Partial<CliConfig>) };
  } catch {
    console.warn(
      `[cli-any-webapi] Failed to parse config at ${CONFIG_PATH}, using defaults.\n` +
      `  Config schema: { "baseUrl": "string", "headers": {...}, "timeout": number }`
    );
    return DEFAULT_CONFIG;
  }
}

/**
 * 获取配置文件的完整路径（供 auth 模块读写使用）。
 */
export function getConfigFilePath(): string {
  return CONFIG_PATH;
}
```

**配置文件位置说明：**

| 场景 | 配置文件路径 |
|------|-------------|
| 项目 `my-app-api-cli/` | `my-app-api-cli/config.json` |
| 项目 `shop-api-cli/` | `shop-api-cli/config.json` |
| 全局 npm link 后执行 | 仍读取项目根目录下的 `config.json`（通过 `dist/` 向上一级定位） |

> **好处**：多个 CLI 项目各自独立的配置，互不影响。不再使用 `~/.cli-any-webapi/config.json` 公共路径。

### 5.4 `src/index.ts` 结构

```typescript
#!/usr/bin/env node
import { program } from 'commander';
import { userCommand } from './commands/user.js';
import { orderCommand } from './commands/order.js';

program
  .name('<project>-api-cli')
  .description('Auto-generated CLI for <Project> Web API — powered by cli-any-webapi')
  .version('<version>');

program.addCommand(userCommand);
program.addCommand(orderCommand);

program.parseAsync(process.argv);
```

### 5.5 输出格式辅助函数

在 `src/index.ts` 中提供全局 `outputResult` 和 `resolvePath` 函数：

```typescript
export function outputResult(data: unknown, format: string): void {
  switch (format) {
    case 'table':
      if (Array.isArray(data)) console.table(data);
      else console.table([data]);
      break;
    case 'raw':
      console.log(typeof data === 'string' ? data : String(data));
      break;
    default: // json
      console.log(JSON.stringify(data, null, 2));
  }
}

export function resolvePath(
  template: string,
  pathParams: Record<string, string>
): string {
  return template.replace(/:([a-zA-Z_][a-zA-Z0-9_]*)/g, (_, key) => {
    if (!(key in pathParams)) {
      console.error(
        `[cli-any-webapi] Missing path parameter: :${key}\n` +
        `  Provide it via --path-params '{"${key}": "<value>"}'`
      );
      process.exit(1);
    }
    return encodeURIComponent(pathParams[key]);
  });
}
```

---

## Phase 6 — 配置与打包文件生成

### 6.1 `package.json`

```json
{
  "name": "<project>-api-cli",
  "version": "1.0.0",
  "description": "Auto-generated CLI for <Project> Web API",
  "type": "module",
  "bin": {
    "<project>-api-cli": "./dist/index.js"
  },
  "scripts": {
    "build": "tsup src/index.ts --format esm --dts --clean --target node18",
    "dev": "tsup src/index.ts --format esm --watch --target node18",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "commander": "^12.0.0"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "tsup": "^8.0.0",
    "@types/node": "^20.0.0"
  }
}
```

### 6.2 `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2022"],
    "strict": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "resolveJsonModule": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

### 6.3 `SKILL.md`（生成的 CLI 项目的 AI 可发现性文档）

> **⚠️ 这是 AI Agent 使用生成的 CLI 的核心参考文档。必须足够详细，让 Agent 无需查看源码即可正确调用所有 API。每一个发现的 API 端点都必须在 SKILL.md 中有独立的、带完整参数的调用示例。**

**SKILL.md 必须包含以下章节（按顺序）：**

#### 6.3.1 头部元信息（YAML frontmatter）

```yaml
---
name: "<project>-api-cli"
description: "Auto-generated TypeScript CLI for <Project> Web API. ..."
---
```

#### 6.3.2 概览（项目信息 + 安装方式 + 配置方式）

包含：
- 项目名、生成时间、源码路径、Base URL
- 安装和构建步骤
- 配置文件位置（`<project>-api-cli/config.json`，项目本地）及示例

#### 6.3.3 通用命令格式说明

```
<project>-api-cli <module> <method> <path> [options]

Options:
  --params <json>       Query params (GET/DELETE) or request body (POST/PUT/PATCH)
  --path-params <json>  Path parameter values, e.g. {"id":"123"}
  --headers <json>      Additional request headers
  --base-url <url>      Override base URL from config.json
  --output <format>     Output format: json | table | raw  [default: json]
```

#### 6.3.4 ⭐ 模块详情（关键：逐模块、逐端点给出示例）

**这是 SKILL.md 最重要的部分。** 对每个 module，必须：

1. 列出该模块下所有端点
2. **每个端点** 给出完整的 CLI 调用示例（包含真实的参数示例值）
3. 说明每个端点的请求参数和响应结构

**格式模板（以 `user` 模块为例）：**

````markdown
## Module: user

Base path: `/api/v1/user`

### GET /api/v1/user — 获取用户列表

```bash
<project>-api-cli user get /api/v1/user --params='{"page":1,"pageSize":20,"keyword":"alice"}'
```

**请求参数 (query):**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| page | number | 否 | 页码，默认 1 |
| pageSize | number | 否 | 每页条数，默认 20 |
| keyword | string | 否 | 搜索关键词 |

**响应示例:**
```json
{
  "total": 100,
  "list": [
    { "id": 1, "username": "alice", "email": "alice@example.com", "createdAt": "2026-01-01T00:00:00Z" }
  ]
}
```

---

### GET /api/v1/user/:id — 获取单个用户详情

```bash
<project>-api-cli user get /api/v1/user/:id --path-params='{"id":"42"}'
```

**路径参数:**
| 参数 | 类型 | 说明 |
|------|------|------|
| id | string | 用户 ID |

**响应示例:**
```json
{ "id": 42, "username": "alice", "email": "alice@example.com", "role": "admin", "createdAt": "2026-01-01T00:00:00Z" }
```

---

### POST /api/v1/user — 创建用户

```bash
<project>-api-cli user post /api/v1/user --params='{"username":"bob","email":"bob@example.com","password":"SecureP@ss1"}'
```

**请求参数 (body):**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| username | string | 是 | 用户名 |
| email | string | 是 | 邮箱 |
| password | string | 是 | 密码 |
| role | string | 否 | 角色，默认 "user" |

**响应示例:**
```json
{ "id": 2, "username": "bob", "createdAt": "2026-03-30T10:00:00Z" }
```

---

### PUT /api/v1/user/:id — 完整更新用户

```bash
<project>-api-cli user put /api/v1/user/:id --path-params='{"id":"42"}' --params='{"username":"alice_new","email":"alice_new@example.com","role":"admin"}'
```

**路径参数:**
| 参数 | 类型 | 说明 |
|------|------|------|
| id | string | 用户 ID |

**请求参数 (body):**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| username | string | 是 | 用户名 |
| email | string | 是 | 邮箱 |
| role | string | 否 | 角色 |

**响应示例:**
```json
{ "id": 42, "username": "alice_new", "email": "alice_new@example.com", "updatedAt": "2026-03-30T11:00:00Z" }
```

---

### PATCH /api/v1/user/:id — 部分更新用户

```bash
<project>-api-cli user patch /api/v1/user/:id --path-params='{"id":"42"}' --params='{"email":"newemail@example.com"}'
```

**路径参数:**
| 参数 | 类型 | 说明 |
|------|------|------|
| id | string | 用户 ID |

**请求参数 (body):**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| (任意字段) | — | 否 | 只需传入要修改的字段 |

**响应示例:**
```json
{ "id": 42, "email": "newemail@example.com", "updatedAt": "2026-03-30T11:30:00Z" }
```

---

### DELETE /api/v1/user/:id — 删除用户

```bash
<project>-api-cli user delete /api/v1/user/:id --path-params='{"id":"42"}'
```

**路径参数:**
| 参数 | 类型 | 说明 |
|------|------|------|
| id | string | 用户 ID |

**响应示例:**
```json
{ "success": true, "message": "User 42 deleted" }
```
````

**生成规则：**

1. **每个发现的端点都必须有独立的示例** — 不允许省略或合并
2. **示例参数值必须使用合理的模拟数据** — 不使用 `<placeholder>` 占位符（路径参数除外），而是用看起来真实的示例值
3. **如果有日志数据**（Phase 2），优先从日志中提取真实的参数值作为示例
4. **如果没有日志数据**，根据类型推断生成合理的示例值（number → `1`/`20`/`42`，string → 有意义的示例文本，boolean → `true`/`false`）
5. **请求参数表** 必须标注每个参数的类型、是否必填、简要说明
6. **响应示例** 必须基于 Phase 2 推断的响应 shape 或 Phase 4 生成的 Response 接口
7. **模块按字母序排列**，模块内端点按 `GET → POST → PUT → PATCH → DELETE` 排列

#### 6.3.5 For AI Agents 章节

提供 AI Agent 使用此 CLI 的完整指南：
- 通用调用模式
- 认证配置方式（auth 命令 + 直接编辑 `config.json`）
- 输出格式说明（JSON 默认、table、raw）
- 错误处理约定（stderr + exit code 1）

#### 6.3.6 完整端点总览表

在文档末尾提供一个所有端点的汇总表：

```markdown
| Module | Method | Path | Description |
|--------|--------|------|-------------|
| user | GET | /api/v1/user | 获取用户列表 |
| user | GET | /api/v1/user/:id | 获取单个用户 |
| user | POST | /api/v1/user | 创建用户 |
| ... | ... | ... | ... |
```

---

## Phase 7 — 验证

**必须完成以下验证，全部通过后才能声明生成完成：**

### 7.1 编译验证

```bash
cd <project>-api-cli
npm install
npm run build
```

- **通过标准**：`dist/index.js` 存在，无 TypeScript 编译错误

### 7.2 帮助输出验证

```bash
node dist/index.js --help
node dist/index.js user --help
node dist/index.js user get --help
```

- **通过标准**：每级命令正确显示子命令和选项，无 runtime 错误

### 7.3 SKILL.md 验证

- 所有 module 均在 SKILL.md 中有独立的 `## Module: <name>` 章节
- **每个端点**（不是每个模块，是每个端点）有独立的 CLI 调用示例（包含真实参数值）
- 每个端点有请求参数表（参数名、类型、是否必填、说明）
- 每个端点有响应示例 JSON
- "For AI Agents" 章节存在且包含完整调用规范
- 末尾有完整端点总览表
- 配置文件路径引用的是项目本地 `config.json`，不是 `~/.cli-any-webapi/`

### 7.4 记录 TEST.md

```markdown
# TEST.md

## Part 1 — Discovered Endpoints
<Phase 1 生成的端点映射表>

## Part 2 — Validation Results
| Check | Status | Notes |
|-------|--------|-------|
| npm build | ✅ PASS | |
| --help (root) | ✅ PASS | |
| --help (module) | ✅ PASS | |
| SKILL.md completeness | ✅ PASS | |
```

---

## 增量同步规则（`sync` 命令）

执行 `/cli-any-webapi sync` 时：

1. 重新执行 Phase 1 + Phase 2
2. 与上次生成的端点列表对比：
   - **新增端点**：生成新的类型和命令，追加到对应文件
   - **删除端点**：在文件中注释掉（不直接删除），并在顶部注释 `// DEPRECATED since <date>`
   - **类型变更**：更新接口，在字段注释标记变更日期
3. 重新执行 Phase 7 验证

**不推倒重建**，保留用户对配置文件的手动修改。

---

## 错误处理规范

| 情形 | 行为 |
|------|------|
| 无法识别框架 | 警告但继续，使用通用路由扫描 |
| 日志格式无法解析 | 跳过 Phase 2，生成 `unknown` 类型并注释 TODO |
| 端点无法匹配日志 | 生成 `Record<string, unknown>` 类型并注释 |
| 编译失败 | 输出完整错误，**不要**自动修改已生成的类型文件，报告给用户 |

---

## 关键规则

### 规则 1：生成代码必须有完整 JSDoc 注释

每个生成的函数/接口必须包含 JSDoc，标注：
- `@description` API 路径和方法
- `@param` 各参数说明
- `@returns` 返回类型说明

### 规则 2：项目本地配置 + 配置驱动认证

> **⚠️ 重要变更**：配置文件不再使用公共路径 `~/.cli-any-webapi/config.json`，而是放在**每个 CLI 项目的根目录**下（`<project>-api-cli/config.json`）。这样多个 CLI 项目的配置互不干扰。

配置文件 `<project>-api-cli/config.json`：

```json
{
  "baseUrl": "http://localhost:3000",
  "headers": {
    "Authorization": "Bearer <token>",
    "Cookie": "session=abc; csrf=xyz"
  },
  "timeout": 30000
}
```

**配置驱动认证设计：**

- 认证信息（Bearer Token、Cookie）存储为 `headers` 字段的值
- `src/config.ts` 读取配置 → `src/client.ts` 将 `headers` 注入原生 fetch 请求
- 每个命令的 `--headers` 选项可覆盖或补充配置中的认证头
- `auth login` 命令本质上是修改 `config.json` 中的 `headers` 字段
- `auth logout` 命令本质上是删除 `config.json` 中的认证相关 header

**安全要求：**

- **禁止**将凭证硬编码到生成的源代码中
- 配置文件创建时设置权限为 `chmod 600`（owner read/write only）
- `auth status` 输出凭证预览（截断显示），不输出完整凭证

**两种配置认证方式（均等效）：**

```bash
# 方式 1：通过 auth 命令（推荐）
<project>-api-cli auth login --token <bearer-token>
<project>-api-cli auth login --cookie "session=abc"

# 方式 2：直接编辑项目本地配置文件
cat > <project>-api-cli/config.json << 'EOF'
{
  "baseUrl": "http://localhost:3000",
  "headers": { "Authorization": "Bearer <token>" }
}
EOF
```

### 规则 3：输出格式规范

`--output` 选项支持三种格式：

| 格式 | 描述 |
|------|------|
| `json`（默认） | `JSON.stringify(data, null, 2)`，适合 AI Agent 消费 |
| `table` | `console.table(data)`，适合人类阅读 |
| `raw` | 原始字符串输出 |

成功输出到 stdout，退出码 0。错误输出到 stderr，退出码非 0。

### 规则 4：路径参数必须通过 `--path-params` 传入

`/api/v1/user/:id` 中的 `:id` 通过 `--path-params='{"id":"123"}'` 传入，不混在 `--params` 中。

### 规则 5：TypeScript 严格模式

生成的 `tsconfig.json` 必须开启 `strict: true`，生成的代码必须通过严格模式类型检查。所有 import 使用 `.js` 扩展名（ESM 兼容）。

### 规则 6：模块命名一致性

- CLI 命令名：kebab-case（`user-profile`）
- TypeScript 类型名：PascalCase（`UserProfile`）
- 文件名：kebab-case（`user-profile.ts`）
- 变量/函数名：camelCase（`userProfile`）

---

## 生成质量检查清单

在声明生成完成前，逐条确认：

- [ ] 所有 Phase 1 发现的端点均有对应的命令
- [ ] 所有类型文件通过 `tsc --noEmit`
- [ ] 每个命令有对应的 `--help` 可读描述
- [ ] `SKILL.md` 包含 "For AI Agents" 章节
- [ ] `SKILL.md` 中每个端点有独立的调用示例、参数表、响应示例
- [ ] `package.json` 的 `bin` 字段正确指向编译产物
- [ ] 配置路径为 `<project>-api-cli/config.json`（项目本地，不是 `~/.cli-any-webapi/`）
- [ ] 路径参数通过 `--path-params` 传入，不在 `--params` 中
- [ ] 所有 import 使用 `.js` 扩展名（ESM 兼容）
- [ ] `--output json/table/raw` 三种输出格式均正常工作

---

## 应用于不同技术栈

相同的 SOP 适用于任何 HTTP API 系统：

| 技术栈 | 路由提取方式 | 模块识别方式 |
|--------|------------|------------|
| NestJS | `@Controller` + `@Get/Post` 装饰器 | `@Controller` 名称 |
| Express | `app.get/post` 调用 | 路径前缀分组 |
| Koa Router | `router.get/post` 调用 | 路径前缀分组 |
| Fastify | `fastify.get/post` 调用 | 路径前缀分组 |
| Hono | `app.get/post` 调用 | 路径前缀分组 |
| Spring Boot | `@RestController` + `@GetMapping` 注解 | `@RestController` 类名 |
| Gin (Go) | `r.GET/POST` 调用 | 路由组名称 |
| Django | `urlpatterns` 列表 | URL 前缀分组 |
| 仅日志文件 | 无需源码分析 | 路径前缀分组 |

**模式始终相同：分析输入 → 构建 APISpec → 套用模板生成 TypeScript CLI**。

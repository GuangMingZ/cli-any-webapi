# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x.x   | Yes       |

## Reporting a Vulnerability

**Please do not open public GitHub Issues for security vulnerabilities.**

Report security issues by emailing: **security@your-org.com**

Include in your report:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You will receive a response within **48 hours**. If the issue is confirmed, a patch will be released within **7 days** for critical issues.

## Security Notes for Generated CLI Packages

The generated CLI packages created by this plugin follow these security practices:

1. **No credentials in generated code** — authentication tokens are read at runtime from project-local `config.json`, never hardcoded into source files
2. **Config file permissions** — auth credentials are stored with `chmod 600` permissions (owner read/write only)
3. **No eval or dynamic code execution** — all generated code is static TypeScript; no `eval()`, `Function()`, or dynamic `require()` calls
4. **Input validation** — JSON parsing errors are caught and reported cleanly; malformed `--params` or `--body` input exits with code 1
5. **No file system writes** — generated CLIs only make HTTP requests and read config; they do not write arbitrary files
6. **Bearer Token masking** — `auth status` command only shows first 8 characters of the token, never the full value
7. **Cookie security** — Cookie strings are stored in the same secured config file, never logged or exposed in verbose output

## Responsible Disclosure

We follow responsible disclosure practices. If a vulnerability is confirmed:
1. We will work with you to understand the scope
2. We will develop and test a fix
3. We will release a patched version
4. We will publicly disclose after the fix is available, crediting the reporter (unless anonymity is requested)

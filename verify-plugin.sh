#!/usr/bin/env bash
# cli-any-webapi plugin verification script
# Run before publishing to ensure the plugin meets all marketplace requirements.
# Usage: bash verify-plugin.sh [plugin-dir]

set -euo pipefail

PLUGIN_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; WARNINGS=$((WARNINGS + 1)); }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  cli-any-webapi — Plugin / Skill Verification       ║"
echo "║  Claude Code Plugin + CodeBuddy Skill               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Plugin directory: $PLUGIN_DIR"
echo ""

# ─── Required files ───────────────────────────────────────────────────────────

echo "── Required Files ──────────────────────────────"

required_files=(
  ".claude-plugin/plugin.json"
  "HARNESS.md"
  "README.md"
  "QUICKSTART.md"
  "SKILL.md"
  "LICENSE"
  "CHANGELOG.md"
  "SECURITY.md"
  "commands/generate.md"
  "commands/add.md"
  "commands/sync.md"
  "commands/list.md"
  "templates/package.json.template"
  "templates/tsconfig.json.template"
  "templates/index.ts.template"
  "templates/http-client.ts.template"
  "templates/config.ts.template"
  "templates/auth-bearer.ts.template"
  "templates/auth-cookie.ts.template"
  "templates/auth-index.ts.template"
  "templates/common.types.ts.template"
  "templates/module.command.ts.template"
  "templates/module.types.ts.template"
  "templates/SKILL.md.template"
  "scripts/setup.sh"
  "verify-plugin.sh"
)

for f in "${required_files[@]}"; do
  if [ -f "$PLUGIN_DIR/$f" ]; then
    pass "$f"
  else
    fail "$f (MISSING)"
  fi
done

# ─── plugin.json validation ───────────────────────────────────────────────────

echo ""
echo "── plugin.json ─────────────────────────────────"

PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [ -f "$PLUGIN_JSON" ]; then
  if node -e "JSON.parse(require('fs').readFileSync('$PLUGIN_JSON','utf8'))" 2>/dev/null; then
    pass "Valid JSON"
  else
    fail "Invalid JSON — fix $PLUGIN_JSON"
  fi

  for field in name version description author; do
    value=$(node -e "const p=JSON.parse(require('fs').readFileSync('$PLUGIN_JSON','utf8')); console.log(p.$field ? 'ok' : 'missing')" 2>/dev/null || echo "error")
    if [ "$value" = "ok" ]; then
      pass "Has '$field' field"
    else
      fail "Missing '$field' field"
    fi
  done

  # Check version format (semver)
  version=$(node -e "const p=JSON.parse(require('fs').readFileSync('$PLUGIN_JSON','utf8')); console.log(p.version||'')" 2>/dev/null || echo "")
  if echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    pass "Version '$version' is valid semver"
  else
    warn "Version '$version' may not be valid semver (expected x.y.z)"
  fi

  # Check commands count
  cmd_count=$(node -e "const p=JSON.parse(require('fs').readFileSync('$PLUGIN_JSON','utf8')); console.log((p.commands||[]).length)" 2>/dev/null || echo "0")
  if [ "$cmd_count" -ge 1 ]; then
    pass "$cmd_count commands registered"
  else
    fail "No commands found in plugin.json"
  fi
fi

# ─── SKILL.md validation (CodeBuddy) ─────────────────────────────────────────

echo ""
echo "── SKILL.md (CodeBuddy Skill) ────────────────────"

SKILL_MD="$PLUGIN_DIR/SKILL.md"

if [ -f "$SKILL_MD" ]; then
  pass "SKILL.md exists"

  # Check YAML frontmatter presence
  if head -1 "$SKILL_MD" | grep -q '^---$'; then
    pass "Has YAML frontmatter"
  else
    fail "Missing YAML frontmatter (must start with ---)"
  fi

  # Check required frontmatter fields: name, description
  for field in name description; do
    if grep -q "^${field}:" "$SKILL_MD" 2>/dev/null; then
      pass "Has '$field' in frontmatter"
    else
      fail "Missing '$field' in SKILL.md frontmatter"
    fi
  done

  # Check optional but recommended fields
  for field in allowed-tools disable; do
    if grep -q "^${field}:" "$SKILL_MD" 2>/dev/null; then
      pass "Has optional '$field' in frontmatter"
    else
      warn "Missing optional '$field' in SKILL.md frontmatter"
    fi
  done

  # Check that SKILL.md has substantive content (not just frontmatter)
  content_lines=$(grep -c -v '^$' "$SKILL_MD" | tr -d ' ')
  if [ "$content_lines" -gt 20 ]; then
    pass "SKILL.md has $content_lines non-empty lines of content"
  else
    warn "SKILL.md seems sparse ($content_lines non-empty lines)"
  fi

  # Check for key sections expected by CodeBuddy
  for section in "When To Use" "Slash Commands" "Execution Process"; do
    if grep -q "$section" "$SKILL_MD"; then
      pass "Section '$section' present"
    else
      warn "Section '$section' missing from SKILL.md"
    fi
  done
else
  fail "SKILL.md missing (required for CodeBuddy Skill)"
fi

# ─── Cross-platform consistency ──────────────────────────────────────────────

echo ""
echo "── Cross-Platform Consistency ─────────────────────"

if [ -f "$PLUGIN_JSON" ] && [ -f "$SKILL_MD" ]; then
  # Check that plugin name matches across both config files
  plugin_name=$(node -e "const p=JSON.parse(require('fs').readFileSync('$PLUGIN_JSON','utf8')); console.log(p.name||'')" 2>/dev/null || echo "")
  skill_name=$(grep '^name:' "$SKILL_MD" | head -1 | sed 's/^name:[[:space:]]*//;s/^"//;s/"$//' | tr -d "'")
  if [ "$plugin_name" = "$skill_name" ]; then
    pass "Plugin name matches: '$plugin_name' (plugin.json = SKILL.md)"
  else
    warn "Name mismatch: plugin.json='$plugin_name' vs SKILL.md='$skill_name'"
  fi

  # Check package.json has codebuddy entry
  PKG_JSON="$PLUGIN_DIR/package.json"
  if [ -f "$PKG_JSON" ]; then
    has_codebuddy=$(node -e "const p=JSON.parse(require('fs').readFileSync('$PKG_JSON','utf8')); console.log(p.codebuddy ? 'ok' : 'missing')" 2>/dev/null || echo "error")
    if [ "$has_codebuddy" = "ok" ]; then
      pass "package.json has 'codebuddy' configuration"
    else
      warn "package.json missing 'codebuddy' field (recommended for discoverability)"
    fi
  fi
else
  warn "Cannot check cross-platform consistency (missing plugin.json or SKILL.md)"
fi

echo ""
echo "── Executable Scripts ──────────────────────────"

for script in "scripts/setup.sh" "verify-plugin.sh"; do
  if [ -f "$PLUGIN_DIR/$script" ]; then
    if [ -x "$PLUGIN_DIR/$script" ]; then
      pass "$script is executable"
    else
      fail "$script is NOT executable (run: chmod +x $script)"
    fi
  fi
done

# ─── No hardcoded credentials or paths ───────────────────────────────────────

echo ""
echo "── Security Checks ─────────────────────────────"

# Check for Bearer tokens (real tokens, not placeholders)
if grep -rq 'Bearer ey[A-Za-z0-9._-]\{20,\}' "$PLUGIN_DIR" 2>/dev/null; then
  fail "Possible hardcoded Bearer token found — review before publishing"
else
  pass "No hardcoded Bearer tokens"
fi

# Check for hardcoded localhost URLs in non-template/non-doc files
suspicious=$(grep -rl 'http://localhost:[0-9]' "$PLUGIN_DIR" \
  --include="*.md" --include="*.json" 2>/dev/null \
  | grep -v 'templates/' | grep -v 'QUICKSTART' | grep -v 'README' \
  | grep -v 'HARNESS' | grep -v 'scripts/' || true)
if [ -n "$suspicious" ]; then
  warn "Hardcoded localhost URLs found in: $suspicious (ensure these are examples, not defaults)"
else
  pass "No unexpected hardcoded localhost URLs"
fi

# ─── Template placeholder consistency ────────────────────────────────────────

echo ""
echo "── Template Consistency ────────────────────────"

if [ -d "$PLUGIN_DIR/templates" ]; then
  template_count=$(find "$PLUGIN_DIR/templates" -name "*.template" | wc -l | tr -d ' ')
  pass "$template_count template files found"

  # Check each template for {{PLACEHOLDER}} tokens
  # tsconfig.json.template may be placeholder-free (fixed config)
  for tmpl in "$PLUGIN_DIR"/templates/*.template; do
    fname=$(basename "$tmpl")
    if [ "$fname" = "tsconfig.json.template" ]; then
      pass "$fname (fixed config, no placeholders needed)"
      continue
    fi
    if grep -q '{{' "$tmpl" 2>/dev/null; then
      pass "$fname has placeholder tokens"
    else
      warn "$fname has no {{PLACEHOLDER}} tokens — verify this is intentional"
    fi
  done
fi

# ─── README completeness ──────────────────────────────────────────────────────

echo ""
echo "── README.md Completeness ──────────────────────"

readme="$PLUGIN_DIR/README.md"
if [ -f "$readme" ]; then
  for section in "Installation" "Quick Start" "Slash Commands" "Generated CLI" "License"; do
    if grep -q "## $section" "$readme"; then
      pass "Section '## $section' present"
    else
      warn "Section '## $section' missing from README.md"
    fi
  done
fi

# ─── HARNESS.md phase coverage ────────────────────────────────────────────────

echo ""
echo "── HARNESS.md Coverage ─────────────────────────"

harness="$PLUGIN_DIR/HARNESS.md"
if [ -f "$harness" ]; then
  for phase in "Phase 0" "Phase 1" "Phase 2" "Phase 3" "Phase 4" "Phase 5" "Phase 6" "Phase 7"; do
    if grep -q "$phase" "$harness"; then
      pass "$phase documented"
    else
      fail "$phase missing from HARNESS.md"
    fi
  done
fi

# ─── Commands coverage ───────────────────────────────────────────────────────

echo ""
echo "── Slash Commands ──────────────────────────────"

for cmd in generate add sync list; do
  if [ -f "$PLUGIN_DIR/commands/$cmd.md" ]; then
    lines=$(wc -l < "$PLUGIN_DIR/commands/$cmd.md" | tr -d ' ')
    if [ "$lines" -gt 10 ]; then
      pass "commands/$cmd.md ($lines lines)"
    else
      warn "commands/$cmd.md seems too short ($lines lines)"
    fi
  fi
done

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════"

if [ $ERRORS -gt 0 ]; then
  echo -e "${RED}✗ FAILED: $ERRORS error(s), $WARNINGS warning(s)${NC}"
  echo "  Fix all errors before publishing."
  echo ""
  exit 1
elif [ $WARNINGS -gt 0 ]; then
  echo -e "${YELLOW}⚠ PASSED WITH WARNINGS: $WARNINGS warning(s)${NC}"
  echo "  Review warnings before publishing."
  echo ""
  exit 0
else
  echo -e "${GREEN}✓ ALL CHECKS PASSED — ready to publish${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. git init && git add . && git commit -m 'Initial release v1.0.0'"
  echo "  2. gh repo create cli-any-webapi --public --source=. --remote=origin"
  echo "  3. git push -u origin main"
  echo "  4. gh release create v1.0.0 --title 'v1.0.0' --notes 'Initial release'"
  echo ""
  exit 0
fi

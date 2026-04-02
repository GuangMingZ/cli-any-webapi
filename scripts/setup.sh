#!/usr/bin/env bash
# cli-any-webapi environment setup checker
# Run this before using the plugin to verify your environment is ready.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║      cli-any-webapi — Environment Check      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ─── Node.js ──────────────────────────────────────────────────────────────────

echo "Checking Node.js..."
if ! command -v node &>/dev/null; then
  echo -e "  ${RED}✗ node not found${NC}"
  echo "    Install Node.js >= 18 from https://nodejs.org"
  ERRORS=$((ERRORS + 1))
else
  NODE_VERSION=$(node --version)
  NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_MAJOR" -lt 18 ]; then
    echo -e "  ${RED}✗ Node.js ${NODE_VERSION} found, but >= 18 is required${NC}"
    echo "    Upgrade at https://nodejs.org"
    ERRORS=$((ERRORS + 1))
  else
    echo -e "  ${GREEN}✓ Node.js ${NODE_VERSION}${NC}"
  fi
fi

# ─── npm ──────────────────────────────────────────────────────────────────────

echo "Checking npm..."
if ! command -v npm &>/dev/null; then
  echo -e "  ${RED}✗ npm not found${NC}"
  echo "    npm comes with Node.js — reinstall Node.js"
  ERRORS=$((ERRORS + 1))
else
  NPM_VERSION=$(npm --version)
  echo -e "  ${GREEN}✓ npm ${NPM_VERSION}${NC}"
fi

# ─── TypeScript ───────────────────────────────────────────────────────────────

echo "Checking TypeScript (tsc)..."
if ! command -v tsc &>/dev/null; then
  echo -e "  ${YELLOW}⚠ tsc not found globally${NC}"
  echo "    This is OK — tsc will be installed locally in the generated package."
  echo "    To install globally: npm install -g typescript"
  WARNINGS=$((WARNINGS + 1))
else
  TSC_VERSION=$(tsc --version)
  echo -e "  ${GREEN}✓ ${TSC_VERSION}${NC}"
fi

# ─── tsup ─────────────────────────────────────────────────────────────────────

echo "Checking tsup..."
if ! command -v tsup &>/dev/null; then
  echo -e "  ${YELLOW}⚠ tsup not found globally${NC}"
  echo "    This is OK — tsup will be installed locally in the generated package."
  echo "    To install globally: npm install -g tsup"
  WARNINGS=$((WARNINGS + 1))
else
  TSUP_VERSION=$(tsup --version 2>/dev/null || echo "unknown")
  echo -e "  ${GREEN}✓ tsup ${TSUP_VERSION}${NC}"
fi

# ─── Config directory ─────────────────────────────────────────────────────────

echo "Checking config directory..."
CONFIG_DIR="$HOME/.cli-any-webapi"
CONFIG_FILE="$CONFIG_DIR/config.json"

if [ ! -d "$CONFIG_DIR" ]; then
  echo -e "  ${YELLOW}⚠ Config directory not found: ${CONFIG_DIR}${NC}"
  echo "    Creating it now..."
  mkdir -p "$CONFIG_DIR"
  echo -e "  ${GREEN}✓ Created ${CONFIG_DIR}${NC}"
  WARNINGS=$((WARNINGS + 1))
else
  echo -e "  ${GREEN}✓ ${CONFIG_DIR} exists${NC}"
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "  ${YELLOW}⚠ No config file found at ${CONFIG_FILE}${NC}"
  echo "    Creating default config..."
  cat > "$CONFIG_FILE" << 'CONFIGEOF'
{
  "baseUrl": "http://localhost:3000",
  "headers": {},
  "timeout": 30000
}
CONFIGEOF
  chmod 600 "$CONFIG_FILE"
  echo -e "  ${GREEN}✓ Created default config at ${CONFIG_FILE}${NC}"
  echo "    Edit it to set your API base URL and auth headers."
  WARNINGS=$((WARNINGS + 1))
else
  echo -e "  ${GREEN}✓ Config found at ${CONFIG_FILE}${NC}"
  # Validate JSON
  if node -e "JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8'))" 2>/dev/null; then
    echo -e "  ${GREEN}✓ Config JSON is valid${NC}"
  else
    echo -e "  ${RED}✗ Config JSON is invalid — fix ${CONFIG_FILE}${NC}"
    ERRORS=$((ERRORS + 1))
  fi
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────────────"

if [ $ERRORS -gt 0 ]; then
  echo -e "${RED}✗ ${ERRORS} error(s) found. Please fix them before using cli-any-webapi.${NC}"
  echo ""
  exit 1
elif [ $WARNINGS -gt 0 ]; then
  echo -e "${YELLOW}✓ Environment ready with ${WARNINGS} warning(s) (non-blocking).${NC}"
  echo ""
else
  echo -e "${GREEN}✓ Environment is fully ready.${NC}"
  echo ""
fi

echo "Available slash commands:"
echo "  /cli-any-webapi generate <source-path> [--logs <log-file>]"
echo "  /cli-any-webapi add <cli-path> <module> <method> <api-path>"
echo "  /cli-any-webapi sync <cli-path> [--source <path>] [--logs <path>]"
echo "  /cli-any-webapi list [--path <dir>] [--json]"
echo ""
echo "Config file: ~/.cli-any-webapi/config.json"
echo ""

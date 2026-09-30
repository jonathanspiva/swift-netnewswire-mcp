#!/bin/sh
# Build a Claude Desktop extension (.mcpb) containing the release binary.
# Output: .build/netnewswire-mcp.mcpb (install by double-clicking it).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$ROOT/.build/mcpb"
OUT="$ROOT/.build/netnewswire-mcp.mcpb"

swift build -c release --package-path "$ROOT"

rm -rf "$STAGE"
mkdir -p "$STAGE/server"
cp "$ROOT/mcpb/manifest.json" "$STAGE/"
cp "$ROOT/.build/release/netnewswire-mcp" "$STAGE/server/"

npx --yes @anthropic-ai/mcpb validate "$STAGE/manifest.json"
npx --yes @anthropic-ai/mcpb pack "$STAGE" "$OUT"
echo "Built $OUT"

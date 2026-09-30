#!/bin/sh
# Build a Claude Desktop extension (.mcpb) containing the release binary.
# Output: .build/netnewswire-mcp.mcpb (install by double-clicking it).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$ROOT/.build/mcpb"
OUT="$ROOT/.build/netnewswire-mcp.mcpb"

# Universal binary (Apple Silicon + Intel); both slices target macOS 26.
ARCHS="--arch arm64 --arch x86_64"
swift build -c release --package-path "$ROOT" $ARCHS
BIN="$(swift build -c release --package-path "$ROOT" $ARCHS --show-bin-path)/netnewswire-mcp"

rm -rf "$STAGE"
mkdir -p "$STAGE/server"
cp "$ROOT/mcpb/manifest.json" "$STAGE/"
cp "$BIN" "$STAGE/server/"

npx --yes @anthropic-ai/mcpb validate "$STAGE/manifest.json"
npx --yes @anthropic-ai/mcpb pack "$STAGE" "$OUT"
echo "Built $OUT"

#!/bin/sh
# Claude Code plugin launcher. A plugin installs from git, which has no compiled
# binary, so on first run this downloads the pinned release tarball, checks its
# SHA-256 against the value below, and caches the binary in the plugin's data
# directory. Every run then execs the cached binary.
#
# stdout belongs to the MCP protocol: all diagnostics go to stderr.
#
# Set NETNEWSWIRE_MCP_BIN to run a local build instead (for development).
set -eu

# Keep VERSION in sync with `serverVersion` (a test enforces it). On release,
# set SHA256 to the tarball's line in the release's SHA256SUMS.txt.
VERSION="1.1.0"
SHA256="b88d898e0cf96bf611d6f3945c13a1ab7c5e20b8a6d5440dc68486318aa6e77e"
REPO="jonathanspiva/swift-netnewswire-mcp"
TARBALL="netnewswire-mcp-$VERSION-macos-universal.tar.gz"

if [ -n "${NETNEWSWIRE_MCP_BIN:-}" ]; then
    exec "$NETNEWSWIRE_MCP_BIN" "$@"
fi

DATA="${CLAUDE_PLUGIN_DATA:?CLAUDE_PLUGIN_DATA is not set; run this through Claude Code}"
BIN="$DATA/$VERSION/netnewswire-mcp"

if [ ! -x "$BIN" ]; then
    echo "netnewswire-mcp: downloading v$VERSION" >&2
    mkdir -p "$DATA"
    TMP="$(mktemp -d "$DATA/download.XXXXXX")"
    trap 'rm -rf "$TMP"' EXIT
    curl -fsSL --retry 2 -o "$TMP/$TARBALL" \
        "https://github.com/$REPO/releases/download/v$VERSION/$TARBALL" >&2
    if ! (cd "$TMP" && echo "$SHA256  $TARBALL" | shasum -a 256 -c - >&2); then
        echo "netnewswire-mcp: checksum mismatch for $TARBALL; refusing to run it" >&2
        exit 1
    fi
    tar -xzf "$TMP/$TARBALL" -C "$TMP" netnewswire-mcp
    mkdir -p "$DATA/$VERSION"
    # Rename within the same filesystem, so a concurrent launch never sees a
    # partial binary.
    mv "$TMP/netnewswire-mcp" "$BIN"
    rm -rf "$TMP"
    trap - EXIT
    # Drop binaries cached for older plugin versions.
    for old in "$DATA"/[0-9]*/; do
        if [ -d "$old" ] && [ "$old" != "$DATA/$VERSION/" ]; then
            rm -rf "$old"
        fi
    done
fi

exec "$BIN" "$@"

# Security Policy

This server reads your NetNewsWire databases, which contain your private reading
history, and hands the results to whichever MCP client you connect it to.

## Reporting a vulnerability

Please report vulnerabilities privately through
[GitHub's private vulnerability reporting](https://github.com/jonathanspiva/swift-netnewswire-mcp/security/advisories/new),
not as a public issue. Include steps to reproduce and the version you tested.

You can expect an initial response within a week.

## Supported versions

Only the latest release receives fixes.

## Scope

In scope: anything that lets the server modify NetNewsWire data, read files outside
NetNewsWire's account folders, run unintended SQL, or leak data through error
messages or logs.

Out of scope: what an MCP client or AI model does with data the server returns
by design.

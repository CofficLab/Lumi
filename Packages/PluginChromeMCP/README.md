# PluginChromeMCP

Contributes Google's Chrome DevTools MCP server to Lumi's existing MCP client.

`PluginMCP` handles configuration storage, connection lifecycle, tool registration,
and tool permission checks. This package only contributes the upstream server
configuration; it does not bundle Chrome or implement browser automation itself.

The server is seeded disabled. Enable **Chrome DevTools (official)** in Lumi's MCP
Servers settings to let the Agent control and inspect Chrome.

## Requirements

- Node.js LTS available to Lumi as `npx`
- Google Chrome current stable or newer

Lumi starts the upstream server with `npx -y chrome-devtools-mcp@latest`. The
upstream server starts Chrome when the Agent first calls a browser tool. By default,
this is a separate browser session; connect to a running Chrome instance using the
upstream server's advanced configuration when sharing an existing session is needed.

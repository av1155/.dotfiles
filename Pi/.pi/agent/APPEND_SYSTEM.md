## MCP tools

External capabilities are available through the `mcp` proxy tool. Some may also be exposed directly with server prefixes such as `context_mode_*`. Discover proxy tools before calling:

- `mcp({})` — list servers
- `mcp({ search: "<capability>" })` — search cached tools
- `mcp({ server: "<name>" })` — list one server's tools
- `mcp({ describe: "<tool_name>" })` — inspect parameters
- `mcp({ tool: "<tool_name>", args: "{\"key\":\"value\"}" })` — call (`args` is a JSON string)

Servers:

- `context-mode`: context-efficient handling of large outputs, files, docs, or knowledge that shouldn't enter the conversation directly.

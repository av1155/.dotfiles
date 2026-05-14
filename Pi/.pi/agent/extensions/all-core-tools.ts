interface ToolInfo {
    name: string;
}

interface ExtensionAPI {
    getAllTools(): ToolInfo[];
    getActiveTools(): string[];
    setActiveTools(names: string[]): void;
    on(event: "session_start" | "before_agent_start", handler: () => Promise<void>): void;
}

// SHARED: keep in sync with CORE_TOOL_NAMES at agent/packages/pi-claude-style-interop/index.ts
const CORE_TOOLS = ["read", "bash", "edit", "write", "grep", "find", "ls"] as const;

export default function allCoreTools(pi: ExtensionAPI): void {
    function enableCoreTools(): void {
        const allToolNames = new Set(pi.getAllTools().map((tool) => tool.name));
        const activeToolNames = new Set(pi.getActiveTools());

        for (const tool of CORE_TOOLS) {
            if (allToolNames.has(tool)) {
                activeToolNames.add(tool);
            }
        }

        pi.setActiveTools(Array.from(activeToolNames));
    }

    pi.on("session_start", async () => {
        enableCoreTools();
    });

    pi.on("before_agent_start", async () => {
        enableCoreTools();
    });
}

import { transformInlineSkillInvocation } from "../inline-skill-invocations.ts";

const commands = [
    {
        name: "skill:review",
        description: "Review code and plans.",
        source: "skill",
    },
    {
        name: "skill:agentic-coding-harnesses",
        description: "Agentic harness reference.",
        source: "skill",
    },
    {
        name: "skill:settings",
        description: "Conflicting skill name for tests.",
        source: "skill",
    },
    {
        name: "custom-command",
        description: "A non-skill command.",
        source: "extension",
    },
] as const;

function transform(text: string): ReturnType<typeof transformInlineSkillInvocation> {
    return transformInlineSkillInvocation(text, [...commands]);
}

function assertDeepEqual(actual: unknown, expected: unknown): void {
    const actualJson = JSON.stringify(actual);
    const expectedJson = JSON.stringify(expected);
    if (actualJson !== expectedJson) {
        throw new Error(`Expected ${expectedJson}, got ${actualJson}`);
    }
}

function assertNull(actual: unknown): void {
    if (actual !== null) throw new Error(`Expected null, got ${JSON.stringify(actual)}`);
}

function test(name: string, run: () => void): void {
    run();
    console.log(`ok - ${name}`);
}

test("rewrites a whole-line explicit skill invocation", () => {
    assertDeepEqual(transform("/skill:review"), {
        skillName: "review",
        text: "/skill:review",
    });
});

test("rewrites a whole-line bare skill invocation", () => {
    assertDeepEqual(transform("/review"), {
        skillName: "review",
        text: "/skill:review",
    });
});

test("preserves line-start inline arguments", () => {
    assertDeepEqual(transform("/review refactor/refactor-pass-2026-05 (all commits)"), {
        skillName: "review",
        text: "/skill:review refactor/refactor-pass-2026-05 (all commits)",
    });
});

test("rewrites a trailing bare same-line skill token", () => {
    assertDeepEqual(
        transform("Is it compatible with my other coding harnesses? /agentic-coding-harnesses"),
        {
            skillName: "agentic-coding-harnesses",
            text: "/skill:agentic-coding-harnesses Is it compatible with my other coding harnesses?",
        },
    );
});

test("rewrites a trailing explicit same-line skill token", () => {
    assertDeepEqual(transform("Review this branch /skill:review"), {
        skillName: "review",
        text: "/skill:review Review this branch",
    });
});

test("rewrites a middle-of-sentence bare same-line skill token", () => {
    assertDeepEqual(transform("Why did /agentic-coding-harnesses not load?"), {
        skillName: "agentic-coding-harnesses",
        text: "/skill:agentic-coding-harnesses Why did agentic-coding-harnesses not load?",
    });
});

test("rewrites a middle-of-sentence explicit same-line skill token", () => {
    assertDeepEqual(transform("Why did /skill:agentic-coding-harnesses not load?"), {
        skillName: "agentic-coding-harnesses",
        text: "/skill:agentic-coding-harnesses Why did agentic-coding-harnesses not load?",
    });
});

test("ignores same-line skill tokens inside inline code spans", () => {
    assertNull(transform("Why did `/agentic-coding-harnesses` not load?"));
});

test("ignores skill tokens inside fenced code blocks", () => {
    assertNull(transform("```\n/review\n```"));
});

test("ignores path-like slash segments", () => {
    assertNull(
        transform("Open /Users/andreaventi/.dotfiles/Agents/.agents/skills/review/SKILL.md"),
    );
    assertNull(transform("Open /review/SKILL.md"));
    assertNull(transform("Open /review.md"));
});

test("ignores unknown same-line skill tokens", () => {
    assertNull(transform("Please use /missing-skill"));
});

test("ignores bare same-line skill tokens that conflict with non-skill commands", () => {
    assertNull(transform("Open /settings"));
});

test("allows explicit same-line skill tokens that conflict with non-skill commands", () => {
    assertDeepEqual(transform("Open /skill:settings"), {
        skillName: "settings",
        text: "/skill:settings Open",
    });
});

test("ignores already-wrapped skill content", () => {
    assertNull(transform('<skill name="review">\nReview this\n</skill>'));
});

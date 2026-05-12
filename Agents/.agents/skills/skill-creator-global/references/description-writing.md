# Description Writing

A skill description is the main trigger surface. Most agents see the name and description before they decide whether to load the full `SKILL.md`.

## Write the description

- Start with the core capability.
- Use words the user is likely to say in prompts.
- Include the key work objects: files, formats, workflows, domains, or failure modes.
- Add anti-triggers when the skill is easy to overuse.
- Keep the strongest trigger words early.

## Useful shape

```yaml
description: Do X for Y. Use when the user asks for A, B, or C. Skip when D or E.
```

Use one paragraph unless the skill truly needs more. Do not bury trigger phrases in the body when they belong in `description`.

## Failure modes

- Vague capability: "Helps with docs" does not tell the agent when to load the skill.
- Missing user language: if users say "release notes" but the description only says "changelog synthesis", triggering will be unreliable.
- No boundary: broad descriptions cause over-triggering.
- Late trigger words: long preambles may be truncated or ignored before the useful terms appear.
- Body-only trigger guidance: agents may never read the body if the description does not trigger.

## Examples

Weak:

```yaml
description: Helps create better skills.
```

Stronger:

```yaml
description: Create or revise Agent Skills. Use when writing SKILL.md files, improving skill descriptions, choosing trigger words, or deciding what belongs in the main skill versus references or scripts.
```

Weak:

```yaml
description: Browser testing guidance.
```

Stronger:

```yaml
description: Test and debug web apps with browser automation. Use when capturing screenshots, inspecting console errors, verifying UI flows, or writing Playwright tests. Skip for non-browser unit tests.
```

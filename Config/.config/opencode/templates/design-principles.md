# design-principles.md

## Purpose

Define core design principles for {{PROJECT_NAME}} to ensure a consistent, accessible experience for {{PRIMARY_USERS}} across {{PLATFORMS}}.

## How to Use this Template

- Replace placeholders with project details; remove optional ones (e.g. `{{TECH_STACK}}` if not used).
- Use "WCAG 2.2 AA" for `{{ACCESSIBILITY_TARGET}}`; list themes in `{{SUPPORTED_THEMES}}` (e.g. Light, Dark) and key breakpoints in `{{KEY_BREAKPOINTS}}`.
- If no user-facing UI, omit this file.

## Core Principles

- **Accessibility First:** Design for all abilities; meet or exceed {{ACCESSIBILITY_TARGET}} standards
- **Clarity & Hierarchy:** Emphasize clear content and visual hierarchy
- **Consistency:** Use consistent patterns, terminology, and layouts
- **Progressive Disclosure:** Reveal complexity gradually to avoid overwhelming users
- **Meaningful Feedback & States:** Provide timely, clear feedback; use distinct states
- **Error Prevention & Recovery:** Prevent errors when possible; ensure easy recovery
- **Performance & Perceived Speed:** Optimize for fast performance; provide feedback during delays
- **Responsive/Adaptive Design:** Work well on all {{PLATFORMS}} and screen sizes
- **Internationalization & RTL:** Support multiple languages and right-to-left layouts
- **Privacy & Data Minimization:** Minimize data collection; respect user privacy
- **Ethical & Inclusive Design:** Design for diverse users and scenarios; avoid bias and exclusion
- **Resilience/Offline Tolerance:** Gracefully handle network issues; support offline use when possible

## Decision Rules

Follow this priority order:

1. **User Goals** – prioritize the needs of {{PRIMARY_USERS}}
2. **Accessibility** – ensure inclusive access
3. **Clarity** – make it easy to understand
4. **Efficiency** – enable quick use
5. **Brand Expression** – reflect the brand appropriately
6. **Aesthetics** – enhance visual appeal

If unresolved: 1) state each option’s goal or principle; 2) choose the higher-priority option; 3) document trade-offs

## Definition of Done (Visual & Interaction) – Checklist

- [ ] Acceptance criteria met
- [ ] Color contrast meets **{{ACCESSIBILITY_TARGET}}** guidelines
- [ ] Focus order is logical; all elements are keyboard-accessible
- [ ] All interactive elements have accessible labels or alt text
- [ ] No blocking layout shifts or overflow at **{{KEY_BREAKPOINTS}}**
- [ ] Consistent behavior and appearance across **{{SUPPORTED_THEMES}}**
- [ ] Respects reduced-motion preferences
- [ ] Content uses plain language and appropriate tone
- [ ] No console errors or warnings
- [ ] Before/after screenshots attached
- [ ] Change summary documented

## References

- WCAG 2.2
- WAI-ARIA Authoring Practices
- Nielsen’s 10 Usability Heuristics
- Inclusive Design Principles
- ISO 9241-210
- Plain Language Guidelines

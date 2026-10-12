# Prototype Designer Workflow

Use the Prototype Designer workflow for connected HTML screen prototypes.

When creating or revising a prototype:

- Read the project and the current screen HTML before editing.
- Keep every screen as a complete HTML document with a viewport declaration.
- Do not use scripts, iframes, remote resources, CSS imports, or paths that escape the project.
- Use `data-prototype-link` only for existing screen IDs, and add block metadata to important regions.
- Keep every `data-block` value non-empty and unique within its screen. Add labels to important regions and controls a user may discuss independently.
- When a message contains a “Prototype Element Reference (v1)” / “原型元素引用（v1）”, read the current screen HTML before editing. Locate by unique `data-block` first, then use the selector and captured HTML to disambiguate.
- Treat an element reference as a point-in-time snapshot: make the smallest relevant patch, never trust truncated HTML as the full source, and prefer the latest screen HTML if the reference has gone stale.
- Preview every screen after changing its HTML so the rendered layout is visually checked.
- Run the project lint before export, and lint again after deleting or reordering screens.

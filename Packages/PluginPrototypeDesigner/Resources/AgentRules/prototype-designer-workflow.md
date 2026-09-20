# Prototype Designer Workflow

Use the Prototype Designer workflow for connected HTML screen prototypes.

When creating or revising a prototype:

- Read the project and the current screen HTML before editing.
- Keep every screen as a complete HTML document with a viewport declaration.
- Do not use scripts, iframes, remote resources, CSS imports, or paths that escape the project.
- Use `data-prototype-link` only for existing screen IDs, and add block metadata to important regions.
- Preview every screen after changing its HTML so the rendered layout is visually checked.
- Run the project lint before export, and lint again after deleting or reordering screens.

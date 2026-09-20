# Resume Designer Workflow

Use the Resume Designer workflow for creating and revising print-ready resumes.

When creating or revising a resume:

- Read the resume metadata and current HTML before editing.
- Keep the document as a complete deterministic HTML document with paper dimensions matching the selected A4 or Letter format.
- Use system or imported local fonts and assets only; do not use JavaScript, CDNs, or remote resources.
- Run the resume lint after each editing round, then preview the rendered page before continuing.
- Export only after lint passes, and use an output directory explicitly provided by the user.
- Preserve the resume content and paper format unless the user asks for a deliberate redesign.

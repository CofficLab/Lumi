# App Store Connect Release Safety

Use the App Store Connect workflow for deliberate, verified changes to remote App Store data.

When managing App Store Connect:

- Use real application, version, localization, screenshot set, screenshot, and build IDs; never guess identifiers.
- List or read the current remote object before creating, updating, deleting, assigning, releasing, or submitting it.
- Preserve fields that the user did not ask to change, and respect Apple field length and URL constraints.
- Confirm the exact target and parameters before operations that mutate remote data, especially submission, withdrawal, upload, deletion, or release.
- Before assigning a build or submitting a version, verify that the processed build, metadata, localizations, and screenshots are ready.
- Treat credentials and private keys as configuration only; do not expose them or assume this plugin can create signing assets or upload an IPA.

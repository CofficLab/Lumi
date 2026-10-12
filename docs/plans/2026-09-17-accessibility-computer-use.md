# Accessibility-first Computer Use

Status: accepted for implementation following user review, 2026-09-17.

## Decision

Keep execution on the current Mac. Add bounded Accessibility observations and
element actions before the existing coordinate tools. AX operations must never
activate the app or synthesize global input. Report unsupported and uncertain
results explicitly; never retry an uncertain toggle automatically.

Native input uses one process-wide coordinator: waiting for permission → countdown
→ running → released. Physical input or focus loss pauses the job, removes the
blocking Lumi overlay, and keeps a non-activating desktop banner with Continue and
Stop. Continue completes the interrupted call with a re-observe requirement, not
a replay of stale coordinates. Cancellation, timeout and shutdown clean up input,
monitoring and presentation. A batch is limited to 10 actions / 20 seconds.

The existing root-overlay provider hosts the Lumi mask. A non-activating panel
hosts the desktop banner. Only target-window screenshots are sent to the model.
Permission is remembered per application; the user must explicitly enable native
input. The model cannot grant consent or clear a paused operation.

## Shell boundary

The built-in run_command tool will use an inherited macOS sandbox profile denying
desktop input and Apple Events / UI service access. No unsandboxed retry. Verify
ordinary build/read commands as well as GUI-service denial. This is a narrow
desktop boundary, not a claim to contain arbitrary malicious code or every other
plugin/tool. Document the tested scope and any residual broker paths.

## Implementation and verification

1. AX observation/action tools: bounded trees, opaque snapshot-scoped IDs, secret
   field exclusion, supported-action checks, settable-value checks, readback.
2. Native coordinator and UI: consent, preparation, global ownership, timeout,
   user-interruption latch, fresh-observation requirement, task cancellation.
3. Shell desktop sandbox and regression tests; verify with real child processes.
4. Package tests and integrated app build. Use synthetic events/fixtures for input
   interruption tests; do not control production Kuzee or the user's desktop.

## Tradeoffs

AX support varies by application and is not a guarantee against app-originated
focus changes. Native mode remains necessary. VM/remote execution was rejected
for this iteration due to setup/resource costs. Keyword blocking alone was rejected
as an enforceable desktop boundary. Live native-app acceptance requires a dedicated
test target and explicit visibility into the test interaction.

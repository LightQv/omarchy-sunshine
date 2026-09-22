# Release Checklist

Run this checklist against the exact commit intended for release.

## Metadata

- Manifest, changelog, and tag use the same semantic version.
- README installation links target the canonical `.git` repository URL.
- Runtime dependencies and tested versions are current.
- The changelog contains a dated release section and valid release links.
- Root `preview.png` represents the release commit and contains no private data.
- No `AGENTS.md` or `CLAUDE.md` file is included in the repository.

## Automated Validation

```bash
omarchy plugin validate .
bash scripts/check-release-metadata.sh
bash scripts/lint-qml.sh
bash scripts/test-service.sh
bash scripts/test-panel.sh
node --test tests/*.test.js
bash -n scripts/*.sh tests/helpers/fake-systemctl
git diff --check
```

## Clean Checkout

- Clone the release candidate into a new temporary directory.
- Confirm no generated files, local instructions, or symlinks are tracked.
- Run manifest validation, metadata checks, QML lint, and model tests there.
- Install Sunshine before adding the plugin; the plugin manager does not install
  external dependencies.
- Add, enable, update, disable, and remove the plugin through Omarchy's plugin
  commands using the published canonical repository URL.

## Live Omarchy Validation

- Confirm the exact `app-dev.lizardbyte.app.Sunshine.service` user unit is used.
- Verify off, starting, on, stopping, failed, missing, and unavailable states.
- Verify left-click, right-click, and complete keyboard navigation.
- Verify start and stop actions without changing login auto-start.
- Verify enable and disable at login without changing the current runtime state.
- Verify the default Web UI port and one valid custom base-port configuration.
- Verify hide-when-off behavior and persistence after restarting the shell.
- Verify at least one dark and one light Omarchy theme.
- Verify no plugin-attributed QML warnings, binding loops, or script errors.
- Confirm the plugin does not modify Sunshine configuration, notifications, or
  its native tray icon.

## Removal

- Disable the plugin and confirm Sunshine continues in its existing state.
- Remove the plugin and confirm Sunshine configuration and systemd enablement
  remain unchanged.
- Confirm reinstalling the plugin discovers the existing Sunshine state.

## Release

- Review the final diff for secrets, private identifiers, and generated files.
- Obtain correctness, security, and Omarchy integration approval.
- Tag the validated commit as `v<version>`.
- Push `main` and the tag, then confirm GitHub Actions passes.
- Publish release notes from the matching changelog section.

# Summary

Describe the change and link its tracking issue when applicable.

## Validation

- [ ] The change is focused and contains no unrelated functionality.
- [ ] I added or updated deterministic tests where behavior changed.
- [ ] I updated user-facing documentation and known limitations where needed.
- [ ] I ran the applicable README development checks and listed omissions below.
- [ ] I tested relevant Sunshine runtime and auto-start transitions on Omarchy.
- [ ] The change does not modify Sunshine configuration, notifications, or its native tray icon.
- [ ] I removed usernames, paths, addresses, credentials, and unrelated entries from logs and fixtures.

Validation performed and any environment limitations:

## Sunshine Integration

Delete this section when the pull request does not change Sunshine integration.

- [ ] The exact `app-dev.lizardbyte.app.Sunshine.service` user unit remains in use.
- [ ] Runtime controls and login auto-start remain independent.
- [ ] Missing, failed, unavailable, and transitional states were checked.
- [ ] Default and custom Web UI port behavior was checked where applicable.
- [ ] Disable and removal leave Sunshine state, enablement, and configuration unchanged.

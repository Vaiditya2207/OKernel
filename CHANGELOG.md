# Aether v0.6.0 - Major Auto-Update Overhaul

This release introduces a production-grade Auto-Update system with a focus on reliability, security, and performance.

## 🚀 New Features
- **Seamless Background Updates**: Aether now silently checks for and downloads updates in the background. You'll simply see an "Update Ready" notification when it's time to restart.
- **Delta Updates (bsdiff)**: Updates are now delivered as binary patches when possible, reducing download sizes by up to 90% and making updates nearly instant.
- **Automated Rollback**: If a new version fails to launch or crashes repeatedly, Aether will automatically roll back to the previously stable version.
- **Release Channels**: Support for **Stable**, **Beta**, and **Dev** update channels (configurable in settings).

## 🛡️ Security
- **Ed25519 Signing**: All update bundles and patches are now cryptographically signed. The client verifies the signature before applying any changes, preventing MITM attacks.

## 📊 Observability
- **Update Telemetry**: Integrated reporting for update success and rollback events to help us monitor rollout health.

## 🛠️ Infrastructure
- **Enhanced CI/CD**: Fully automated release pipeline with automated signing and patch generation.
- **SysCore Integration**: Backend updated to handle signed metadata and telemetry storage.

---
*Aether - The modern terminal for macOS.*

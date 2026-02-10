# mac_cleaner

A shell script that audits storage on a developer's macOS machine. It scans common locations that inflate "System Data" in macOS storage settings — developer tools, caches, build artifacts, and more — and reports what's consuming space with cleanup instructions.

**This script is read-only. It does not delete anything.** It only measures directory sizes and prints a report.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/Bersh/mac_cleaner/main/mac_storage_audit.sh -o mac_storage_audit.sh
chmod +x mac_storage_audit.sh
./mac_storage_audit.sh
```

Or clone and run:

```bash
git clone https://github.com/Bersh/mac_cleaner.git
cd mac_cleaner
chmod +x mac_storage_audit.sh
./mac_storage_audit.sh
```

Some system directories require elevated permissions for accurate sizing:

```bash
sudo ./mac_storage_audit.sh
```

## What It Scans

| Category | Examples |
|---|---|
| Docker | Disk images, VM data |
| Package managers | Homebrew, npm, Yarn, pnpm, pip, Maven, Gradle, Go modules, Cargo, CocoaPods, Pub |
| IDEs & dev tools | Xcode (DerivedData, Archives, simulators), Android SDK/AVD, JetBrains caches, VS Code |
| Cloud & VMs | Google Cloud SDK, Firebase, Terraform, Minikube, Vagrant |
| System caches | ~/Library/Caches, logs, Spotlight, Time Machine snapshots, swap |
| Build artifacts | `node_modules`, `target`, `build`, `dist`, `.next`, `.nuxt`, `__pycache__` (scanned recursively) |

## Safety Levels

Each finding is tagged with a safety level:

- **SAFE** — can be deleted without consequence; will regenerate on next use (e.g., caches, DerivedData, logs)
- **CAUTION** — safe to delete but will trigger re-downloads or has minor side effects (e.g., Maven `.m2`, system logs)
- **REVIEW** — inspect manually before deleting; may contain important data (e.g., Docker volumes, Xcode Archives, Android SDK)

The summary at the end totals only **SAFE** items as "estimated safely reclaimable space."

## Options

```
./mac_storage_audit.sh              # standard audit
./mac_storage_audit.sh --no-color   # plain text output (useful for piping/logging)
./mac_storage_audit.sh --help       # show usage info
```

## Example Output

```
🔎 macOS System Data Storage Audit
   Running as: user | Date: 2026-02-10 14:00

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🐳 DOCKER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🔍 Docker disk image (all data)                    18.42 GB  [REVIEW]
     ↳ Contains all images, containers, volumes. Use 'docker system prune -a' to clean
     Path: /Users/user/Library/Containers/com.docker.docker/Data

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📦 PACKAGE MANAGERS & LANGUAGE CACHES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ Homebrew cache                                    832.0 MB  [SAFE]
     ↳ Old downloads. Clean: brew cleanup --prune=all
     Path: /Users/user/Library/Caches/Homebrew
  ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📊 SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Estimated safely reclaimable space: 14.7 GB
```

The summary also prints copy-paste cleanup commands for common tools (Docker, Homebrew, npm, Xcode, etc.).

## Requirements

- macOS (tested on Ventura, Sonoma, Sequoia)
- Bash 3.2+ (ships with macOS)
- Standard macOS utilities: `du`, `bc`, `find`

Works on both Intel and Apple Silicon Macs.

## Contributing

Contributions are welcome! Some ideas:

- Add more scan targets (Ruby gems, Python virtualenvs, etc.)
- Add a `--json` output mode
- Add threshold flags to control minimum reported size

Please open an issue first to discuss larger changes.

## License

[MIT](LICENSE)

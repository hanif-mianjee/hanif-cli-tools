# Hanif CLI - Quick Start

## Get Started

```bash
# Install locally for development
cd /Users/hanifmianjee/code/personal/hanif-cli-tools
bash scripts/dev-install.sh

# Verify
hanif version
hanif help
```

## Commands

| Command | What it does |
|---------|-------------|
| `hanif sync` | Update main, rebase, cleanup |
| `hanif nf <desc>` | Create a branch (multi-word ok; `--prefix` to override `feature/`) |
| `hanif up` | Update main branch |
| `hanif upall` | Update all branches |
| `hanif clean` | Delete branches removed from remote |
| `hanif rb main` | Rebase onto branch |
| `hanif squash [count]` | Interactive commit squashing (default: 20) |
| `hanif gi <path>` | Add to .gitignore & remove from tracking |
| `hanif svg convert ...` | SVG to PNG conversion |
| `hanif help` | Show help |

## Examples

```bash
# Create a feature branch
hanif nf add user authentication
# → feature/add_user_authentication

# With ticket number (single quotes keep ` < > $ intact)
hanif nf 'OM-755: fix login bug'
# → feature/OM-755_fix_login_bug

# No arguments → prompts for the description (paste anything, no quoting)
hanif nf

# Override the feature/ prefix
hanif nf --prefix hotfix 'OM-756: patch login'
# → hotfix/OM-756_patch_login

# Full sync (update, rebase, clean)
hanif sync

# Rebase current branch
hanif rb main

# Add file to .gitignore and untrack it
hanif gi .env
```

## Add Your Own Commands

1. Create `lib/commands/mycommand.sh`:

   ```bash
   mycommand_handler() {
     info "Running..."
     success "Done!"
   }
   ```

2. Register in `bin/hanif`:

   ```bash
   mycommand)
     source "${COMMANDS_DIR}/mycommand.sh"
     mycommand_handler "$@"
     ;;
   ```

3. Use: `hanif mycommand`

## Testing

```bash
bash tests/run-tests.sh
```

## Project Structure

```
bin/hanif              # Main CLI entry point
lib/
  commands/            # Command handlers (add yours here)
  functions/           # Core logic
  utils/common.sh      # Helpers (info, success, error, etc.)
tests/                 # Test files
scripts/               # Build/install scripts
```

For more details, see [README.md](README.md).

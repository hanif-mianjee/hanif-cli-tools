# Hanif CLI - Simple & Extensible

## What It Is

A **simple, personal CLI tool** that's easy to extend for any daily task. Comes with git helpers, but designed to add your own commands easily.

## Quick Start

```bash
# Test it
./bin/hanif version
./bin/hanif help

# Install locally
bash scripts/dev-install.sh

# Use it
hanif git sync
hanif git nf "my feature"
```

## Built-In Commands

### Git Helpers
- `hanif git sync` - Full sync (update, rebase, clean) ⭐
- `hanif git nf "desc"` - Create feature branch
- `hanif git up` - Update main
- `hanif git upall` - Update all branches
- `hanif git clean` - Remove deleted branches
- `hanif git rb main` - Rebase onto main

**Note:** Unknown git commands pass through to git

## Add Your Own Commands

### 3 Simple Steps

1. **Create**: `lib/commands/mycommand.sh`
   ```bash
   mycommand_handler() {
     info "Running..."
     success "Done!"
   }
   ```

2. **Register**: Add to `bin/hanif`
   ```bash
   mycommand)
     source "${COMMANDS_DIR}/mycommand.sh"
     mycommand_handler "$@"
     ;;
   ```

3. **Use**: `hanif mycommand`

### Example: Docker Helper

```bash
# lib/commands/docker.sh
docker_handler() {
  case "$1" in
    clean)
      info "Cleaning docker..."
      docker system prune -af
      success "Done!"
      ;;
    *)
      docker "$@"
      ;;
  esac
}

# Use it
hanif docker clean
```

## Utilities Available

From `lib/utils/common.sh`:

```bash
info "Message"        # Blue ℹ
success "Message"     # Green ✓
warning "Message"     # Yellow ⚠
error "Message"       # Red ✗

is_git_repo          # Check if in git repo
get_current_branch   # Get current branch
confirm "Question?"  # Y/N prompt
```

## Project Structure

```
hanif-cli-tools/
├── bin/hanif              # Main CLI
├── lib/
│   ├── commands/          # Add your commands here
│   ├── functions/         # Reusable functions
│   └── utils/common.sh    # Helpers
├── tests/                 # Tests
├── scripts/               # Build/install
├── README.md             # Full docs
└── QUICKSTART.md         # Quick guide
```

## Files (22 total)

**Core:**
- `bin/hanif` - Main executable
- `lib/commands/` - Command handlers (git, help)
- `lib/functions/` - Git functions
- `lib/utils/` - Common utilities

**Tests:**
- `tests/` - Test framework and git tests (10 passing)

**Install:**
- `install.sh` - Direct installation
- `package.json` - npm package
- `hanif-cli.rb` - Homebrew formula
- `scripts/` - Dev install/build

**Docs:**
- `README.md` - Main documentation
- `QUICKSTART.md` - Quick start guide
- `CONTRIBUTING.md` - How to contribute
- `docs/DEVELOPMENT.md` - Development guide
- `CHANGELOG.md` - Version history

## Testing

```bash
bash tests/run-tests.sh    # All tests (10 passing ✓)
```

## Publishing

```bash
# Update version in package.json and bin/hanif
npm publish
```

## Key Design

✅ **Simple** - Easy to understand, easy to extend  
✅ **Not git-centric** - Git is just one category of commands  
✅ **Extensible** - Add commands for Docker, AWS, anything  
✅ **Tested** - 10 tests, all passing  
✅ **Clean** - No bloat, focused on usability  

## Next Steps

1. **Try it**: `./bin/hanif help`
2. **Install**: `bash scripts/dev-install.sh`
3. **Extend**: Add your own commands
4. **Customize**: Make it yours!

---

**Simple. Extensible. Yours.**

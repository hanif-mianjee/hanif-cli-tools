# Hanif CLI

> Personal productivity CLI for daily workflows

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/hanif-mianjee/hanif-cli-tools)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Website](https://img.shields.io/badge/website-hanif--mianjee.github.io-6d4cff.svg)](https://hanif-mianjee.github.io/hanif-cli-tools/)

🌐 **Website:** <https://hanif-mianjee.github.io/hanif-cli-tools/> — full command reference, scenarios, and install guide.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/hanif-mianjee/hanif-cli-tools/main/install.sh | bash
```

## Git Commands

```bash
hanif sync                          # Full sync (update main, rebase, clean)
hanif nf add user auth              # → feature/add_user_auth (no quotes needed!)
hanif nf "JIRA-123: fix bug"        # → feature/jira-123_fix_bug
hanif up                            # Update main/master branch
hanif upall                         # Update all branches
hanif clean                         # Delete branches removed from remote
hanif rb main                       # Rebase onto branch
hanif pull                          # Fetch all + pull
hanif st                            # Git status
hanif amend                         # Amend last commit (keep message)
hanif amend "new message"           # Amend last commit with new message
hanif gi .env                       # Add .env to .gitignore & untrack
hanif gi node_modules/              # Add node_modules/ to .gitignore & untrack
hanif gsetup work                   # Set up a new git profile (config + SSH key)
hanif wip                           # Park changes as "WIP: <timestamp>"
hanif wip refactor in progress      # Park as "WIP: refactor in progress"
hanif unwip                         # Undo the last WIP commit (soft reset)
hanif undo                          # Interactive "undo the last git thing" menu
hanif stash save "wip on form"      # Friendlier git stash save
hanif stash list                    # Tabular stash list
hanif stash pop                     # Pop (interactive picker if >1)
hanif pr                            # Open the current branch's PR/compare page
hanif pr url                        # Print the PR URL only
hanif pr copy                       # Copy the PR URL to the clipboard
```

Smart branch naming with `nf`:
- Extracts ticket numbers (JIRA-123, OM-755, ABC-42)
- Sanitizes names, converts to lowercase
- Enforces 60 character limit

## Productivity Commands

```bash
hanif clip                          # Copy stdin to the system clipboard
echo foo | hanif clip               # (same — auto-detects pbcopy/xclip/wl-copy/clip.exe)
hanif clip paste                    # Print clipboard contents to stdout
hanif ip                            # Show local + public IP and active interface
hanif ip local                      # Print local IP only
hanif ip copy public                # Copy public IP to clipboard
hanif ports                         # List all listening TCP ports
hanif ports 3000                    # Show what's on a single port
hanif ports kill 3000               # SIGTERM the process on a port (asks first)
hanif ports kill 3000 --force       # SIGKILL instead of SIGTERM
hanif serve                         # Static HTTP server on :8000 in the cwd
hanif serve 3000 ./dist             # Custom port + directory; prints LAN URL too
```

`hanif pr` supports GitHub, GitLab (incl. self-hosted + subgroups), Azure DevOps,
and Bitbucket Cloud. Set `HANIF_NO_BROWSER=1` to print the URL instead of opening
a browser (handy in SSH sessions). `hanif ip` respects `HANIF_OFFLINE=1` to skip
the public-IP lookup. `hanif undo` shows only the choices that apply to the current
repo state and double-confirms destructive actions.

## Squash Command

Interactive commit squashing with smart message formatting:

```bash
hanif squash          # Shows last 20 commits (default)
hanif squash 5        # Shows last 5 commits
```

**Workflow:** Select a commit to squash into, then optionally provide a custom message. All squashed commits are preserved with their hashes in the final message.

Result with custom message:
```
OM-1200 Major refactor
* 1a6c6d8 Third commit
* ef3798f Fourth commit
* a524b8f Fifth commit
```

Result without custom message (uses selected commit's message):
```
Third commit
* ef3798f Fourth commit
* a524b8f Fifth commit
```

Run `hanif squash --help` for the full guide.

## Gitignore Command

Add paths to `.gitignore` and remove them from git tracking in one step. Files stay on disk — only removed from the git index:

```bash
hanif gi .env                # Add .env to .gitignore & untrack
hanif gi node_modules/       # Add node_modules/ to .gitignore & untrack
hanif gi "*.log"             # Add *.log pattern to .gitignore & untrack
hanif gitignore .DS_Store    # Full command name also works
```

Creates `.gitignore` if it doesn't exist. Skips duplicate entries. Run `hanif gi --help` for the full guide.

## Bumpversion Command

Semantic version bumping with RC (release candidate) workflow:

```bash
hanif bv              # Interactive bump with preview menu
hanif bv init         # Initialize .bumpversion.cfg for your project
hanif bv patch        # 1.0.0 → 1.0.1-rc0
hanif bv minor        # 1.0.0 → 1.1.0-rc0
hanif bv major        # 1.0.0 → 2.0.0-rc0
hanif bv rc           # 1.0.1-rc0 → 1.0.1-rc1
hanif bv release      # 1.0.1-rc1 → 1.0.1
```

**Workflow:** Initialize with `hanif bv init`, then use `patch`/`minor`/`major` to create RC versions, `rc` to iterate, and `release` to promote.

**Features:**

- Auto-detects project type (Node.js, Python, Rust, Java, etc.)
- Updates version strings across all configured files
- Git commit and tag automation with push prompts
- Tag conflict detection with interactive resolution
- Pre-flight verification prevents partial updates
- Custom version input via interactive menu
- Compatible with `.bumpversion.cfg` format

Run `hanif bv --help` for the full guide.

## SVG Commands

Convert SVG to PNG with auto-detected converters (librsvg, Inkscape, ImageMagick):

```bash
hanif svg convert icon.svg 16,32,64                      # Custom sizes
hanif svg convert logo.svg 100,200 --prefix logo -o out  # Custom prefix/dir
hanif svg chrome icon.svg                                 # Chrome extension icons
```

## Env Command

Persist exported environment variables across shell sessions. Hanif writes vars to a managed file (`~/.hanif/env.sh`, or `~/.hanif/env.fish` for fish) and wires your shell profile to source it on startup — your own profile is touched at most once and only after you confirm.

```bash
hanif env set API_KEY=sk-abc123                       # Asks before writing
hanif env set DATABASE_URL "postgres://user:pass@host/db"  # Space form
hanif env list                                        # Tabular view (secrets masked)
hanif env get API_KEY                                 # Reveal a value
hanif env unset API_KEY                               # Remove (asks first)
hanif env source                                      # Print the load command for your shell
hanif env path                                        # Show env file + profile + wiring status
```

**Safety:**

- `KEY` validated against `^[A-Za-z_][A-Za-z0-9_]*$` — bad names rejected.
- `VALUE` shell-quoted with `printf '%q'` before writing (or fish-quoted on fish); user input is never `eval`-ed.
- Existing values trigger an overwrite warning before they're replaced.
- Values that look like secrets (`*TOKEN*`, `*SECRET*`, `*PASSWORD*`, `*KEY*`, `*API*`) are masked in `list`.
- A `.bak` side-file is created before every write.

**Profile detection:** `zsh` → `~/.zshrc`, `bash` → `~/.bash_profile` (macOS) or `~/.bashrc` (Linux), `fish` → `~/.config/fish/conf.d/hanif.fish`. Override with `HANIF_ENV_PROFILE` / `HANIF_ENV_FILE`.

Run `hanif env --help` for the full guide.

## Git Profile Setup

Juggling work / personal / freelance / experiments accounts? `hanif gsetup` is a one-shot that wires everything up so git auto-picks the right identity AND SSH key based on which directory the repo lives in:

```bash
hanif gsetup work                   # Asks for repos dir + name + email, then:
                                    #  • generates ~/.ssh/id_ed25519_work
                                    #  • writes ~/.gitconfig-work
                                    #  • appends an includeIf block to ~/.gitconfig
                                    #  • prints the public key + GitHub/Azure DevOps instructions
hanif gsetup personal               # Same flow for the next profile
hanif git-setup freelance           # Long-form alias
```

After setup, every repo cloned under the profile's directory (default `~/code/<profile>`) automatically uses that profile's name, email, and SSH key — no per-repo configuration. Re-running for the same profile updates the `includeIf` block in place instead of duplicating it. Run `hanif gsetup --help` for the full guide.

## Development

```bash
git clone https://github.com/hanif-mianjee/hanif-cli-tools.git
cd hanif-cli-tools
bash scripts/dev-install.sh
bash tests/run-tests.sh
```

### Project Structure

```text
bin/hanif              # Main CLI entry point (small dispatcher)
lib/
  registry.sh          # Command registry & dispatcher
  commands/            # Command files — each self-registers via register_command
  functions/           # Heavy implementation logic, lazy-loaded by handlers
  utils/common.sh      # Shared utilities (logging, git helpers)
tests/                 # Test suites (run via tests/run-tests.sh)
scripts/               # Build/install/publish scripts
```

### Adding Commands

Commands are auto-discovered. To add `hanif mycommand`:

1. Create `lib/commands/mycommand.sh`
2. Register and define your handler:

   ```bash
   register_command --name "mycommand" --group "Other" \
     --handler "mycommand_handler" \
     --description "What it does"

   mycommand_handler() {
     # Lazy-load any heavy logic from lib/functions/
     echo "Hello from mycommand: $*"
   }
   ```

3. Done — `bin/hanif` requires no changes. Add tests in `tests/test-mycommand.sh`.

### Publishing

```bash
# Automated: bumps version everywhere, tags, publishes
bash scripts/publish.sh
```

## Legacy Syntax

`hanif git <command>` still works for backward compatibility (e.g., `hanif git sync`).
This form will be removed in v2.0.0 — use `hanif <command>` directly.

## License

MIT

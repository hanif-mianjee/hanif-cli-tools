# Changelog

## [Unreleased]

### Fixed
- **`hanif pr`**: remote URL parsing now handles all Azure DevOps SSH URL formats:
  - SCP-style with any username (`myorg@vs-ssh.visualstudio.com:v3/<org>/<project>/<repo>`) — previously only `git@` usernames were accepted.
  - `ssh://` URLs via `vs-ssh.visualstudio.com` (in addition to the already-supported `ssh.dev.azure.com`).
  - Fixed a latent bug where `ssh://git@ssh.dev.azure.com/v3/…` URLs produced a malformed PR link due to a 3-field/4-field mismatch in the parser.

## [1.1.0] - 2026-05-07

## [1.0.0] - 2026-05-06

### Added
- **New command: `hanif gsetup`** (alias `hanif git-setup`) — one-shot setup for a new git profile (work, personal, freelance, experiments, …).
  - Asks for a profile name (or accepts it as an argument), suggests a default repos directory (`~/code/<profile>`), and prompts for `user.name` / `user.email`.
  - Generates a dedicated `ed25519` SSH key at `~/.ssh/id_ed25519_<profile>` (no passphrase by default — the summary tells you how to add one with `ssh-keygen -p` later).
  - Writes a per-profile gitconfig at `~/.gitconfig-<profile>` containing the right `user.name`/`user.email` and a `core.sshCommand` pinned to the new key.
  - Appends an idempotent `includeIf "gitdir:<repos-dir>/"` block to `~/.gitconfig` (delimited by `# >>> hanif gsetup: <profile> >>>` markers) so git auto-loads the right identity AND ssh key whenever you're working inside that directory — no per-repo configuration.
  - Detects existing keys / per-profile configs and asks before reusing or overwriting; backs up `~/.gitconfig` and the per-profile config as `<file>.bak` before any change.
  - Prints the public key plus copy-pasteable instructions for adding it to GitHub and Azure DevOps.
  - Re-running for the same profile updates the `includeIf` block in place instead of duplicating it.
- **New command: `hanif env`** (alias `hanif e`) — manage persistent environment variables.
  - Subcommands: `set KEY=VALUE` / `set KEY VALUE` (with overwrite detection), `unset KEY`, `list` (tabular view), `get KEY`, `source` (prints the load command for the current shell), `edit`, `path`.
  - Persists to a Hanif-managed file (`~/.hanif/env.sh`, or `~/.hanif/env.fish` for fish) and wires the user's shell profile (`~/.zshrc`, `~/.bashrc`/`~/.bash_profile`, or `~/.config/fish/conf.d/hanif.fish`) to source it once on shell start. The profile is touched at most once and only after explicit confirmation.
  - Strict safety: `KEY` validated against `^[A-Za-z_][A-Za-z0-9_]*$`, `VALUE` shell-quoted with `printf '%q'` before being written, no `eval` on user input, automatic `.bak` side-file before each write, secrets-looking keys (`*TOKEN*`/`*SECRET*`/`*PASSWORD*`/`*KEY*`/`*API*`) masked in `list`.
  - Override with `HANIF_ENV_PROFILE` / `HANIF_ENV_FILE` / `HANIF_ENV_SHELL`.
- `render_table` and `kv` helpers in `lib/utils/common.sh` for tabular and aligned key/value output (TTY/`NO_COLOR` aware, cyan box-drawing borders).
- `gitclean` now ends with a polished tabular summary (kept / deleted / protected branches) and a one-line totals line.
- `step`, `hint`, and `print_banner` helpers in `lib/utils/common.sh` for consistent UI across commands.
- TTY / `NO_COLOR` / `HANIF_NO_COLOR` aware color rendering — colors are automatically stripped when output is piped or captured (keeps scripts and tests clean).

### Changed
- `hanif nf` (newfeature) now accepts multi-word descriptions without quotes — `hanif nf add login form` works the same as `hanif nf "add login form"`. Quoted form remains fully supported.
- Refreshed CLI output across the board for a more polished, professional feel:
  - Consistent colored, iconified status lines (`ℹ`, `✓`, `⚠`, `✗`, `→`) via shared logging helpers.
  - Boxed banners on every help screen render in cyan/bold when the terminal supports it.
  - Squash interactive prompts and commit-selection list use color and consistent spacing.
  - Update-available notice uses bold/colored highlights.

## [0.4.0] - 2026-02-14

### Added
- Gitignore command (`hanif gitignore` / `hanif gi`) — add paths to .gitignore and remove from git tracking
- Creates .gitignore if it doesn't exist
- Prevents duplicate entries in .gitignore
- Removes path from git index while keeping files on disk
- Provides feedback and next-step guidance
- Comprehensive test suite for gitignore command

## [0.3.1] - 2026-02-13

### Fixed
- "Update available!" message no longer appears after `hanif self-update` completes
- Install verification (`hanif version` during install) no longer triggers stale update notices

### Changed
- Publish script now automatically stamps CHANGELOG.md with version number and date instead of opening editor manually
- Publish script no longer runs tests twice (skips duplicate test run in build step)

## [0.3.0] - 2026-02-12

### Added
- Bumpversion command (`hanif bv` / `hanif bumpversion`) — semantic version bumping with RC workflow
- Interactive bump mode with preview menu and custom version input
- Direct bump subcommands: `patch`, `minor`, `major`, `rc`, `release`
- Config initialization (`hanif bv init`) with auto-detection of project type (Node.js, Python, Rust, Java, etc.)
- RC (release candidate) workflow: all bumps produce RCs, explicit `release` to promote
- Pre-flight verification of all files before any changes are applied
- Tag conflict detection with interactive resolution (delete, suggest next, abort)
- Git commit and tag automation with push prompts and failure detection
- Automatic commit revert on tag conflict abort to prevent dirty history
- Guards against invalid operations (`rc` on stable, `release` on non-rc)
- Missing config auto-prompts to run `hanif bv init`
- Config header with workflow docs and repo link
- Comprehensive test suite for bumpversion command (61 tests)

## [0.2.2] - 2026-02-11

### Fixed
- Squash command now strips surrounding quotes from custom commit messages
- `hanif amend "message"` now uses the full message instead of only the first word
- `hanif amend "message"` now works even when there are no staged changes (updates commit message only)
- `hanif nf --help` no longer creates a `feature/help` branch; shows help instead
- All git subcommands (`nf`, `up`, `upall`, `clean`, `rb`, `amend`) now handle `--help`/`-h` flags correctly
- Publish script now stages lib files changed by the build step, preventing dirty working directory after release

### Changed
- Updated README with detailed squash command result examples
- Added `hanif amend` command to README documentation
- Help topics now route git subcommands (e.g., `hanif help amend`) to git help page

### Added
- Interactive commit squashing command (`hanif squash [count]`)
- Smart message formatting with commit hash preservation
- Support for custom squash messages
- Root commit squashing capability (auto-detected)
- Re-squashing support (preserves previous formatting)
- Default count of 20 when no count argument is provided
- Comprehensive test suite for squash command (16 tests)

### Fixed
- Squash command no longer squashes all commits when selecting the oldest displayed commit; root rebase only triggers when the selected commit is the actual root commit of the repository

## [0.0.0] - 2026-01-20

### Added
- Initial release
- Extensible CLI framework
- Git helper commands (sync, newfeature, up, upall, clean, rebase)
- JIRA/ticket number extraction in feature branches
- Simple testing framework
- Installation script (direct install via curl)
- Documentation

[0.2.2]: https://github.com/hanif-mianjee/hanif-cli-tools/releases/tag/v0.2.2
[0.0.0]: https://github.com/hanif-mianjee/hanif-cli-tools/releases/tag/v0.0.0

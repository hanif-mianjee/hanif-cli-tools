# Changelog

## [Unreleased]

### Added
- **New command: `hanif pre-commit`** (alias `hanif pc`) — interactive installer for a pure-shell `.git/hooks/pre-commit` script tailored to the project's detected stack(s).
  - Auto-detects Node.js, Python, Rust, Go, Java, Ruby, and PHP via standard marker files (`package.json`, `pyproject.toml`/`setup.py`/`setup.cfg`/`requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`/`build.gradle`, `Gemfile`, `composer.json`).
  - Curated catalog of checks: universal safety nets (`protect-branches`, `no-merge-markers`, `no-large-files`, `no-secrets`, `no-env-files`, `no-trailing-whitespace`, `no-debug`) plus per-stack lint / format / test / typecheck options. Stack-specific checks gracefully skip when their tool isn't installed (e.g. a teammate without `cargo` still commits cleanly).
  - Multi-select picker with keyword shortcuts: `all`, `none`, `universal`, `recommended` (Enter = recommended).
  - Free-form custom commands — add any number of your own shell commands alongside the curated checks; single-quote-safe encoding survives apostrophes.
  - Generated hook is delimited by `# >>> hanif pre-commit: managed >>>` / `# <<< hanif pre-commit: managed <<<` markers. Re-running `hanif pre-commit` rewrites only the managed block; anything you added outside the markers is preserved verbatim. Pre-existing unmanaged hooks are backed up to `pre-commit.bak.<UTC-timestamp>` before being replaced.
  - Failure model in the generated hook: accumulate failures across all checks (no fail-fast) so the user sees every problem on a single run. `HANIF_PRECOMMIT_SKIP=<id1,id2>` at commit time lets you bypass specific checks without `--no-verify`.
  - Subcommands: `hanif pre-commit` (setup), `hanif pre-commit list` (show installed state + selected check IDs + generation timestamp), `hanif pre-commit run` (dry-run the hook against the current staged set), `hanif pre-commit remove` (uninstall — deletes file if purely managed, strips just the managed block if user content exists outside the markers; always writes a timestamped backup).
  - Warns clearly when `git config core.hooksPath` is set elsewhere — the hook is still written to `.git/hooks/pre-commit` (the git-native location), and the user is told how to wire it up.
  - Non-interactive mode for CI / automation: `HANIF_PRE_COMMIT_YES=1`, `HANIF_PRE_COMMIT_CHECKS=<id-list>`, `HANIF_PRE_COMMIT_CUSTOM=<cmds>`.
- **`hanif squash <hash>`**: skip the interactive picker by passing a commit hash directly. Hanif squashes every commit from `<hash>` through `HEAD` into one, with the same custom-message prompt as the picker flow.
- **`hanif squash <older> <newer>`**: squash an inclusive commit range without losing the work that came after it. Hanif squashes `<older>..<newer>` into a single commit, then cherry-picks every commit that was on top of `<newer>` back on. Refuses to run with a dirty working tree, a detached `HEAD`, or when `<older>` is not an ancestor of `<newer>`. Prints the original `HEAD` so you can recover via `git reset --hard <hash>` if anything goes wrong. Pure-digit arguments still mean "count" — backwards compatible with `hanif squash 5`.
- **`hanif nf` branch prefix is now configurable.** Branches no longer have to start with `feature/`:
  - `--prefix <p>` / `-p <p>` sets the prefix for a single run (`hanif nf --prefix hotfix 'OM-9: patch login'` → `hotfix/OM-9_patch_login`).
  - `--no-prefix` creates a bare branch with no prefix at all (`spike_idea`).
  - `HANIF_NF_PREFIX` sets your default for every run — persist it with `hanif env set HANIF_NF_PREFIX bugfix`.
  - Resolution order is flag → `HANIF_NF_PREFIX` → `feature`.
- **`hanif nf` with no arguments now prompts for the description.** Pasting at the prompt is the only input path your shell cannot interfere with, so ticket titles containing backticks, `<`, `>` or `$` arrive exactly as written. Scripted use (no TTY) still shows the usage error as before.

### Fixed
- **`hanif pr`: `Unsupported remote host: ssh.dev.azure.com`.** The SCP-style Azure DevOps remote `git@ssh.dev.azure.com:v3/<org>/<project>/<repo>` — the URL Azure hands out for most organisations — was parsed as an ordinary `owner/repo` host, so the PR URL could never be built. `ssh://` URLs with an explicit port (`ssh://git@ssh.dev.azure.com:22/v3/…`) failed the same way and are fixed too.
- **`hanif nf` no longer glues words together.** Punctuation in a description was deleted rather than treated as a word separator, so a title like ``OM-900: create table `<env>_catalog.my_table` `` produced `..._catalogmy_table...`. Dotted identifiers, common in table and package names, now read correctly as `..._catalog_my_table...`. The 60-character limit is unchanged, but truncation now trims back to the last whole word instead of cutting mid-word.
- **`hanif nf` with a description that sanitizes to nothing** (e.g. `hanif nf '!!!'`) now fails with a clear message instead of asking git to create a branch literally named `feature/`.
- **`hanif nf help me fix the login`** creates a branch again — `help` as the first word of a description no longer opens the help screen. `hanif nf help` on its own still does.
- **`hanif nf`**: free-text descriptions containing shell glob characters (`[`, `]`, `*`, `?`) — common in Jira titles such as `OM-1460: [Data loader] - Loader Failed` — no longer cause a zsh `bad pattern` error. `install.sh` now writes `alias hanif='noglob hanif'` to `.zshrc`, which tells zsh to skip glob expansion for hanif arguments. Existing installs pick up the alias on the next `hanif self-update`. As always, quoting the whole description also works.
- **`hanif squash` no longer stalls where no editor is available** (CI, cron, any non-interactive shell). The rebase used `squash`, which opens a commit-message editor; with no usable editor it left the branch part-way through the rebase, carrying git's own `# This is a combination of N commits.` message instead of the formatted one. It now uses `fixup`, which needs no editor, and the final message is written exactly as before.

## [1.1.1] - 2026-05-11

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

# Contributing

Thanks for your interest! This is a simple, personal CLI tool that's easy to extend.

## Quick Start

```bash
# Fork and clone
git clone https://github.com/hanif-mianjee/hanif-cli-tools.git
cd hanif-cli-tools

# Install locally
bash scripts/dev-install.sh

# Make changes, test
hanif version
bash tests/run-tests.sh
```

## Adding Commands

Commands are **auto-discovered** — `bin/hanif` does not need to change.

1. Create `lib/commands/yourcommand.sh`
2. At the top of the file, register the command:

   ```bash
   register_command --name "yourcommand" --aliases "yc" --group "Other" \
     --handler "yourcommand_handler" \
     --description "Short one-line description"
   ```

3. Define the handler function in the same file. Lazy-load any heavy logic
   from `lib/functions/` inside the handler (so unrelated invocations stay fast):

   ```bash
   yourcommand_handler() {
     # shellcheck source=../functions/your-functions.sh
     source "${FUNCTIONS_DIR}/your-functions.sh"
     run_your_thing "$@"
   }
   ```

4. Add tests in `tests/test-yourcommand.sh` (see `tests/test-registry.sh` for the patterns).
5. Submit a PR.

See `lib/registry.sh` for the full registry API
(`register_command`, `dispatch_command`, `registry_has`).

## Code Style

- Use `set -euo pipefail` in scripts
- Quote variables: `"$var"`
- Use utility functions: `info`, `success`, `error`, `warning`
- Use `snake_case` for functions and variables
- 2 spaces for indentation

## Testing

```bash
# Run all tests
bash tests/run-tests.sh

# Run specific test
bash tests/test-git.sh

# Debug mode
DEBUG=1 bash tests/test-git.sh
```

Add tests for new features in `tests/`.

## Development Workflow

```bash
# Create feature branch (using the tool itself!)
hanif nf "add-new-feature"

# Make changes, test locally
./bin/hanif mycommand
bash tests/run-tests.sh
```

## Pull Requests

- Clear description of changes
- All tests passing (`bash tests/run-tests.sh`)
- One feature per PR
- Use conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`

## Project Structure

```
bin/hanif              # Main CLI entry point (small dispatcher)
lib/
  registry.sh          # Command registry & dispatcher
  commands/            # Command handlers — each self-registers
  functions/           # Core logic, lazy-loaded
  utils/common.sh      # Shared utilities
tests/                 # Test files (run via tests/run-tests.sh)
scripts/               # Build/install scripts
```

## Release Process

```bash
# Automated: bumps version everywhere, runs tests, tags, and publishes
bash scripts/publish.sh
```

## Getting Help

- **Bugs**: Open an [Issue](https://github.com/hanif-mianjee/hanif-cli-tools/issues)
- **Questions**: Open a [Discussion](https://github.com/hanif-mianjee/hanif-cli-tools/discussions)

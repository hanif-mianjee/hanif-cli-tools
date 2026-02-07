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

1. Create `lib/commands/yourcommand.sh`
2. Add handler function
3. Register in `bin/hanif`
4. Write tests in `tests/`
5. Submit PR

## Code Style

- Use `set -euo pipefail` in scripts
- Quote variables: `"$var"`
- Use utility functions: `info`, `success`, `error`, `warning`
- Use `snake_case` for functions and variables
- 2 spaces for indentation

## Testing

```bash
# Run all tests
npm test

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
npm test

# Lint
npm run lint
```

## Pull Requests

- Clear description of changes
- All tests passing (`npm test`)
- One feature per PR
- Use conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`

## Project Structure

```
bin/hanif              # Main CLI entry point
lib/
  commands/            # Command handlers
  functions/           # Core logic
  utils/common.sh      # Shared utilities
tests/                 # Test files
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

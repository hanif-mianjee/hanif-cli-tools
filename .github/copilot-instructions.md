# GitHub Copilot Instructions

These instructions apply to every agent/chat session working in this repository.

## Changelog

- **Always update `CHANGELOG.md`** when making any code change (bug fix, feature, refactor, or breaking change).
- Add entries under the `## [Unreleased]` section at the top of the file. Create the section if it does not exist.
- Use the standard Keep-a-Changelog headings: `### Added`, `### Changed`, `### Fixed`, `### Removed`, `### Security`, `### Deprecated`.
- Write entries in plain English from the user's perspective — what changed and why it matters, not implementation details.
- One bullet per logical change. Sub-bullets are allowed for detail.

## Documentation

- **Always check `README.md`** for any section that describes the modified command or feature, and update it to stay accurate.
- **Always check `docs/index.html`** for any corresponding section (command cards, feature descriptions, tag lists) and update it too.
- If a command's supported inputs, flags, environment variables, or host/provider coverage changes, update all three: `README.md`, `docs/index.html`, and the inline `--help` text in `lib/commands/<cmd>.sh`.
- Do not add docs for things that weren't changed. Keep additions scoped to what actually changed.
- Aways include examples for new commands or parameter change

## Tests

- When fixing a bug, add at least one test that reproduces the bug and confirms the fix.
- Place tests in the appropriate `tests/test-<cmd>.sh` file.
- Use generic dummy values (e.g. `myorg`, `myrepo`, `myproj`) — never real org names, repo names, or credentials.
- Run the relevant test file after changes and confirm all tests pass before committing.

## Commits

- Stage only the files that were changed as part of the task (implementation + tests + CHANGELOG + docs).
- Use the Conventional Commits format: `type(scope): short description`.
  - Common types: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`.
  - Scope is the command name, e.g. `fix(pr): …`, `feat(env): …`.
- The commit body should list the key changes as bullet points (matching the CHANGELOG entry).
- **Never add author or co-author trailers to commits.** No `Co-Authored-By:`, no `Signed-off-by:`,
  no "Generated with …" or other tool-attribution lines, and never pass `--author`. The commit author
  is the repository owner's configured git identity and nothing else.
- Never use `--no-verify` or bypass pre-commit hooks.

# Claude Instructions

`.github/copilot-instructions.md` is the source of truth for how to work in this repository —
**read it before making changes.** It covers the changelog, documentation, test and commit rules
that apply to every agent session. The commit rules are repeated here because they are the easiest
to get wrong.

## Commits

- **Never add author or co-author trailers.** No `Co-Authored-By:`, no `Signed-off-by:`, no
  "Generated with …" or other tool-attribution lines, and never pass `--author`. The commit author
  is the repository owner's configured git identity and nothing else.
- Use Conventional Commits: `type(scope): short description`, where scope is the command name
  (e.g. `fix(pr): …`, `feat(nf): …`).
- Stage only the files that belong to the task (implementation + tests + CHANGELOG + docs).
- Never use `--no-verify` or otherwise bypass pre-commit hooks.

## Before committing

- Update `CHANGELOG.md` under `## [Unreleased]`.
- Update `README.md`, `docs/index.html`, and the inline `--help` text in `lib/commands/<cmd>.sh`
  whenever a command's inputs, flags, or environment variables change.
- Add a regression test in `tests/test-<cmd>.sh` for every bug fix, and run
  `bash tests/run-tests.sh`.

## Testing gotcha

Run the suite with `env -u GIT_EDITOR -u EDITOR bash tests/run-tests.sh` before pushing. An
interactive shell often exports `GIT_EDITOR`, which masks failures in any code path that shells out
to `git rebase`/`git commit` — CI has no editor, so a suite that passes locally can still fail there.

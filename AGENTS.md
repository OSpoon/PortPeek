@/Users/osp/.codex/RTK.md

## Git Commit Message

When creating a git commit, always use Conventional Commits:

```text
<type>: <short description>
```

Allowed types:

- `feat`: new user-facing functionality; triggers a minor release
- `fix`: bug fix; triggers a patch release
- `perf`: performance improvement; triggers a patch release
- `refactor`: internal refactoring; no release by default
- `docs`: documentation-only change; no release
- `test`: tests; no release
- `chore`: maintenance; no release
- `ci`: CI/CD changes; no release

Rules:

- Write the subject in English.
- Keep the subject concise and imperative.
- Do not add a period at the end.
- Use `feat!:` or `BREAKING CHANGE:` only for breaking changes.
- Inspect the diff before committing and summarize the actual change.
- Do not create a commit unless the user explicitly asks for one.

Examples:

- `feat: group listening ports by process`
- `fix: exclude system-level processes`
- `perf: cache process details by PID`
- `docs: update PortPeek introduction`
- `ci: automate PortPeek releases`

---
name: mbpr
description: Make branch and PR for current changes — creates a feature branch from current changes, commits, pushes, and opens a GitHub PR.
user_invocable: true
---

# MBPR — Make Branch and PR

Create a feature branch from the current changes, commit them, push, and open a pull request.

## Steps

1. Run `git status` and `git diff` to see all staged and unstaged changes.
2. Run `git log --oneline -5` to match the repo's commit message style.
3. Run `.claude/skills/run-smoke/smoke.sh prod` to verify the build passes before committing. If it fails, fix the issues first.
4. Ask the user for a branch name if not obvious from the changes, or suggest one based on the diff.
5. Create and switch to a new branch: `git checkout -b <branch-name>`
6. Stage all relevant changed files (avoid secrets, .env files, credentials).
7. Commit with a concise message summarizing the changes.
8. Push the branch: `git push -u origin <branch-name>`
9. Create a PR with `gh pr create` using a short title and a body with a Summary section and Test Plan section.
10. Return the PR URL to the user.
11. After the PR is created, start a `/loop` that polls every 2 minutes (`gh pr view <PR-NUMBER> --json state,mergedAt`) to check whether the PR has been merged.
12. When the PR is merged:
    - Stash any uncommitted changes: `git stash -u`
    - Switch to main: `git checkout main`
    - Pull latest: `git pull`
    - Pop the stash: `git stash pop`
    - Ask the user if they want to delete the local and remote feature branch. If yes, run `git branch -d <branch-name>` and `git push origin --delete <branch-name>`.

#!/usr/bin/env bash
set -e
git init
git add -A
git commit -m "scaffold: BloodLine project plan and agent workflow"
git branch -M main
echo "Done. For parallel agents:"
echo "  git worktree add ../bloodline-api -b feat/api"
echo "  git worktree add ../bloodline-app -b feat/app"

#!/usr/bin/env bash
# Clones missing review repos and parks each one on its up-to-date base branch.
# Fetches only the base branch: a refspec-less fetch negotiates thousands of refs on the big repos.
set -uo pipefail

review_root="${REVIEW_DIR:-$HOME/review}"

if [ "$#" -eq 0 ]; then
  echo "usage: sync-repos.sh <repo> [<repo> ...]" >&2
  exit 1
fi

for repo_name in "$@"; do
  repo_dir="$review_root/$repo_name"

  if [ ! -d "$repo_dir/.git" ]; then
    if ! gh repo clone "bounceinsights/$repo_name" "$repo_dir" -- --filter=blob:none -q 2>/dev/null; then
      echo "MISSING: $repo_name (clone failed: no access or no such repo)"
      continue
    fi
  fi

  base_branch=$(git -C "$repo_dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
  if [ -z "$base_branch" ]; then
    for candidate_branch in master main; do
      if git -C "$repo_dir" rev-parse -q --verify "refs/remotes/origin/$candidate_branch" >/dev/null; then
        base_branch=$candidate_branch
        break
      fi
    done
  fi
  if [ -z "$base_branch" ]; then
    echo "NO-BASE: $repo_name (cannot diff or grep safely, skipped)"
    continue
  fi

  timeout_prefix=""
  if command -v timeout >/dev/null; then
    timeout_prefix="timeout 120"
  fi
  $timeout_prefix git -C "$repo_dir" fetch -q --no-tags origin \
    "refs/heads/$base_branch:refs/remotes/origin/$base_branch" \
    || echo "FETCH-FAILED: $repo_name (base may be stale)"

  current_branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)
  if [ "$current_branch" != "$base_branch" ]; then
    if git -C "$repo_dir" checkout -q -f "$base_branch" 2>/dev/null; then
      current_branch=$base_branch
    else
      echo "STUCK: $repo_name on $current_branch (checkout $base_branch failed, do not grep it)"
      continue
    fi
  fi

  if ! git -C "$repo_dir" reset -q --hard "origin/$base_branch" 2>/dev/null; then
    echo "BEHIND: $repo_name (could not move $base_branch to origin/$base_branch, code may be stale)"
  fi

  echo "$repo_name base=$base_branch head=$(git -C "$repo_dir" rev-parse --short HEAD)"
done

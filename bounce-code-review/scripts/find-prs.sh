#!/usr/bin/env bash
# Prints one JSON object per open bounceinsights PR that requests my review or that I authored.
set -euo pipefail

search_fields="repository,number,title,author,isDraft,url,updatedAt"

search_prs() {
  local filter_flag="$1"
  local reason="$2"
  gh search prs --owner bounceinsights --state open "$filter_flag" --limit 100 \
    --json "$search_fields" \
    --jq ".[] | {repo: .repository.name, number, title, author: .author.login, isDraft, url, updatedAt, reason: \"$reason\"}"
}

{
  search_prs "--review-requested=@me" "requested"
  search_prs "--author=@me" "mine"
} | jq -s -c 'unique_by(.url) | sort_by(.repo, .number) | .[]'

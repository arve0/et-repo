#!/usr/bin/env bash
set -eo pipefail

POLL_INTERVAL="${POLL_INTERVAL:-2}"
MAX_OUTPUT="${MAX_OUTPUT:-60000}"
export GITHUB_TOKEN="${GITHUB_TOKEN:-}"

GIST_ID=""
GIST_URL=""
OWNER=""
LAST_COMMENT_ID=0

main() {
  init
  while true; do
    hent_neste_kommentar
    sleep "$POLL_INTERVAL"
  done
}

init() {
  if ! command -v gh &>/dev/null; then
    echo "Feil: 'gh' (GitHub CLI) er ikke installert." >&2
    exit 1
  fi

  if ! gh auth status &>/dev/null; then
    echo "Feil: 'gh' er ikke autentisert. Kjør 'gh auth login' først." >&2
    exit 1
  fi

  OWNER=$(gh api user --jq .login)

  local tmpfile
  tmpfile=$(mktemp)
  echo "# Kommandosenter" > "$tmpfile"
  echo "Send kommandoer som kommentarer på formatet: \`run: <kommando>\`" >> "$tmpfile"

  GIST_URL=$(gh gist create --public --desc "kommandosenter" --filename "kommandosenter.md" "$tmpfile")
  rm -f "$tmpfile"

  GIST_ID=$(basename "$GIST_URL")

  echo "Kommandosenter er klart!"
  echo "Gist URL: $GIST_URL"
  echo "Send kommandoer som kommentarer: run: <kommando>"
}

hent_neste_kommentar() {
  local kommentarer
  kommentarer=$(gh api "gists/$GIST_ID/comments" --jq '.[]')

  while IFS= read -r linje; do
    [[ -z "$linje" ]] && continue

    local id bruker kropp
    id=$(echo "$linje" | jq -r '.id')
    bruker=$(echo "$linje" | jq -r '.user.login')
    kropp=$(echo "$linje" | jq -r '.body')

    if [[ "$id" -le "$LAST_COMMENT_ID" ]]; then
      continue
    fi

    LAST_COMMENT_ID="$id"

    if [[ "$bruker" != "$OWNER" ]]; then
      continue
    fi

    local cmd
    cmd=$(echo "$kropp" | sed -En 's/^[[:space:]]*[Rr][Uu][Nn]:[[:space:]]*(.*)/\1/p')
    if [[ -n "$cmd" ]]; then
      prosseser_kommentar "$cmd"
    fi
  done <<< "$kommentarer"
}

prosseser_kommentar() {
  local cmd="$1"
  local output exit_code

  echo "Kjører: $cmd"

  output=$(eval "$cmd" 2>&1) && exit_code=0 || exit_code=$?

  if [[ ${#output} -gt $MAX_OUTPUT ]]; then
    output="${output:0:$MAX_OUTPUT}"$'\n[... output avkortet ...]'
  fi

  post_resultat "$cmd" "$output" "$exit_code"
}

post_resultat() {
  local cmd="$1"
  local output="$2"
  local exit_code="$3"

  local body
  body=$(printf '**$ %s**\n```\n%s\n```\nExit code: %d' "$cmd" "$output" "$exit_code")

  gh api "gists/$GIST_ID/comments" -f body="$body" >/dev/null
  echo "Resultat postet (exit code: $exit_code)"
}

shutdown() {
  echo ""
  echo "Avslutter kommandosenter..."
  if [[ -n "$GIST_ID" ]]; then
    gh api "gists/$GIST_ID/comments" -f body="🛑 Kommandosenteret er avsluttet." >/dev/null 2>&1 || true
  fi
  exit 0
}
trap shutdown SIGINT SIGTERM

main "$@"

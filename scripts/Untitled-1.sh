#!/usr/bin/env bash
set -euo pipefail

# Deletes transactions by account_id from Diruzorro API.
# Default mode is dry-run (no deletion).

BASE_URL="${BASE_URL:-http://diruzorro.basator.com}"
API_PREFIX="/api/v1"
ACCOUNT_ID="5"
DRY_RUN=true
ASSUME_YES=false

usage() {
  cat <<'USAGE'
Usage: ./Untitled-1.sh --account-id <id> [options]

Options:
  --account-id <id>   Account ID whose transactions will be deleted (required)
  --base-url <url>    API base URL (default: http://diruzorro.basator.com)
  --execute           Perform deletion (default is dry-run)
  --yes               Skip confirmation prompt (only with --execute)
  -h, --help          Show this help

Environment variables:
  API_KEY             If set, sent as X-API-Key header

Examples:
  ./Untitled-1.sh --account-id 1
  ./Untitled-1.sh --account-id 1 --execute
  API_KEY=secret ./Untitled-1.sh --account-id 1 --execute --yes
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found." >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account-id)
      ACCOUNT_ID="${2:-}"
      shift 2
      ;;
    --base-url)
      BASE_URL="${2:-}"
      shift 2
      ;;
    --execute)
      DRY_RUN=false
      shift
      ;;
    --yes)
      ASSUME_YES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option '$1'" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$ACCOUNT_ID" ]]; then
  echo "Error: --account-id is required." >&2
  usage
  exit 1
fi

if ! [[ "$ACCOUNT_ID" =~ ^[0-9]+$ ]]; then
  echo "Error: --account-id must be a positive integer." >&2
  exit 1
fi

require_cmd curl
require_cmd jq

TRANSACTIONS_URL="${BASE_URL%/}${API_PREFIX}/transactions"
HEADER_ARGS=()
if [[ -n "${API_KEY:-}" ]]; then
  HEADER_ARGS=(-H "X-API-Key: ${API_KEY}")
fi

echo "Fetching transactions from: $TRANSACTIONS_URL"
response="$(curl -fsS "${HEADER_ARGS[@]}" "$TRANSACTIONS_URL")"

mapfile -t tx_ids < <(jq -r --argjson aid "$ACCOUNT_ID" '.[] | select(.account_id == $aid) | .id' <<< "$response")

echo "Found ${#tx_ids[@]} transactions for account_id=$ACCOUNT_ID"
if [[ ${#tx_ids[@]} -eq 0 ]]; then
  exit 0
fi

if [[ "$DRY_RUN" == true ]]; then
  echo "Dry-run mode. IDs that would be deleted:"
  printf '%s\n' "${tx_ids[@]}"
  echo "Run again with --execute to delete."
  exit 0
fi

if [[ "$ASSUME_YES" == false ]]; then
  read -r -p "Delete ${#tx_ids[@]} transactions for account_id=$ACCOUNT_ID? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

deleted=0
failed=0
for tx_id in "${tx_ids[@]}"; do
  delete_url="${TRANSACTIONS_URL}/${tx_id}"
  if curl -fsS -X DELETE "${HEADER_ARGS[@]}" "$delete_url" >/dev/null; then
    ((deleted+=1))
    echo "Deleted transaction id=$tx_id"
  else
    ((failed+=1))
    echo "Failed to delete transaction id=$tx_id" >&2
  fi
done

echo "Done. deleted=$deleted failed=$failed"
if [[ $failed -gt 0 ]]; then
  exit 1
fi

#!/usr/bin/env bash
# Export monthly enterprise AI credit usage grouped by user and model.
# Usage: get-copilot-ai-credit-usage-by-user-and-model.sh <enterprise> [year] [month] [output.csv] [max-users]
# Requires authenticated gh access to Copilot metrics and billing plus jq and curl.
set -euo pipefail

usage() {
  echo "Usage: $0 <enterprise> [year] [month] [output.csv] [max-users]" >&2
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

api() {
  local error_file output
  error_file=$(mktemp)
  TEMP_FILES+=("$error_file")

  if ! output=$(gh api "$@" 2>"$error_file"); then
    cat "$error_file" >&2
    if grep -q "HTTP 404" "$error_file"; then
      cat >&2 <<'EOF'

The API returned 404. Confirm the enterprise slug and credential access.
For classic PAT authentication, try:
  gh auth refresh -s read:enterprise -s manage_billing:copilot

The metrics API also requires the enterprise Copilot usage metrics policy.
The enterprise AI credit endpoint may require an enterprise owner or billing
manager using a classic PAT.
EOF
    fi
    return 1
  fi

  printf '%s' "$output"
}

days_in_month() {
  case "$1" in
    1|3|5|7|8|10|12) echo 31 ;;
    4|6|9|11) echo 30 ;;
    2)
      if (( YEAR % 400 == 0 || (YEAR % 4 == 0 && YEAR % 100 != 0) )); then
        echo 29
      else
        echo 28
      fi
      ;;
    *) fail "Month must be between 1 and 12." ;;
  esac
}

[[ $# -ge 1 && $# -le 5 ]] || { usage; exit 1; }
for command_name in gh jq curl; do
  command -v "$command_name" >/dev/null 2>&1 ||
    fail "Required command not found: $command_name"
done
gh auth status >/dev/null 2>&1 ||
  fail "GitHub CLI is not authenticated. Run: gh auth login"

ENTERPRISE="$1"
YEAR="${2:-$(date +%Y)}"
MONTH=$((10#${3:-$(date +%m)}))
[[ "$YEAR" =~ ^[0-9]{4}$ ]] || fail "Year must use YYYY format."

MONTH_PADDED=$(printf '%02d' "$MONTH")
OUTPUT="${4:-${ENTERPRISE}-copilot-ai-credit-usage-${YEAR}-${MONTH_PADDED}.csv}"
MAX_USERS="${5:-0}"
[[ "$MAX_USERS" =~ ^[0-9]+$ ]] || fail "Max users must be a non-negative integer."

ACTIVE_USERS=$(mktemp)
TEMP_FILES=("$ACTIVE_USERS")
trap 'rm -f "${TEMP_FILES[@]}"' EXIT

LAST_DAY=$(days_in_month "$MONTH")
echo "Finding users with AI-credit usage in $YEAR-$MONTH_PADDED..." >&2

for ((day = 1; day <= LAST_DAY; day++)); do
  report_date=$(printf '%04d-%02d-%02d' "$YEAR" "$MONTH" "$day")
  echo "Reading $report_date..." >&2
  api -H "X-GitHub-Api-Version: 2026-03-10" \
    "/enterprises/$ENTERPRISE/copilot/metrics/reports/users-1-day?day=$report_date" |
  jq -r 'if type == "object" then (.download_links // [])[] else empty end' |
  while IFS= read -r url; do
    [[ -n "$url" ]] || continue
    curl -fsSL "$url" |
      jq -r 'select(type == "object" and (.ai_credits_used // 0) > 0) | .user_login'
  done
done | sort -u >"$ACTIVE_USERS"

user_count=$(wc -l <"$ACTIVE_USERS" | tr -d ' ')
if (( MAX_USERS > 0 && user_count > MAX_USERS )); then
  head -n "$MAX_USERS" "$ACTIVE_USERS" >"${ACTIVE_USERS}.limited"
  mv "${ACTIVE_USERS}.limited" "$ACTIVE_USERS"
  user_count="$MAX_USERS"
fi

echo "Found $user_count users. This next phase makes one billing API call per user." >&2
if (( user_count > 1000 )); then
  echo "Warning: this may approach the 5,000 requests/hour classic PAT limit." >&2
fi

{
  echo '"user","model","gross_ai_credits","included_ai_credits","net_ai_credits","gross_amount","net_spend"'
  while IFS= read -r login; do
    [[ -n "$login" ]] || continue
    echo "Processing $login..." >&2
    api --method GET -H "X-GitHub-Api-Version: 2026-03-10" \
      "/enterprises/$ENTERPRISE/settings/billing/ai_credit/usage" \
      -f year="$YEAR" -f month="$MONTH" -f user="$login" |
    jq -r --arg user "$login" '
      .usageItems
      | select(type == "array" and length > 0)
      | group_by(.model)[]
      | [
          $user,
          .[0].model,
          (map(.grossQuantity) | add),
          (map(.discountQuantity) | add),
          (map(.netQuantity) | add),
          (map(.grossAmount) | add),
          (map(.netAmount) | add)
        ]
      | @csv
    '
  done <"$ACTIVE_USERS"
} >"$OUTPUT"

echo "Created $OUTPUT" >&2

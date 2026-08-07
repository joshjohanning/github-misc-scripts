#!/usr/bin/env bash
# Generate monthly enterprise Copilot usage as a weekly CSV and standalone HTML report.
# Usage: copilot-enterprise-usage-report.sh <enterprise> [year] [month] [output-prefix]
# Requires authenticated gh access to enterprise Copilot metrics plus jq, curl, and base64.
set -euo pipefail

usage() {
  echo "Usage: $0 <enterprise> [year] [month] [output-prefix]" >&2
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

api() {
  local error_file output
  error_file=$(mktemp)
  TEMP_FILES+=("$error_file")

  if ! output=$(gh api "$@" 2>"$error_file"); then
    cat "$error_file" >&2
    if grep -q "HTTP 404" "$error_file"; then
      cat >&2 <<'EOF'

The API returned 404. Confirm:
- The enterprise slug is correct.
- Copilot usage metrics are enabled in enterprise AI Controls.
- Your credential is an enterprise owner, billing manager, or has the
  "View Enterprise Copilot Metrics" permission.
- A classic PAT has read:enterprise or manage_billing:copilot.

For a classic PAT authenticated through gh:
  gh auth refresh -s read:enterprise -s manage_billing:copilot
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

[[ $# -ge 1 && $# -le 4 ]] || { usage; exit 1; }

for command_name in gh jq curl base64; do
  require_command "$command_name"
done

gh auth status >/dev/null 2>&1 ||
  fail "GitHub CLI is not authenticated. Run: gh auth login"

ENTERPRISE="$1"
YEAR="${2:-$(date +%Y)}"
MONTH=$((10#${3:-$(date +%m)}))
[[ "$YEAR" =~ ^[0-9]{4}$ ]] || fail "Year must use YYYY format."

MONTH_PADDED=$(printf '%02d' "$MONTH")
PREFIX="${4:-${ENTERPRISE}-copilot-usage-${YEAR}-${MONTH_PADDED}}"
WEEKLY_OUTPUT="${PREFIX}-weekly.csv"
HTML_OUTPUT="${PREFIX}.html"
RAW_ROWS=$(mktemp)
TEMP_FILES=("$RAW_ROWS")

cleanup() {
  rm -f "${TEMP_FILES[@]}"
}
trap cleanup EXIT

LAST_DAY=$(days_in_month "$MONTH")

echo "Downloading $ENTERPRISE Copilot metrics for $YEAR-$MONTH_PADDED..." >&2

for ((day = 1; day <= LAST_DAY; day++)); do
  report_date=$(printf '%04d-%02d-%02d' "$YEAR" "$MONTH" "$day")
  echo "Reading $report_date..." >&2

  api -H "X-GitHub-Api-Version: 2026-03-10" \
    "/enterprises/$ENTERPRISE/copilot/metrics/reports/enterprise-1-day?day=$report_date" |
  jq -r 'if type == "object" then (.download_links // [])[] else empty end' |
  while IFS= read -r url; do
    [[ -n "$url" ]] || continue
    curl -fsSL "$url" |
      jq -c '
        select(type == "object") as $r
        | (
            $r.totals_by_ide[]?
            | {
                day: $r.day, surface: .ide, kind: "ide",
                interactions: (.user_initiated_interaction_count // 0),
                generations: (.code_generation_activity_count // 0),
                acceptances: (.code_acceptance_activity_count // 0),
                requests: 0, outcomes: 0, outcome_label: "",
                loc_suggested: (.loc_suggested_to_add_sum // 0),
                loc_added: (.loc_added_sum // 0)
              }
          ),
          (
            select(($r.totals_by_cli? | type) == "object")
            | {
                day: $r.day, surface: "copilot_cli", kind: "surface",
                interactions: ($r.totals_by_cli.prompt_count // 0),
                generations: 0, acceptances: 0,
                requests: ($r.totals_by_cli.request_count // 0),
                outcomes: 0, outcome_label: "", loc_suggested: 0, loc_added: 0
              }
          ),
          (
            select(($r.totals_by_copilot_app? | type) == "object")
            | {
                day: $r.day, surface: "copilot_app", kind: "surface",
                interactions: ($r.totals_by_copilot_app.prompt_count // 0),
                generations: 0, acceptances: 0,
                requests: ($r.totals_by_copilot_app.request_count // 0),
                outcomes: 0, outcome_label: "", loc_suggested: 0, loc_added: 0
              }
          ),
          (
            select(($r.pull_requests.total_created_by_copilot // 0) > 0)
            | {
                day: $r.day, surface: "copilot_coding_agent", kind: "surface",
                interactions: 0, generations: 0, acceptances: 0, requests: 0,
                outcomes: ($r.pull_requests.total_created_by_copilot // 0),
                outcome_label: "Copilot-created PRs", loc_suggested: 0, loc_added: 0
              }
          ),
          (
            select(($r.pull_requests.total_reviewed_by_copilot // 0) > 0)
            | {
                day: $r.day, surface: "copilot_code_review", kind: "surface",
                interactions: 0, generations: 0, acceptances: 0, requests: 0,
                outcomes: ($r.pull_requests.total_reviewed_by_copilot // 0),
                outcome_label: "Copilot-reviewed PRs", loc_suggested: 0, loc_added: 0
              }
          )
      ' >>"$RAW_ROWS"
  done
done

jq -rs '
  def week_start:
    (.day + "T00:00:00Z" | fromdateiso8601) as $ts
    | ($ts | strftime("%w") | tonumber) as $weekday
    | ($ts - ($weekday * 86400) | strftime("%Y-%m-%d"));
  map(. + {week_start: week_start})
  | sort_by(.week_start, .surface)
  | group_by([.week_start, .surface])
  | map({
      week_start: .[0].week_start,
      surface: .[0].surface,
      surface_type: .[0].kind,
      interactions: (map(.interactions) | add),
      generations: (map(.generations) | add),
      requests: (map(.requests) | add),
      outcomes: (map(.outcomes) | add),
      outcome_label: (map(.outcome_label) | map(select(length > 0)) | first // "")
    })
  | (
      ["week_start","surface","surface_type","interactions","generations","requests","outcomes","outcome_label"],
      (.[] | [.week_start,.surface,.surface_type,.interactions,.generations,.requests,.outcomes,.outcome_label])
    )
  | @csv
' "$RAW_ROWS" >"$WEEKLY_OUTPUT"

CSV_BASE64=$(base64 <"$WEEKLY_OUTPUT" | tr -d '\n')
cat >"$HTML_OUTPUT" <<EOF
<!doctype html>
<meta charset="utf-8">
<title>${ENTERPRISE} Copilot usage ${YEAR}-${MONTH_PADDED}</title>
<style>
body{margin:0;padding:28px;background:#f6f8fa;color:#1f2328;font:14px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
main{max-width:1180px;margin:auto}.panel{background:#fff;border:1px solid #d0d7de;border-radius:14px;padding:26px 30px;margin-bottom:18px;box-shadow:0 8px 24px #8c959f24}
h1,h2{margin:0 0 6px}p{color:#656d76;margin:0 0 18px}.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}.card{border:1px solid #d0d7de;border-radius:10px;padding:16px}
.card strong{font-size:28px;display:block}.card span{color:#656d76}svg{width:100%;height:auto}.legend{display:flex;flex-wrap:wrap;gap:14px;margin:10px 0}.dot{width:10px;height:10px;border-radius:50%;display:inline-block;margin-right:5px}
table{width:100%;border-collapse:collapse}th,td{padding:9px;border-bottom:1px solid #d0d7de;text-align:right}th:first-child,td:first-child{text-align:left}.note{background:#ddf4ff;border:1px solid #54aeff;border-radius:8px;padding:12px;margin-top:14px}
</style>
<main>
<section class="panel"><h1>${ENTERPRISE} Copilot usage</h1><p>${YEAR}-${MONTH_PADDED}, generated from enterprise daily usage metrics</p><div class="cards"><div class="card"><strong id="interactions">0</strong><span>Interactions</span></div><div class="card"><strong id="requests">0</strong><span>Reported requests</span></div><div class="card"><strong id="outcomes">0</strong><span>Agent outcomes</span></div></div></section>
<section class="panel"><h2>Weekly interactions</h2><div id="legend" class="legend"></div><svg id="chart" viewBox="0 0 1120 420"></svg><div class="note">Interactions are user-initiated prompts. CLI and Copilot App request counts include agentic follow-up calls. CCA and CCR are reported as pull request outcomes.</div></section>
<section class="panel"><h2>Surface summary</h2><table><thead><tr><th>Surface</th><th>Interactions</th><th>Generations</th><th>Requests</th><th>Outcomes</th></tr></thead><tbody id="summary"></tbody></table></section>
</main>
<script>
const csv=atob("$CSV_BASE64"),lines=csv.trim().split(/\\r?\\n/),head=parse(lines.shift()),rows=lines.map(x=>Object.fromEntries(head.map((h,i)=>[h,parse(x)[i]])));
function parse(s){return s.match(/(".*?"|[^",]+)(?=\\s*,|\\s*$)/g).map(v=>v.replace(/^"|"$/g,""))}
const colors=["#0969da","#8250df","#1a7f37","#cf222e","#bc4c00","#bf3989","#007c83","#57606a"],weeks=[...new Set(rows.map(r=>r.week_start))].sort(),surfaces=[...new Set(rows.filter(r=>+r.interactions>0).map(r=>r.surface))].sort();
const totals=f=>rows.reduce((n,r)=>n+(+r[f]||0),0); interactions.textContent=totals("interactions").toLocaleString();requests.textContent=totals("requests").toLocaleString();outcomes.textContent=totals("outcomes").toLocaleString();
const left=70,right=1080,top=25,bottom=360,max=Math.max(1,...rows.map(r=>+r.interactions||0)),cap=Math.ceil(max/100)*100,x=i=>left+i*(right-left)/Math.max(1,weeks.length-1),y=v=>bottom-v/cap*(bottom-top);
let svg="";for(let i=0;i<=5;i++){let v=cap*i/5,p=y(v);svg+=\`<line x1="\${left}" y1="\${p}" x2="\${right}" y2="\${p}" stroke="#d8dee4"/><text x="\${left-10}" y="\${p+4}" text-anchor="end" fill="#656d76">\${Math.round(v).toLocaleString()}</text>\`}weeks.forEach((w,i)=>svg+=\`<text x="\${x(i)}" y="390" text-anchor="middle" fill="#656d76">\${w}</text>\`);
surfaces.forEach((s,si)=>{let c=colors[si%colors.length],pts=weeks.map((w,i)=>{let r=rows.find(r=>r.week_start===w&&r.surface===s);return \`\${x(i)},\${y(r?+r.interactions:0)}\`}).join(" ");svg+=\`<polyline points="\${pts}" fill="none" stroke="\${c}" stroke-width="4"/>\`;legend.innerHTML+=\`<span><i class="dot" style="background:\${c}"></i>\${s.replaceAll("_"," ")}</span>\`});chart.innerHTML=svg;
const grouped=Object.values(rows.reduce((a,r)=>{let x=a[r.surface]||={surface:r.surface,interactions:0,generations:0,requests:0,outcomes:0};["interactions","generations","requests","outcomes"].forEach(k=>x[k]+=+r[k]||0);a[r.surface]=x;return a},{})).sort((a,b)=>b.interactions-a.interactions);
summary.innerHTML=grouped.map(r=>\`<tr><td>\${r.surface.replaceAll("_"," ")}</td><td>\${r.interactions.toLocaleString()}</td><td>\${r.generations.toLocaleString()}</td><td>\${r.requests.toLocaleString()}</td><td>\${r.outcomes.toLocaleString()}</td></tr>\`).join("");
</script>
EOF

echo "Created $WEEKLY_OUTPUT" >&2
echo "Created $HTML_OUTPUT" >&2

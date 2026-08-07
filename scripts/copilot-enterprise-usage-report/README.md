# copilot-enterprise-usage-report

Generate monthly GitHub Copilot enterprise usage reports from the current
`enterprise-1-day` Usage Metrics API.

## Outputs

- Weekly surface activity CSV
- Standalone HTML report with embedded data

The report distinguishes unlike metrics instead of treating them as equivalent:

- IDEs expose user-initiated interactions and generation activity
- Copilot CLI and Copilot App expose prompt and request counts
- Copilot Coding Agent exposes Copilot-created pull requests
- Copilot Code Review exposes Copilot-reviewed pull requests

## Prerequisites

- An authenticated GitHub CLI session: `gh auth status`
- `jq`, `curl`, and `base64`
- Enterprise access to Copilot usage metrics

Classic PATs need `read:enterprise` or `manage_billing:copilot`. Fine-grained
credentials need the **View Enterprise Copilot Metrics** permission. The
enterprise **Copilot usage metrics** policy must also be enabled.

## Usage

```shell
./copilot-enterprise-usage-report.sh <enterprise> [year] [month] [output-prefix]
```

Example:

```shell
./copilot-enterprise-usage-report.sh avocado-corp 2026 7
```

This creates:

```text
avocado-corp-copilot-usage-2026-07-weekly.csv
avocado-corp-copilot-usage-2026-07.html
```

The API provides up to one year of daily history beginning October 10, 2025.
Recent data can take several UTC days to finalize.

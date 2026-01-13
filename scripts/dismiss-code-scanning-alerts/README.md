# dismiss-code-scanning-alerts

Dismiss code scanning alerts by rule ID across repositories in a GitHub organization.

## Prerequisites

- Node.js 18+
- GitHub token with `security_events` scope (for private repos) or `public_repo` scope (for public repos)
- Or GitHub App with Code scanning alerts (write) permission

## Installation

```bash
cd scripts/dismiss-code-scanning-alerts
npm install
```

## Authentication

### Using a Personal Access Token (PAT)

```bash
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

Required scopes:
- `security_events` - For private and public repositories
- `public_repo` - For public repositories only

### Using a GitHub App

```bash
export GITHUB_APP_ID=123456
export GITHUB_APP_PRIVATE_KEY_PATH=/path/to/private-key.pem
```

**Required GitHub App Permissions:**

Repository permissions:

| Permission | Access | Required For |
|------------|--------|--------------|
| Code scanning alerts | Write | Dismissing code scanning alerts |
| Contents | Read | Listing repositories |
| Metadata | Read | Repository information (automatically added) |

Organization permissions:

| Permission | Access | Required For |
|------------|--------|--------------|
| Administration | Read | Listing all repositories in the organization |

**Note:** The app must be installed on the organization with access to the repositories you want to process (either "All repositories" or selected repositories).

## Usage

```bash
node dismiss-code-scanning-alerts.js <organization> --rule <rule-id> --reason <reason> [options]
node dismiss-code-scanning-alerts.js --orgs-file <file> --rule <rule-id> --reason <reason> [options]
```

### Required Options

| Option | Description |
|--------|-------------|
| `--rule <rule-id>` | CodeQL rule ID to match (e.g., `js/stack-trace-exposure`, `py/sql-injection`) |
| `--reason <reason>` | Dismissal reason: `"false positive"`, `"won't fix"`, or `"used in tests"` |

### Optional Options

| Option | Description |
|--------|-------------|
| `--orgs-file <file>` | File containing list of organizations (one per line) |
| `--repo <repo>` | Target a single repository instead of all repos |
| `--comment <comment>` | Optional dismissal comment |
| `--output <file>` | Write CSV report of dismissed alerts to file |
| `--dry-run` | Preview what would be dismissed without making changes |
| `--concurrency <n>` | Number of concurrent API calls (default: 10) |
| `--help` | Show help message |

## Examples

### Dismiss alerts for a single repository

```bash
node dismiss-code-scanning-alerts.js my-org --repo my-repo --rule "js/stack-trace-exposure" --reason "won't fix"
```

### Dismiss alerts across all repos in an organization

```bash
node dismiss-code-scanning-alerts.js my-org --rule "js/stack-trace-exposure" --reason "false positive"
```

### Dismiss alerts with a comment

```bash
node dismiss-code-scanning-alerts.js my-org --rule "js/stack-trace-exposure" --reason "won't fix" --comment "This is expected behavior in our error handling"
```

### Preview what would be dismissed (dry run)

```bash
node dismiss-code-scanning-alerts.js my-org --rule "js/stack-trace-exposure" --reason "won't fix" --dry-run
```

### Process multiple organizations from a file

```bash
node dismiss-code-scanning-alerts.js --orgs-file orgs.txt --rule "py/sql-injection" --reason "used in tests" --output dismissed.csv
```

### Generate a report of dismissed alerts

```bash
node dismiss-code-scanning-alerts.js my-org --rule "js/stack-trace-exposure" --reason "won't fix" --output dismissed.csv
```

## Output

When using `--output`, the script generates a CSV report with the following columns:

| Column | Description |
|--------|-------------|
| Organization | GitHub organization name |
| Repository | Repository name |
| Alert Number | Code scanning alert number |
| Rule ID | CodeQL rule ID that triggered the alert |
| Severity | Alert severity (critical, high, medium, low) |
| Path | File path where the alert was found |
| URL | Link to the alert on GitHub |
| Status | Result of the dismiss operation |

## Dismissal Reasons

The GitHub API accepts three dismissal reasons:

| Reason | When to Use |
|--------|-------------|
| `"false positive"` | The alert is incorrect - the code doesn't actually have this vulnerability |
| `"won't fix"` | The vulnerability is acknowledged but won't be fixed (risk accepted) |
| `"used in tests"` | The vulnerable code is only used in tests and not in production |

## Finding Rule IDs

Rule IDs can be found:

1. In the URL of a code scanning alert: `github.com/org/repo/security/code-scanning/123` → click on an alert to see the rule ID
2. In the alert details panel on GitHub
3. Common CodeQL rule IDs:
   - `js/stack-trace-exposure`
   - `js/sql-injection`
   - `py/sql-injection`
   - `java/sql-injection`
   - `go/sql-injection`
   - `rb/sql-injection`

## Notes

- The script only processes open alerts
- Archived repositories are skipped
- Repositories without code scanning enabled are skipped
- Use `--dry-run` to preview changes before making them
- Rate limiting is handled automatically with retries

# add-codeowners-to-repositories

Adds a CODEOWNERS file to the default branch in a list of repositories.

## Prerequisites

- Node.js 18+
- `GITHUB_TOKEN` environment variable with `repo` scope

## Installation

```bash
npm install
```

## Usage

```bash
node add-codeowners-to-repositories.js --repos-file <file> --codeowners <file> [options]
```

### Options

| Option | Description |
|--------|-------------|
| `--repos-file <file>` | File containing list of repositories (org/repo format, one per line) |
| `--codeowners <file>` | Path to the CODEOWNERS file to add |
| `--overwrite` | Overwrite existing CODEOWNERS file (default: append) |
| `--dry-run` | Show what would be done without making changes |
| `--concurrency <n>` | Number of concurrent API calls (default: 10) |
| `--help` | Show help message |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `GITHUB_TOKEN` | GitHub PAT with `repo` scope (required) |
| `GITHUB_API_URL` | API endpoint (defaults to `https://api.github.com`) |

## Input File Format

The repos file should contain one repository per line in `org/repo` format:

```
my-org/repo-1
my-org/repo-2
other-org/repo-3
```

Lines starting with `#` are treated as comments and ignored. Empty lines are also ignored.

## Behavior

- Checks for existing CODEOWNERS in: `CODEOWNERS`, `.github/CODEOWNERS`, `docs/CODEOWNERS`
- By default, appends new content to existing CODEOWNERS file
- With `--overwrite`, replaces the entire CODEOWNERS file
- Creates CODEOWNERS in the root if it doesn't exist

## Examples

Add CODEOWNERS (append mode):

```bash
node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS
```

Add CODEOWNERS (overwrite mode):

```bash
node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS --overwrite
```

Dry run to see what would happen:

```bash
node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS --dry-run
```

With GitHub Enterprise Server:

```bash
GITHUB_API_URL=https://github.example.com/api/v3 node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS
```

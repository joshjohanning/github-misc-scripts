# Add New Script to README.md

You are helping to add a new script to the appropriate README.md file in this repository while ensuring it passes the lint-readme.js validation.

## Context

This repository contains GitHub-related scripts organized in different directories:

- `gh-cli/` - Scripts using GitHub CLI
- `api/` - Scripts using direct API calls
- `scripts/` - General utility scripts
- `graphql/` - GraphQL-specific scripts

Each directory has its own README.md that documents the scripts in that directory.

## Requirements

When adding a new script entry to a README.md, you must ensure it meets these criteria from `lint-readme.js`:

### 1. Alphabetical Order

- Script entries must be in alphabetical order within the "Scripts" section
- Use the appropriate heading level (### for gh-cli, ## for other directories)
- Check existing entries to maintain proper ordering

### 2. Naming Convention

- Script names must follow kebab-case convention
- Avoid short words like "repo" (use "repository"), "org" (use "organization")
- File extensions should be included (.sh, .ps1, .js, .py, etc.)

### 3. Required Information

Each script entry must include:

- **Heading**: `### script-name.sh` (or appropriate extension)
- **Description**: Brief explanation of what the script does
- **Usage examples**: If applicable, show how to run the script (We don't need both usage AND an example of running the script - just one please)
- **Notes/Warnings**: Any important information about prerequisites, permissions, or limitations

### 4. File Existence

- Only add entries for scripts that actually exist in the repository
- The script file must be committed to Git (not just local files)

## Template Format

Use this template when adding a new script entry:

```markdown
### script-name.sh

Brief description of what the script does.

Usage:

\`\`\`shell
./script-name.sh <parameter1> <parameter2>
\`\`\`

Additional details, examples, or notes if needed.

> [!NOTE]
> Any important notes about requirements or limitations.
```

## Process

1. **Identify the correct directory** where the script belongs
2. **Check the existing README.md** in that directory for formatting patterns
3. **Find the correct alphabetical position** for the new entry
4. **Add the script entry** using the template above
5. **Verify the entry** includes all required information

## Validation

After adding the script entry, the lint-readme.js will check:

- ✅ Script exists in the repository and is committed
- ✅ Entry is in alphabetical order
- ✅ Follows kebab-case naming convention
- ✅ Uses appropriate heading level
- ✅ Avoids short words in file names

## Examples

Good script entry:

```markdown
### get-organization-repositories.sh

Gets a list of all repositories in an organization with optional filtering.

Usage:

\`\`\`shell
./get-organization-repositories.sh my-org
./get-organization-repositories.sh my-org --type=private
\`\`\`

> [!NOTE]
> Requires organization member permissions to see private repositories.
```

## Instructions

When I provide you with a script name and description, please:

1. Determine which directory/README.md it belongs in
2. Find the correct alphabetical position
3. Create a properly formatted entry following the template
4. Include appropriate usage examples and notes
5. Ensure it will pass all lint-readme.js validations

Ask for clarification if you need more details about the script's functionality or usage patterns.

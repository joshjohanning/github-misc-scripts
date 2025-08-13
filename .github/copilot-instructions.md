# Copilot instructions

## scripts in the `gh-cli` and `scripts` directories

When creating or modifying scripts in the `gh-cli` directory, ensure:

- The script has input parameters
- The script has a basic description and usage examples at the top
- We make sure to paginate (`--paginate`) when retrieving results
- Note any special permissions/token requirements
- If modifying input parameters to a script, make sure to update the respective `README.md` in the script directory (if applicable)

## README.md documentation

When adding new scripts to any directory:

- Always add an entry to the appropriate `README.md` file in alphabetical order
- Follow the existing format and structure in the README
- Include a clear description, usage examples, and any prerequisites/notes
- We don't need both usage AND an example of running the script - just one please
- Use proper kebab-case naming convention for script files
- Avoid short words like "repo" (use "repository"), "org" (use "organization")
- Test that the entry passes `lint-readme.js` validation

## Script naming and structure

- Use kebab-case for all script filenames (e.g., `get-organization-repositories.sh`)
- Include appropriate file extensions (.sh, .ps1, .js, .py)
- Make shell scripts executable with `chmod +x`
- Add shebang lines at the top of scripts (e.g., `#!/bin/bash`)
- Include error handling and parameter validation

## API and authentication patterns

- Use `gh api --paginate` for GitHub CLI API calls
- Include proper error handling for API rate limits and permissions
- Document required scopes and permissions in script comments
- Use environment variables or parameters for sensitive data (never hardcode tokens)
- For scripts requiring special permissions, mention this in both script comments and README

# Copilot instructions

## scripts in the `gh-cli` and `scripts` directories

When creating or modifying scripts in the `gh-cli` and `scripts` directories:

- Ensure the script has input parameters
- Include input validation and meaningful error messages
- Ensure the script has a basic description and usage examples at the top
- Make sure to paginate (`--paginate` and/or `octokit.paginate`) when retrieving results
- Note any special permissions/token requirements
- If modifying input parameters to a script, make sure to update the respective `README.md` in the script directory (if applicable)
- Use only `2` spaces for indentation - not `4`
- Do not leave any trailing whitespace at the end of lines
- With `gh api` commands, prefer `--jq` versus piping to `jq` when possible
- Include the header `-H "X-Github-Next-Global-ID: 1"` in GraphQL queries to retrieve the new global ID format - see the [GitHub migration guide for global node IDs](https://docs.github.com/en/graphql/guides/migrating-graphql-global-node-ids) for details

## README.md documentation

When adding new scripts to any directory:

- Always add an entry to the appropriate `README.md` file in alphabetical order
- Follow the existing format and structure in the README
- Include a clear description, usage examples, and any prerequisites/notes
- We don't need both usage AND an example of running the script - just one please
- Use proper kebab-case naming convention for script files
- Avoid short words like "repo" (use "repository"), "org" (use "organization")
- Test that the entry passes `lint-readme.js` validation
- Don't be too verbose - keep descriptions and usage instructions concise and to the point
- Don't use periods after bullet points for consistency

## script naming and structure

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
- Add hostname support for GitHub Enterprise instances / ghe.com when applicable

## commit messages

Prefer the Conventional Commits specification:

- Format: `<type>(<scope>): <description>`
- Types:
  - `feat`: New feature
  - `fix`: Bug fix
  - `refactor`: Code change that neither fixes a bug nor adds a feature
  - `docs`: Documentation only changes
  - `chore`: Changes to build process or auxiliary tools
  - `ci`: Changes to CI configuration files and scripts
  - `style`: Code style changes (formatting, missing semicolons, etc.)
  - `test`: Adding or updating tests
- Scopes (optional):
  - `scripts`: Changes in the scripts directory
  - `gh-cli`: Changes in the gh-cli directory
  - `ci`: Changes to CI/linting tools
- Description: Short, imperative tense summary (e.g., "add feature" not "added feature")
- Body (optional): Provide additional context with bullet points
- Keep it concise but descriptive
- Append `!` to the type if it's a breaking change (e.g., `feat!: add additional required input parameters`)

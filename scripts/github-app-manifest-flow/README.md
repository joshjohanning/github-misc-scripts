# GitHub App Manifest Scripts

Scripts for creating GitHub Apps using the [GitHub App Manifest flow](https://docs.github.com/en/apps/sharing-github-apps/registering-a-github-app-from-a-manifest). The manifest flow is a streamlined way to create GitHub Apps by posting a JSON configuration to GitHub, which automatically generates the app and returns credentials including a private key.

## Overview

The GitHub App Manifest flow allows you to:

- Create GitHub Apps programmatically without manual configuration
- Automatically generate and receive private keys
- Set up apps for users or organizations through a web-based flow
- Simplify GitHub App creation for testing or development environments

## Workflow

### 1. Generate HTML Form

Create an HTML form that will initiate the manifest flow:

```bash
./generate-github-app-manifest-form.sh [organization]
```

**For an organization:**

```bash
./generate-github-app-manifest-form.sh my-org
```

**For a personal account:**

```bash
./generate-github-app-manifest-form.sh
```

This creates a `github-app-manifest-form.html` file with:

- Pre-configured manifest JSON
- Instructions for local server setup
- Automatic code capture when GitHub redirects back
- Dropdown sections with detailed usage instructions

### 2. Serve the HTML File

The HTML file must be served over HTTP (not opened as `file://`). Start a local server:

```bash
# Python 3
python3 -m http.server 8000

# Python 2
python -m SimpleHTTPServer 8000

# Node.js
npx http-server -p 8000

# PHP
php -S localhost:8000
```

Then open: `http://localhost:8000/github-app-manifest-form.html`

### 3. Create the App

1. Click "Create GitHub App from Manifest" in the form
2. GitHub redirects you to review the app configuration
3. Click "Create GitHub App" on GitHub's page
4. GitHub redirects back to your local server with a manifest code in the URL
5. The code is automatically displayed in the success message

### 4. Convert Manifest Code

Use the manifest code to retrieve your app credentials:

```bash
export GITHUB_TOKEN=ghp_abc  # Classic PAT required
./create-github-app-from-manifest.sh <manifest-code>
```

The script will:

- Convert the manifest code into app credentials
- Display the app ID, client ID, client secret, and webhook secret
- Automatically save the private key to a file: `<app-name>.<date>.private-key.pem`

## Scripts

### generate-github-app-manifest-form.sh

Generates an interactive HTML form for the GitHub App Manifest flow.

**Usage:**

```bash
./generate-github-app-manifest-form.sh [organization]
```

**Features:**

- Creates customized form for organization or personal account
- Includes collapsible sections with detailed instructions
- Automatically captures and displays the manifest code on redirect
- Provides copy-paste commands for next steps

**Output:** `github-app-manifest-form.html`

### create-github-app-from-manifest.sh

Converts a manifest code into GitHub App credentials with detailed output and error handling.

**Usage:**

```bash
export GITHUB_TOKEN=ghp_abc
./create-github-app-from-manifest.sh <manifest-code>
```

**Features:**

- Comprehensive error checking and validation
- Detailed explanations of what a manifest code is
- Formatted JSON output with all app details
- Automatic private key file creation
- Helpful instructions for next steps

**Requirements:**

- `curl`
- `jq`
- Classic GitHub personal access token (fine-grained tokens not supported)

**Output:**

- JSON with app ID, client ID, secrets, permissions, and events
- Private key file: `<app-name>.<date>.private-key.pem`

### github-app-manifest-form-example.html

Example of the generated HTML form. This file demonstrates what the `generate-github-app-manifest-form.sh` script creates.

**Note:** This is a sample output file and should not be edited directly. Regenerate it using the shell script.

## Requirements

- **curl**: For API requests
- **jq**: For JSON parsing
- **Classic GitHub PAT**: Fine-grained tokens are not supported for the manifest conversion endpoint
  - Token must start with `ghp_`
  - No specific scopes required for the conversion endpoint
- **Local HTTP server**: To serve the HTML form (Python, Node.js, PHP, etc.)

## Complete Example

```bash
# Step 1: Generate the form
./generate-github-app-manifest-form.sh my-org

# Step 2: Start a local server
python3 -m http.server 8000

# Step 3: Open in browser
# Visit: http://localhost:8000/github-app-manifest-form.html
# Click "Create GitHub App from Manifest"
# Complete the flow on GitHub
# Get redirected back with code (e.g., code=a180b1a3d263c81bc6441d7b990bae27d4c10679)

# Step 4: Convert the code to credentials
export GITHUB_TOKEN=ghp_your_classic_token_here
./create-github-app-from-manifest.sh a180b1a3d263c81bc6441d7b990bae27d4c10679

# Output: JSON with credentials + my-app.2024-01-15.private-key.pem
```

## Important Notes

- **Manifest codes expire in 1 hour** and can only be used once
- **Fine-grained tokens are NOT supported** - you must use a classic personal access token
- The private key can only be retrieved during this conversion - save it securely
- Client secret and webhook secret are also only shown once
- The HTML form must be served over HTTP, not opened as a local file

## Customizing the Manifest

To customize the app configuration, edit the `manifest` object in the generated HTML file before submitting:

```javascript
const manifest = {
  name: 'My Custom App',
  url: 'https://www.example.com',
  hook_attributes: {
    url: 'https://example.com/github/events'
  },
  redirect_url: redirectUrl,
  callback_urls: [redirectUrl],
  public: false,
  default_permissions: {
    metadata: 'read',
    contents: 'write',
    issues: 'write',
    pull_requests: 'write'
  },
  default_events: ['issues', 'pull_request', 'push']
};
```

See the [GitHub App Manifest documentation](https://docs.github.com/en/apps/sharing-github-apps/registering-a-github-app-from-a-manifest#github-app-manifest-parameters) for all available parameters.

## Troubleshooting

### "Fine-grained tokens are not supported"

The manifest conversion endpoint only accepts classic personal access tokens (starting with `ghp_`). Create one at: Settings → Developer settings → Personal access tokens → Tokens (classic)

### "No parser could be inferred for file"

Make sure `jq` is installed:

```bash
brew install jq    # macOS
apt-get install jq # Ubuntu/Debian
yum install jq     # CentOS/RHEL
```

### "Error: manifest code is required"

The manifest code comes from GitHub after completing the web flow. You cannot generate it manually.

### Form doesn't work when opened as file://

The HTML form must be served over HTTP. Use one of the local server commands provided in the workflow section.

## References

- [GitHub App Manifest Flow Documentation](https://docs.github.com/en/apps/sharing-github-apps/registering-a-github-app-from-a-manifest)
- [Create a GitHub App from a manifest API](https://docs.github.com/en/rest/apps/apps#create-a-github-app-from-a-manifest)
- [GitHub App Manifest Parameters](https://docs.github.com/en/apps/sharing-github-apps/registering-a-github-app-from-a-manifest#github-app-manifest-parameters)

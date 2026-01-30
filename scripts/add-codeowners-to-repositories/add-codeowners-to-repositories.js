#!/usr/bin/env node

//
// Adds a CODEOWNERS file to the default branch in a list of repositories
//
// Usage:
//   node add-codeowners-to-repositories.js --repos-file <file> --codeowners <file> [options]
//
// Options:
//   --repos-file <file>   File containing list of repositories (org/repo format, one per line)
//   --codeowners <file>   Path to the CODEOWNERS file to add
//   --overwrite           Overwrite existing CODEOWNERS file (default: append)
//   --create-pr           Create a pull request instead of committing directly
//   --branch <name>       Branch name for PR (default: add-codeowners)
//   --pr-title <title>    PR title (default: Add CODEOWNERS file)
//   --dry-run             Show what would be done without making changes
//   --concurrency <n>     Number of concurrent API calls (default: 10)
//   --help                Show help
//
// Environment Variables:
//   GITHUB_TOKEN          GitHub PAT with repo scope (required)
//   GITHUB_API_URL        API endpoint (defaults to https://api.github.com)
//
// Example:
//   node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS
//   node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS --overwrite
//   node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS --create-pr
//

import { Octokit } from "octokit";
import fs from 'fs';
import { fileURLToPath } from 'url';

// =============================================================================
// Configuration
// =============================================================================
const DEFAULT_CONCURRENCY = 10;
const DEFAULT_BRANCH_NAME = 'add-codeowners';
const DEFAULT_PR_TITLE = 'Add CODEOWNERS file';

// Possible CODEOWNERS file locations (in order of preference)
const CODEOWNERS_PATHS = ['CODEOWNERS', '.github/CODEOWNERS', 'docs/CODEOWNERS'];

// API call counter
let apiCallCount = 0;

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const config = {
    reposFile: null,
    codeownersFile: null,
    overwrite: false,
    createPr: false,
    branch: DEFAULT_BRANCH_NAME,
    prTitle: DEFAULT_PR_TITLE,
    dryRun: false,
    concurrency: DEFAULT_CONCURRENCY,
    help: false
  };

  // Helper to get required argument value
  const getRequiredValue = (option, index) => {
    const value = args[index];
    if (value === undefined || value.startsWith('-')) {
      console.error(`ERROR: ${option} requires a value`);
      process.exit(1);
    }
    return value;
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
      case '--help':
      case '-h':
        config.help = true;
        break;
      case '--repos-file':
        config.reposFile = getRequiredValue('--repos-file', ++i);
        break;
      case '--codeowners':
        config.codeownersFile = getRequiredValue('--codeowners', ++i);
        break;
      case '--overwrite':
        config.overwrite = true;
        break;
      case '--create-pr':
        config.createPr = true;
        break;
      case '--branch':
        config.branch = getRequiredValue('--branch', ++i);
        break;
      case '--pr-title':
        config.prTitle = getRequiredValue('--pr-title', ++i);
        break;
      case '--dry-run':
        config.dryRun = true;
        break;
      case '--concurrency': {
        const value = getRequiredValue('--concurrency', ++i);
        const parsed = parseInt(value, 10);
        if (isNaN(parsed) || parsed < 1) {
          console.error(`ERROR: --concurrency must be a positive number`);
          process.exit(1);
        }
        config.concurrency = parsed;
        break;
      }
      default:
        if (arg.startsWith('-')) {
          console.error(`ERROR: Unknown option: ${arg}`);
          process.exit(1);
        }
    }
  }

  return config;
}

function showHelp() {
  console.log(`
Adds a CODEOWNERS file to the default branch in a list of repositories.

Usage:
  node add-codeowners-to-repositories.js --repos-file <file> --codeowners <file> [options]

Options:
  --repos-file <file>   File containing list of repositories (org/repo format, one per line)
  --codeowners <file>   Path to the CODEOWNERS file to add
  --overwrite           Overwrite existing CODEOWNERS file (default: append)
  --create-pr           Create a pull request instead of committing directly
  --branch <name>       Branch name for PR (default: ${DEFAULT_BRANCH_NAME})
  --pr-title <title>    PR title (default: ${DEFAULT_PR_TITLE})
  --dry-run             Show what would be done without making changes
  --concurrency <n>     Number of concurrent API calls (default: ${DEFAULT_CONCURRENCY})
  --help                Show this help message

Environment Variables:
  GITHUB_TOKEN          GitHub PAT with repo scope (required)
  GITHUB_API_URL        API endpoint (defaults to https://api.github.com)

Input File Format:
  The repos file should contain one repository per line in org/repo format:
    my-org/repo-1
    my-org/repo-2
    other-org/repo-3

  Lines starting with # are treated as comments and ignored.
  Empty lines are also ignored.

Behavior:
  - Checks for existing CODEOWNERS in: CODEOWNERS, .github/CODEOWNERS, docs/CODEOWNERS
  - By default, appends new content to existing CODEOWNERS file
  - With --overwrite, replaces the entire CODEOWNERS file
  - Creates CODEOWNERS in the root if it doesn't exist
  - With --create-pr, creates a branch and pull request for review

Examples:
  node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS
  node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS --overwrite
  node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS --create-pr
  node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS --create-pr --branch my-branch --pr-title "My PR Title"
  node add-codeowners-to-repositories.js --repos-file repos.txt --codeowners ./CODEOWNERS --dry-run
`);
}

// Shared configuration
const baseUrl = process.env.GITHUB_API_URL || 'https://api.github.com';

// Create Octokit instance with retry logic
let octokitInstance = null;
function createOctokit() {
  if (octokitInstance) return octokitInstance;

  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    console.error("ERROR: GITHUB_TOKEN environment variable is required");
    process.exit(1);
  }

  octokitInstance = new Octokit({
    auth: token,
    baseUrl,
    throttle: {
      onRateLimit: (retryAfter, options, _octokit, retryCount) => {
        console.error(`Rate limit hit for ${options.method} ${options.url}`);
        if (retryCount < 3) {
          console.error(`Retrying after ${retryAfter} seconds...`);
          return true;
        }
        return false;
      },
      onSecondaryRateLimit: (retryAfter, options, _octokit, retryCount) => {
        console.error(`Secondary rate limit hit for ${options.method} ${options.url}`);
        if (retryCount < 3) {
          console.error(`Retrying after ${retryAfter} seconds...`);
          return true;
        }
        return false;
      }
    }
  });

  octokitInstance.hook.before('request', () => {
    apiCallCount++;
  });

  return octokitInstance;
}

// Read repositories from file
function readRepositoriesFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const repos = content
      .split('\n')
      .map(line => line.trim())
      .filter(line => line && !line.startsWith('#'))
      .map(line => {
        const parts = line.split('/');
        if (parts.length !== 2) {
          console.error(`WARNING: Invalid repository format: ${line} (expected org/repo)`);
          return null;
        }
        return { org: parts[0], repo: parts[1] };
      })
      .filter(Boolean);

    if (repos.length === 0) {
      console.error(`ERROR: No valid repositories found in ${filePath}`);
      process.exit(1);
    }

    return repos;
  } catch (error) {
    console.error(`ERROR: Failed to read repositories file: ${filePath}`);
    console.error(error.message);
    process.exit(1);
  }
}

// Read CODEOWNERS file content
function readCodeownersFile(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch (error) {
    console.error(`ERROR: Failed to read CODEOWNERS file: ${filePath}`);
    console.error(error.message);
    process.exit(1);
  }
}

// Get repository default branch and its SHA
async function getDefaultBranchInfo(octokit, org, repo) {
  const { data } = await octokit.rest.repos.get({
    owner: org,
    repo
  });
  const defaultBranch = data.default_branch;

  // Get the SHA of the default branch
  const { data: refData } = await octokit.rest.git.getRef({
    owner: org,
    repo,
    ref: `heads/${defaultBranch}`
  });

  return {
    name: defaultBranch,
    sha: refData.object.sha
  };
}

// Create a new branch from the default branch
async function createBranch(octokit, org, repo, branchName, baseSha) {
  await octokit.rest.git.createRef({
    owner: org,
    repo,
    ref: `refs/heads/${branchName}`,
    sha: baseSha
  });
}

// Create a pull request
async function createPullRequest(octokit, org, repo, head, base, title, body) {
  const { data } = await octokit.rest.pulls.create({
    owner: org,
    repo,
    title,
    body,
    head,
    base
  });
  return {
    number: data.number,
    url: data.html_url
  };
}

// Check if CODEOWNERS file exists and return its info
async function findExistingCodeowners(octokit, org, repo) {
  for (const path of CODEOWNERS_PATHS) {
    try {
      const { data } = await octokit.rest.repos.getContent({
        owner: org,
        repo,
        path
      });
      // File exists
      const content = Buffer.from(data.content, 'base64').toString('utf8');
      return {
        exists: true,
        path,
        sha: data.sha,
        content
      };
    } catch (error) {
      if (error.status === 404) {
        continue; // Try next path
      }
      throw error;
    }
  }

  // File doesn't exist in any location
  return {
    exists: false,
    path: 'CODEOWNERS',
    sha: null,
    content: null
  };
}

// Create or update CODEOWNERS file
async function updateCodeowners(octokit, org, repo, path, content, sha, message, branch = null) {
  const params = {
    owner: org,
    repo,
    path,
    message,
    content: Buffer.from(content).toString('base64')
  };

  if (sha) {
    params.sha = sha;
  }

  if (branch) {
    params.branch = branch;
  }

  const { data } = await octokit.rest.repos.createOrUpdateFileContents(params);
  return {
    path: data.content.path,
    sha: data.content.sha,
    commitDate: data.commit.committer.date
  };
}

// Process a single repository
async function processRepository(octokit, org, repo, newCodeownersContent, config) {
  const result = {
    repository: `${org}/${repo}`,
    status: 'unknown',
    message: '',
    path: null,
    sha: null,
    prUrl: null
  };

  try {
    // Find existing CODEOWNERS file
    const existing = await findExistingCodeowners(octokit, org, repo);

    let finalContent;
    let commitMessage;

    if (existing.exists) {
      if (config.overwrite) {
        // Overwrite mode: replace entire content
        finalContent = newCodeownersContent;
        commitMessage = 'Updating CODEOWNERS file';
        result.message = 'Replaced existing CODEOWNERS';
      } else {
        // Append mode: add new content to existing
        finalContent = existing.content + '\n' + newCodeownersContent;
        commitMessage = 'Updating CODEOWNERS file';
        result.message = 'Appended to existing CODEOWNERS';
      }
    } else {
      // Create new file
      finalContent = newCodeownersContent;
      commitMessage = 'Adding CODEOWNERS file';
      result.message = 'Created new CODEOWNERS file';
    }

    if (config.dryRun) {
      result.status = 'dry-run';
      result.path = existing.path;
      result.message += config.createPr ? ' (dry-run, would create PR)' : ' (dry-run)';
      return result;
    }

    if (config.createPr) {
      // Get default branch info
      const defaultBranchInfo = await getDefaultBranchInfo(octokit, org, repo);

      // Create a new branch
      const branchName = config.branch;
      try {
        await createBranch(octokit, org, repo, branchName, defaultBranchInfo.sha);
      } catch (error) {
        if (error.status === 422 && error.message.includes('Reference already exists')) {
          // Branch already exists - could be from a previous run
          result.status = 'error';
          result.message = `Branch '${branchName}' already exists. Delete it or use a different branch name.`;
          return result;
        }
        throw error;
      }

      // Commit to the new branch
      // Need to get the file info from the new branch (which is same as default at this point)
      const commitResult = await updateCodeowners(
        octokit,
        org,
        repo,
        existing.path,
        finalContent,
        existing.sha,
        commitMessage,
        branchName
      );

      // Create the pull request
      const prBody = existing.exists
        ? `This PR ${config.overwrite ? 'replaces' : 'updates'} the CODEOWNERS file.`
        : 'This PR adds a CODEOWNERS file to the repository.';

      const pr = await createPullRequest(
        octokit,
        org,
        repo,
        branchName,
        defaultBranchInfo.name,
        config.prTitle,
        prBody
      );

      result.status = 'success';
      result.path = commitResult.path;
      result.sha = commitResult.sha;
      result.prUrl = pr.url;
      result.message += ` (PR #${pr.number})`;
    } else {
      // Commit directly to default branch
      const commitResult = await updateCodeowners(
        octokit,
        org,
        repo,
        existing.path,
        finalContent,
        existing.sha,
        commitMessage
      );

      result.status = 'success';
      result.path = commitResult.path;
      result.sha = commitResult.sha;
    }

  } catch (error) {
    result.status = 'error';
    result.message = error.message;
  }

  return result;
}

// Process repositories with concurrency control
async function processRepositories(octokit, repositories, codeownersContent, config) {
  const results = [];
  const total = repositories.length;

  // Process in batches for concurrency
  for (let i = 0; i < repositories.length; i += config.concurrency) {
    const batch = repositories.slice(i, i + config.concurrency);
    const batchResults = await Promise.all(
      batch.map((repoInfo, idx) => {
        const num = i + idx + 1;
        const pct = Math.round((num / total) * 100);
        process.stderr.write(`[${num}/${total}] (${pct}%) Processing: ${repoInfo.org}/${repoInfo.repo}\n`);
        return processRepository(octokit, repoInfo.org, repoInfo.repo, codeownersContent, config);
      })
    );
    results.push(...batchResults);
  }

  return results;
}

// Print results summary
function printSummary(results) {
  const summary = {
    success: 0,
    error: 0,
    dryRun: 0
  };

  console.error('\n--- Results ---');
  for (const result of results) {
    const statusIcon = result.status === 'success' ? '✓' :
                       result.status === 'dry-run' ? '○' : '✗';
    let line = `${statusIcon} ${result.repository}: ${result.message}`;
    if (result.prUrl) {
      line += ` - ${result.prUrl}`;
    }
    console.error(line);

    if (result.status === 'success') summary.success++;
    else if (result.status === 'dry-run') summary.dryRun++;
    else summary.error++;
  }

  console.error('\n--- Summary ---');
  if (summary.dryRun > 0) {
    console.error(`Would update: ${summary.dryRun} repositories`);
  } else {
    console.error(`Success: ${summary.success}`);
    console.error(`Errors: ${summary.error}`);
  }
}

// Main function
async function main() {
  const config = parseArgs();

  if (config.help) {
    showHelp();
    process.exit(0);
  }

  // Validate required arguments
  if (!config.reposFile) {
    console.error("ERROR: --repos-file is required");
    console.error("Usage: node add-codeowners-to-repositories.js --repos-file <file> --codeowners <file>");
    console.error("Use --help for more information");
    process.exit(1);
  }

  if (!config.codeownersFile) {
    console.error("ERROR: --codeowners is required");
    console.error("Usage: node add-codeowners-to-repositories.js --repos-file <file> --codeowners <file>");
    console.error("Use --help for more information");
    process.exit(1);
  }

  // Read input files
  const repositories = readRepositoriesFile(config.reposFile);
  const codeownersContent = readCodeownersFile(config.codeownersFile);

  console.error(`Processing ${repositories.length} repositories...`);
  console.error(`Mode: ${config.overwrite ? 'overwrite' : 'append'}${config.createPr ? ' (create PR)' : ''}`);
  if (config.dryRun) {
    console.error('DRY RUN: No changes will be made');
  }
  console.error('');

  // Create Octokit instance
  const octokit = createOctokit();

  // Process repositories
  const results = await processRepositories(octokit, repositories, codeownersContent, config);

  // Print summary
  printSummary(results);

  // Display API call count
  console.error(`\nTotal API calls: ${apiCallCount}`);

  // Exit with error code if any failures
  const hasErrors = results.some(r => r.status === 'error');
  if (hasErrors) {
    process.exit(1);
  }
}

// Only run main() if this is the entry point
const isMainModule = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMainModule) {
  main().catch(err => {
    console.error(`ERROR: ${err.message}`);
    process.exit(1);
  });
}

// Export functions for testing
export {
  parseArgs,
  readRepositoriesFile,
  readCodeownersFile,
  getDefaultBranchInfo,
  createBranch,
  createPullRequest,
  findExistingCodeowners,
  updateCodeowners,
  processRepository,
  processRepositories,
  createOctokit,
  CODEOWNERS_PATHS,
  DEFAULT_CONCURRENCY,
  DEFAULT_BRANCH_NAME,
  DEFAULT_PR_TITLE
};

#!/usr/bin/env node

//
// Generate a comprehensive code scanning coverage report for all repositories in a GitHub organization
//
// Usage:
//   node code-scanning-coverage-report.js <organization> [options]
//
// Options:
//   --output <file>       Write CSV to file (also generates sub-reports)
//   --repo <repo>         Check a single repository instead of all repos
//   --sample              Sample 25 random repositories
//   --check-workflows     Include CodeQL workflow run status column
//   --check-actions       Check for unscanned GitHub Actions workflows
//   --concurrency <n>     Number of concurrent API calls (default: 10)
//   --help                Show help
//
// Environment Variables:
//   GITHUB_TOKEN                    GitHub PAT with repo scope (required if not using App auth)
//   GITHUB_API_URL                  API endpoint (defaults to https://api.github.com)
//
//   GitHub App Authentication (alternative to GITHUB_TOKEN, recommended for higher rate limits):
//   GITHUB_APP_ID                   GitHub App ID
//   GITHUB_APP_PRIVATE_KEY_PATH     Path to GitHub App private key file (.pem)
//   GITHUB_APP_INSTALLATION_ID      GitHub App installation ID for the organization
//
// Example:
//   node code-scanning-coverage-report.js my-org --output report.csv
//

const { Octokit } = require("octokit");
const { createAppAuth } = require("@octokit/auth-app");
const fs = require('fs');
const path = require('path');

// CodeQL supported languages
const CODEQL_LANGUAGES = new Set([
  'c', 'c++', 'cpp', 'csharp', 'c#', 'go', 'java', 'kotlin',
  'javascript', 'typescript', 'python', 'ruby', 'swift'
]);

// Language normalization map (GitHub language -> CodeQL language name)
const LANGUAGE_NORMALIZE = {
  'c#': 'csharp',
  'csharp': 'csharp',
  'c': 'c-cpp',
  'c++': 'c-cpp',
  'cpp': 'c-cpp',
  'javascript': 'javascript-typescript',
  'typescript': 'javascript-typescript',
  'java': 'java-kotlin',
  'kotlin': 'java-kotlin'
};

// Configuration
const SAMPLE_SIZE = 25;
const DEFAULT_CONCURRENCY = 10;

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const config = {
    org: null,
    output: null,
    repo: null,
    sample: false,
    checkWorkflows: false,
    checkActions: false,
    concurrency: DEFAULT_CONCURRENCY,
    help: false
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
      case '--help':
      case '-h':
        config.help = true;
        break;
      case '--output':
        config.output = args[++i];
        break;
      case '--repo':
        config.repo = args[++i];
        break;
      case '--sample':
        config.sample = true;
        break;
      case '--check-workflows':
        config.checkWorkflows = true;
        break;
      case '--check-actions':
        config.checkActions = true;
        break;
      case '--concurrency':
        config.concurrency = parseInt(args[++i], 10) || DEFAULT_CONCURRENCY;
        break;
      default:
        if (!arg.startsWith('-')) {
          config.org = arg;
        } else {
          console.error(`Unknown option: ${arg}`);
          process.exit(1);
        }
    }
  }

  return config;
}

function showHelp() {
  console.log(`
Generate a comprehensive code scanning coverage report for all repositories in a GitHub organization.

Usage:
  node code-scanning-coverage-report.js <organization> [options]

Arguments:
  organization          GitHub organization name

Options:
  --output <file>       Write CSV to file (also generates sub-reports)
  --repo <repo>         Check a single repository instead of all repos
  --sample              Sample ${SAMPLE_SIZE} random repositories
  --check-workflows     Include CodeQL workflow run status column
  --check-actions       Check for unscanned GitHub Actions workflows
  --concurrency <n>     Number of concurrent API calls (default: ${DEFAULT_CONCURRENCY})
  --help                Show this help message

Environment Variables:
  GITHUB_TOKEN          GitHub token with repo scope (required)
  GITHUB_API_URL        API endpoint (defaults to https://api.github.com)

Examples:
  node code-scanning-coverage-report.js my-org
  node code-scanning-coverage-report.js my-org --output report.csv
  node code-scanning-coverage-report.js my-org --repo my-repo
  node code-scanning-coverage-report.js my-org --sample --output sample.csv
  node code-scanning-coverage-report.js my-org --check-workflows --check-actions

Output Columns:
  - Repository: Repository name
  - Default Branch: The default branch of the repository
  - Last Updated: When the repository was last updated
  - Languages: Languages detected in the repository
  - CodeQL Enabled: Yes / No Scans / Disabled / Requires GHAS / No
  - Last Default Branch Scan Date: Date of most recent scan on default branch
  - Scanned Languages: Languages scanned by CodeQL
  - Unscanned CodeQL Languages: CodeQL-supported languages not being scanned
  - Open Alerts: Number of open code scanning alerts
  - Analysis Errors: Errors from most recent analysis
  - Analysis Warnings: Warnings from most recent analysis
  - Workflow Status: (with --check-workflows) CodeQL workflow run status

Sub-reports (generated with --output):
  - *-disabled.csv: Repos with CodeQL disabled or no scans
  - *-stale.csv: Repos modified >90 days after last scan
  - *-missing-languages.csv: Repos scanning but missing some CodeQL languages
  - *-open-alerts.csv: Repos with open code scanning alerts
  - *-analysis-issues.csv: Repos with analysis errors or warnings
`);
}

// Initialize Octokit
function createOctokit() {
  const baseUrl = process.env.GITHUB_API_URL || 'https://api.github.com';

  // Check for GitHub App authentication
  const appId = process.env.GITHUB_APP_ID;
  const privateKeyPath = process.env.GITHUB_APP_PRIVATE_KEY_PATH;
  const installationId = process.env.GITHUB_APP_INSTALLATION_ID;

  if (appId && privateKeyPath && installationId) {
    // Use GitHub App authentication
    console.error('Using GitHub App authentication...');

    // Read private key from file
    let privateKey;
    try {
      privateKey = fs.readFileSync(privateKeyPath, 'utf8');
    } catch (error) {
      console.error(`ERROR: Failed to read private key file: ${privateKeyPath}`);
      console.error(error.message);
      process.exit(1);
    }

    return new Octokit({
      authStrategy: createAppAuth,
      auth: {
        appId: parseInt(appId, 10),
        privateKey,
        installationId: parseInt(installationId, 10)
      },
      baseUrl,
      throttle: {
        onRateLimit: (retryAfter, options, octokit) => {
          console.error(`Rate limit hit, retrying after ${retryAfter} seconds...`);
          return true;
        },
        onSecondaryRateLimit: (retryAfter, options, octokit) => {
          console.error(`Secondary rate limit hit, retrying after ${retryAfter} seconds...`);
          return true;
        }
      }
    });
  }

  // Fall back to token authentication
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    console.error("ERROR: Authentication required. Set either:");
    console.error("  - GITHUB_TOKEN environment variable, or");
    console.error("  - GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY_PATH, and GITHUB_APP_INSTALLATION_ID");
    process.exit(1);
  }

  return new Octokit({
    auth: token,
    baseUrl,
    throttle: {
      onRateLimit: (retryAfter, options, octokit) => {
        console.error(`Rate limit hit, retrying after ${retryAfter} seconds...`);
        return true;
      },
      onSecondaryRateLimit: (retryAfter, options, octokit) => {
        console.error(`Secondary rate limit hit, retrying after ${retryAfter} seconds...`);
        return true;
      }
    }
  });
}

// Fetch all repositories in an organization using GraphQL
async function fetchRepositories(octokit, org) {
  const repos = [];
  let cursor = null;

  const query = `
    query($org: String!, $cursor: String) {
      organization(login: $org) {
        repositories(first: 100, after: $cursor) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            name
            updatedAt
            isArchived
            defaultBranchRef {
              name
            }
          }
        }
      }
    }
  `;

  do {
    const result = await octokit.graphql(query, { org, cursor });
    const data = result.organization.repositories;
    repos.push(...data.nodes.map(repo => ({
      name: repo.name,
      updatedAt: repo.updatedAt,
      isArchived: repo.isArchived,
      defaultBranch: repo.defaultBranchRef?.name || 'main'
    })));
    cursor = data.pageInfo.hasNextPage ? data.pageInfo.endCursor : null;
  } while (cursor);

  return repos;
}

// Fetch a single repository
async function fetchSingleRepository(octokit, org, repoName) {
  const query = `
    query($org: String!, $repo: String!) {
      repository(owner: $org, name: $repo) {
        name
        updatedAt
        isArchived
        defaultBranchRef {
          name
        }
      }
    }
  `;

  const result = await octokit.graphql(query, { org, repo: repoName });
  const repo = result.repository;

  if (!repo) {
    throw new Error(`Repository ${org}/${repoName} not found`);
  }

  return [{
    name: repo.name,
    updatedAt: repo.updatedAt,
    isArchived: repo.isArchived,
    defaultBranch: repo.defaultBranchRef?.name || 'main'
  }];
}

// Fetch repository languages
async function fetchRepoLanguages(octokit, org, repo) {
  try {
    const { data } = await octokit.rest.repos.listLanguages({ owner: org, repo });
    return Object.keys(data);
  } catch {
    return [];
  }
}

// Check CodeQL/code scanning status
async function checkCodeQLStatus(octokit, org, repo) {
  try {
    const { data } = await octokit.rest.codeScanning.listRecentAnalyses({
      owner: org,
      repo,
      per_page: 1
    });

    return data.length > 0 ? 'Yes' : 'No Scans';
  } catch (error) {
    const message = error.message?.toLowerCase() || '';
    if (message.includes('advanced security must be enabled')) {
      return 'Requires GHAS';
    }
    if (message.includes('code security must be enabled')) {
      return 'Disabled';
    }
    if (message.includes('no analysis found')) {
      return 'No Scans';
    }
    if (error.status === 404 || error.status === 403) {
      return 'No';
    }
    return 'Unknown';
  }
}

// Get code scanning analyses for a repo
async function fetchScanningInfo(octokit, org, repo, defaultBranch) {
  try {
    const { data } = await octokit.rest.codeScanning.listRecentAnalyses({
      owner: org,
      repo,
      ref: `refs/heads/${defaultBranch}`,
      per_page: 100
    });

    if (!data || data.length === 0) {
      return {
        lastScanDate: null,
        scannedLanguages: [],
        analysisError: null,
        analysisWarning: null
      };
    }

    // Most recent analysis
    const latest = data[0];

    // Extract unique scanned languages from category field
    const languages = new Set();
    for (const analysis of data) {
      const category = analysis.category || '';
      const match = category.match(/language:([a-zA-Z0-9_-]+)/);
      if (match) {
        languages.add(match[1]);
      }
    }

    return {
      lastScanDate: latest.created_at,
      scannedLanguages: Array.from(languages),
      analysisError: latest.error || null,
      analysisWarning: latest.warning || null
    };
  } catch {
    return {
      lastScanDate: null,
      scannedLanguages: [],
      analysisError: null,
      analysisWarning: null
    };
  }
}

// Get open alerts count
async function fetchOpenAlertsCount(octokit, org, repo) {
  try {
    let count = 0;
    for await (const response of octokit.paginate.iterator(
      octokit.rest.codeScanning.listAlertsForRepo,
      { owner: org, repo, state: 'open', per_page: 100 }
    )) {
      count += response.data.length;
    }
    return count;
  } catch {
    return null;
  }
}

// Check if .github/workflows directory exists
async function hasGitHubWorkflows(octokit, org, repo) {
  try {
    await octokit.rest.repos.getContent({
      owner: org,
      repo,
      path: '.github/workflows'
    });
    return true;
  } catch {
    return false;
  }
}

// Get CodeQL workflow status
async function fetchCodeQLWorkflowStatus(octokit, org, repo) {
  try {
    const { data: workflows } = await octokit.rest.actions.listRepoWorkflows({
      owner: org,
      repo
    });

    const codeqlWorkflows = workflows.workflows.filter(w =>
      w.name.toLowerCase().includes('codeql')
    );

    if (codeqlWorkflows.length === 0) {
      return 'No workflow';
    }

    let hasFailure = false;
    let hasSuccess = false;

    for (const workflow of codeqlWorkflows) {
      try {
        const { data: runs } = await octokit.rest.actions.listWorkflowRuns({
          owner: org,
          repo,
          workflow_id: workflow.id,
          per_page: 1
        });

        if (runs.workflow_runs.length > 0) {
          const conclusion = runs.workflow_runs[0].conclusion;
          if (conclusion === 'failure') hasFailure = true;
          if (conclusion === 'success') hasSuccess = true;
        }
      } catch {
        // Skip workflow if we can't fetch runs
      }
    }

    if (hasFailure) return 'Failing';
    if (hasSuccess) return 'OK';
    return 'Unknown';
  } catch {
    return 'Unknown';
  }
}

// Check if language is CodeQL scannable
function isCodeQLLanguage(lang) {
  return CODEQL_LANGUAGES.has(lang.toLowerCase());
}

// Get unscanned CodeQL languages
function getUnscannedLanguages(repoLanguages, scannedLanguages, hasWorkflows, checkActions) {
  const unscanned = new Set();
  const scannedLower = scannedLanguages.map(l => l.toLowerCase());

  // Helper to check if a language is covered by scanned languages
  // Handles combined extractors like javascript-typescript covering both js and ts
  const isLanguageCovered = (langLower) => {
    // Check combined extractor coverage first
    // javascript-typescript covers both javascript and typescript
    // java-kotlin covers both java and kotlin
    // c-cpp covers c, c++, cpp
    if (langLower === 'javascript' || langLower === 'typescript') {
      return scannedLower.some(s => s.includes('javascript'));
    }
    if (langLower === 'java' || langLower === 'kotlin') {
      return scannedLower.some(s => s.includes('java'));
    }
    if (langLower === 'c' || langLower === 'c++' || langLower === 'cpp') {
      return scannedLower.some(s => s === 'c-cpp' || s === 'cpp' || s.includes('c-cpp'));
    }

    // Direct/exact match for other languages (csharp, go, python, ruby, swift)
    return scannedLower.includes(langLower);
  };

  // Check for actions if enabled
  if (checkActions && hasWorkflows && !scannedLower.includes('actions')) {
    unscanned.add('actions');
  }

  // No languages detected
  if (repoLanguages.length === 0) {
    if (unscanned.size > 0) return Array.from(unscanned);
    if (scannedLanguages.length > 0) return [];
    return null; // N/A
  }

  for (const lang of repoLanguages) {
    const langLower = lang.toLowerCase();

    // Normalize C# to csharp
    const normalizedLang = langLower === 'c#' ? 'csharp' : langLower;

    if (!isCodeQLLanguage(normalizedLang)) continue;

    // Check if this language is already being scanned
    if (isLanguageCovered(normalizedLang)) continue;

    // Not covered - add normalized CodeQL language name to unscanned list
    const unscannedName = LANGUAGE_NORMALIZE[normalizedLang] || normalizedLang;
    unscanned.add(unscannedName);
  }

  return unscanned.size > 0 ? Array.from(unscanned) : [];
}

// Process a single repository
async function processRepository(octokit, org, repo, config) {
  const [languages, codeqlStatus, scanningInfo, openAlerts, hasWorkflows, workflowStatus] = await Promise.all([
    fetchRepoLanguages(octokit, org, repo.name),
    checkCodeQLStatus(octokit, org, repo.name),
    fetchScanningInfo(octokit, org, repo.name, repo.defaultBranch),
    fetchOpenAlertsCount(octokit, org, repo.name),
    config.checkActions ? hasGitHubWorkflows(octokit, org, repo.name) : Promise.resolve(false),
    config.checkWorkflows ? fetchCodeQLWorkflowStatus(octokit, org, repo.name) : Promise.resolve(null)
  ]);

  const unscanned = getUnscannedLanguages(
    languages,
    scanningInfo.scannedLanguages,
    hasWorkflows,
    config.checkActions
  );

  return {
    repository: repo.name,
    defaultBranch: repo.defaultBranch,
    lastUpdated: repo.updatedAt ? repo.updatedAt.split('T')[0] : '',
    isArchived: repo.isArchived || false,
    languages: languages.join(';'),
    codeqlEnabled: codeqlStatus,
    lastScanDate: scanningInfo.lastScanDate ? scanningInfo.lastScanDate.split('T')[0] : 'Never',
    scannedLanguages: scanningInfo.scannedLanguages.join(';'),
    unscannedLanguages: unscanned === null ? 'N/A' : (unscanned.length === 0 ? 'None' : unscanned.join(';')),
    openAlerts: openAlerts === null ? 'N/A' : openAlerts,
    analysisError: scanningInfo.analysisError || 'None',
    analysisWarning: scanningInfo.analysisWarning || 'None',
    workflowStatus
  };
}

// Process repositories with concurrency control
async function processRepositories(octokit, org, repos, config) {
  const results = [];
  const total = repos.length;

  // Process in batches for concurrency
  for (let i = 0; i < repos.length; i += config.concurrency) {
    const batch = repos.slice(i, i + config.concurrency);
    const batchResults = await Promise.all(
      batch.map((repo, idx) => {
        const num = i + idx + 1;
        process.stderr.write(`[${num}/${total}] Processing: ${repo.name}\n`);
        return processRepository(octokit, org, repo, config);
      })
    );
    results.push(...batchResults);
  }

  return results;
}

// Generate CSV output
function generateCSV(results, config) {
  const headers = [
    'Repository',
    'Default Branch',
    'Last Updated',
    'Archived',
    'Languages',
    'CodeQL Enabled',
    'Last Default Branch Scan Date',
    'Scanned Languages',
    'Unscanned CodeQL Languages',
    'Open Alerts',
    'Analysis Errors',
    'Analysis Warnings'
  ];

  if (config.checkWorkflows) {
    headers.push('Workflow Status');
  }

  const rows = results.map(r => {
    const row = [
      r.repository,
      r.defaultBranch,
      r.lastUpdated,
      r.isArchived ? 'Yes' : 'No',
      r.languages,
      r.codeqlEnabled,
      r.lastScanDate,
      r.scannedLanguages,
      r.unscannedLanguages,
      r.openAlerts,
      `"${r.analysisError}"`,
      `"${r.analysisWarning}"`
    ];

    if (config.checkWorkflows) {
      row.push(r.workflowStatus);
    }

    return row.join(',');
  });

  return [headers.join(','), ...rows].join('\n');
}

// Generate sub-reports
function generateSubReports(results, outputFile, config) {
  const baseName = outputFile.replace(/\.csv$/, '');
  const headers = generateCSV([], config).split('\n')[0];

  // Helper to write sub-report
  const writeSubReport = (filename, filter, description) => {
    const filtered = results.filter(filter);
    const csv = [headers, ...filtered.map(r => {
      const row = [
        r.repository,
        r.defaultBranch,
        r.lastUpdated,
        r.isArchived ? 'Yes' : 'No',
        r.languages,
        r.codeqlEnabled,
        r.lastScanDate,
        r.scannedLanguages,
        r.unscannedLanguages,
        r.openAlerts,
        `"${r.analysisError}"`,
        `"${r.analysisWarning}"`
      ];
      if (config.checkWorkflows) row.push(r.workflowStatus);
      return row.join(',');
    })].join('\n');

    fs.writeFileSync(filename, csv);
    console.error(`  - ${description}: ${filename} (${filtered.length} repos)`);
  };

  // Disabled repos (excluding archived repos since they can't be remediated)
  writeSubReport(
    `${baseName}-disabled.csv`,
    r => !r.isArchived && ['Disabled', 'No', 'Requires GHAS', 'No Scans'].includes(r.codeqlEnabled),
    'Disabled/Not scanning'
  );

  // Stale repos (modified >90 days after last scan)
  writeSubReport(
    `${baseName}-stale.csv`,
    r => {
      if (r.lastScanDate === 'Never' || !r.lastUpdated) return false;
      const scanDate = new Date(r.lastScanDate);
      const cutoffDate = new Date(scanDate);
      cutoffDate.setDate(cutoffDate.getDate() + 90);
      return new Date(r.lastUpdated) > cutoffDate;
    },
    'Stale scans (modified >90 days after scan)'
  );

  // Missing languages (only if already scanning)
  writeSubReport(
    `${baseName}-missing-languages.csv`,
    r => r.codeqlEnabled === 'Yes' && r.unscannedLanguages !== 'None' && r.unscannedLanguages !== 'N/A',
    'Missing CodeQL languages'
  );

  // Open alerts
  writeSubReport(
    `${baseName}-open-alerts.csv`,
    r => typeof r.openAlerts === 'number' && r.openAlerts > 0,
    'Repos with open alerts'
  );

  // Analysis issues
  writeSubReport(
    `${baseName}-analysis-issues.csv`,
    r => (r.analysisError && r.analysisError !== 'None') || (r.analysisWarning && r.analysisWarning !== 'None'),
    'Analysis errors/warnings'
  );
}

// Shuffle array (Fisher-Yates)
function shuffle(array) {
  const arr = [...array];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

// Main function
async function main() {
  const config = parseArgs();

  if (config.help) {
    showHelp();
    process.exit(0);
  }

  if (!config.org) {
    console.error("ERROR: Organization name is required");
    console.error("Usage: node code-scanning-coverage-report.js <organization> [options]");
    console.error("Use --help for more information");
    process.exit(1);
  }

  const octokit = createOctokit();

  // Fetch repositories
  console.error(`Generating code scanning coverage report for: ${config.org}`);
  let repos;

  if (config.repo) {
    repos = await fetchSingleRepository(octokit, config.org, config.repo);
  } else {
    repos = await fetchRepositories(octokit, config.org);
    if (config.sample) {
      const totalAvailable = repos.length;
      repos = shuffle(repos).slice(0, SAMPLE_SIZE);
      console.error(`Sample mode: selecting ${SAMPLE_SIZE} random repos from ${totalAvailable} available`);
    }
  }

  // Process repositories
  const results = await processRepositories(octokit, config.org, repos, config);

  // Generate output
  const csv = generateCSV(results, config);

  if (config.output) {
    fs.writeFileSync(config.output, csv);
    console.error(`\nReport complete. Processed ${results.length} repositories.`);
    console.error(`Report saved to: ${config.output}`);
    generateSubReports(results, config.output, config);
  } else {
    console.log(csv);
    console.error(`\nReport complete. Processed ${results.length} repositories.`);
  }
}

main().catch(err => {
  console.error(`ERROR: ${err.message}`);
  process.exit(1);
});

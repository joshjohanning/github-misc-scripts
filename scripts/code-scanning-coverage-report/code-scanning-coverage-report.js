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
//   --check-workflow-status    Check CodeQL workflow run status (success/failure)
//   --check-unscanned-actions  Check if repos have Actions workflows not being scanned
//   --fetch-alerts        Fetch open alert counts (uses more API calls)
//   --concurrency <n>     Number of concurrent API calls (default: 10)
//   --help                Show help
//
// Environment Variables:
//   GITHUB_TOKEN                    GitHub PAT with repo scope (required if not using App auth)
//   GITHUB_API_URL                  API endpoint (defaults to https://api.github.com)
//
//   GitHub App Authentication (alternative to GITHUB_TOKEN, recommended for higher rate limits):
//   GITHUB_APP_ID                   GitHub App ID (numeric) or Client ID (starts with "Iv")
//   GITHUB_APP_PRIVATE_KEY_PATH     Path to GitHub App private key file (.pem)
//   GITHUB_APP_INSTALLATION_ID      GitHub App installation ID for the organization
//
// Example:
//   node code-scanning-coverage-report.js my-org --output report.csv
//

import { Octokit } from "octokit";
import { createAppAuth } from "@octokit/auth-app";
import fs from 'fs';
import { fileURLToPath } from 'url';

// =============================================================================
// Configuration
// =============================================================================
const SAMPLE_SIZE = 25;
const DEFAULT_CONCURRENCY = 10;
const DEFAULT_STALE_DAYS = 90; // Days after last scan to consider repo stale

// CodeQL supported languages
const CODEQL_LANGUAGES = new Set([
  'c', 'c++', 'cpp', 'csharp', 'c#', 'go', 'java', 'kotlin',
  'javascript', 'typescript', 'python', 'ruby', 'swift'
]);

// API call counter
let apiCallCount = 0;

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

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const config = {
    org: null,
    output: null,
    repo: null,
    sample: false,
    checkWorkflowStatus: false,
    checkUnscannedActions: false,
    fetchAlerts: false,
    concurrency: DEFAULT_CONCURRENCY,
    staleDays: DEFAULT_STALE_DAYS,
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
      case '--output':
        config.output = getRequiredValue('--output', ++i);
        break;
      case '--repo':
        config.repo = getRequiredValue('--repo', ++i);
        break;
      case '--sample':
        config.sample = true;
        break;
      case '--check-workflow-status':
        config.checkWorkflowStatus = true;
        break;
      case '--check-unscanned-actions':
        config.checkUnscannedActions = true;
        break;
      case '--fetch-alerts':
        config.fetchAlerts = true;
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
      case '--stale-days': {
        const value = getRequiredValue('--stale-days', ++i);
        const parsed = parseInt(value, 10);
        if (isNaN(parsed) || parsed < 1) {
          console.error(`ERROR: --stale-days must be a positive number`);
          process.exit(1);
        }
        config.staleDays = parsed;
        break;
      }
      default:
        if (!arg.startsWith('-')) {
          config.org = arg;
        } else {
          console.error(`ERROR: Unknown option: ${arg}`);
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
  --check-workflow-status    Check CodeQL workflow run status (success/failure)
  --check-unscanned-actions  Check if repos have Actions workflows not being scanned
  --fetch-alerts        Fetch open alert counts (uses more API calls)
  --concurrency <n>     Number of concurrent API calls (default: ${DEFAULT_CONCURRENCY})
  --stale-days <n>      Days after last scan to consider repo stale (default: ${DEFAULT_STALE_DAYS})
  --help                Show this help message

Environment Variables:
  GITHUB_TOKEN          GitHub token with repo scope (required)
  GITHUB_API_URL        API endpoint (defaults to https://api.github.com)

Examples:
  node code-scanning-coverage-report.js my-org
  node code-scanning-coverage-report.js my-org --output report.csv
  node code-scanning-coverage-report.js my-org --repo my-repo
  node code-scanning-coverage-report.js my-org --sample --output sample.csv
  node code-scanning-coverage-report.js my-org --check-workflow-status --check-unscanned-actions

Output Columns:
  - Repository: Repository name
  - Default Branch: The default branch of the repository
  - Last Updated: When the repository was last updated
  - Languages: Languages detected in the repository
  - CodeQL Enabled: Yes / No Scans / Disabled / Requires GHAS / No
  - Last Default Branch Scan Date: Date of most recent scan on default branch
  - Scanned Languages: Languages scanned by CodeQL
  - Unscanned CodeQL Languages: CodeQL-supported languages not being scanned
  - Open Alerts: Total number of open code scanning alerts
  - Critical Alerts: Number of open critical severity alerts
  - Analysis Errors: Errors from most recent analysis
  - Analysis Warnings: Warnings from most recent analysis
  - Workflow Status: (with --check-workflow-status) CodeQL workflow run status

Sub-reports (generated with --output):
  - *-disabled.csv: Repos with CodeQL disabled or no scans
  - *-stale.csv: Repos modified after last scan (configurable with --stale-days)
  - *-missing-languages.csv: Repos scanning but missing some CodeQL languages
  - *-critical-alerts.csv: Repos with open critical severity alerts
  - *-analysis-issues.csv: Repos with analysis errors or warnings

API Usage:
  Default options use ~2 API calls per repository. With GitHub App auth
  (15,000 requests/hour), this supports organizations up to ~7,500 repos.
  Optional flags like --fetch-alerts and --check-workflow-status increase API usage.
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

    const octokit = new Octokit({
      authStrategy: createAppAuth,
      auth: {
        appId: appId,
        privateKey,
        installationId: parseInt(installationId, 10)
      },
      baseUrl,
      throttle: {
        onRateLimit: (retryAfter, _options, _octokit) => {
          console.error(`Rate limit hit, retrying after ${retryAfter} seconds...`);
          return true;
        },
        onSecondaryRateLimit: (retryAfter, _options, _octokit) => {
          console.error(`Secondary rate limit hit, retrying after ${retryAfter} seconds...`);
          return true;
        }
      }
    });

    // Add hook to count API calls
    octokit.hook.before('request', () => {
      apiCallCount++;
    });

    return octokit;
  }

  // Fall back to token authentication
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    console.error("ERROR: Authentication required. Set either:");
    console.error("  - GITHUB_TOKEN environment variable, or");
    console.error("  - GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY_PATH, and GITHUB_APP_INSTALLATION_ID");
    process.exit(1);
  }

  const octokit = new Octokit({
    auth: token,
    baseUrl,
    throttle: {
      onRateLimit: (retryAfter, _options, _octokit) => {
        console.error(`Rate limit hit, retrying after ${retryAfter} seconds...`);
        return true;
      },
      onSecondaryRateLimit: (retryAfter, _options, _octokit) => {
        console.error(`Secondary rate limit hit, retrying after ${retryAfter} seconds...`);
        return true;
      }
    }
  });

  // Add hook to count API calls
  octokit.hook.before('request', () => {
    apiCallCount++;
  });

  return octokit;
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
            languages(first: 20) {
              nodes {
                name
              }
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
      defaultBranch: repo.defaultBranchRef?.name || 'main',
      languages: repo.languages?.nodes?.map(l => l.name) || []
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
        languages(first: 20) {
          nodes {
            name
          }
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
    defaultBranch: repo.defaultBranchRef?.name || 'main',
    languages: repo.languages?.nodes?.map(l => l.name) || []
  }];
}

// Check CodeQL/code scanning status
async function checkCodeQLStatus(octokit, org, repo, isArchived = false) {
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
      // Archived repos return 403 - not actionable, so mark as N/A
      if (isArchived) {
        return 'N/A';
      }
      return 'Disabled';
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

// Get alert counts (total open and critical)
async function fetchAlertCounts(octokit, org, repo) {
  try {
    let totalOpen = 0;
    let critical = 0;
    for await (const response of octokit.paginate.iterator(
      octokit.rest.codeScanning.listAlertsForRepo,
      { owner: org, repo, state: 'open', per_page: 100 }
    )) {
      totalOpen += response.data.length;
      critical += response.data.filter(a => a.rule?.security_severity_level === 'critical').length;
    }
    return { totalOpen, critical };
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
  // Languages are now fetched in the initial GraphQL query
  const languages = repo.languages || [];

  const [codeqlStatus, scanningInfo, alertCounts, hasWorkflows, workflowStatus] = await Promise.all([
    checkCodeQLStatus(octokit, org, repo.name, repo.isArchived),
    fetchScanningInfo(octokit, org, repo.name, repo.defaultBranch),
    config.fetchAlerts ? fetchAlertCounts(octokit, org, repo.name) : Promise.resolve(null),
    config.checkUnscannedActions ? hasGitHubWorkflows(octokit, org, repo.name) : Promise.resolve(false),
    config.checkWorkflowStatus ? fetchCodeQLWorkflowStatus(octokit, org, repo.name) : Promise.resolve(null)
  ]);

  const unscanned = getUnscannedLanguages(
    languages,
    scanningInfo.scannedLanguages,
    hasWorkflows,
    config.checkUnscannedActions
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
    openAlerts: alertCounts === null ? 'N/A' : alertCounts.totalOpen,
    criticalAlerts: alertCounts === null ? 'N/A' : alertCounts.critical,
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
        const pct = Math.round((num / total) * 100);
        process.stderr.write(`[${num}/${total}] (${pct}%) Processing: ${repo.name}\n`);
        return processRepository(octokit, org, repo, config);
      })
    );
    results.push(...batchResults);
  }

  return results;
}

// Escape CSV field (handles commas, quotes, newlines)
function escapeCSV(value) {
  const str = String(value ?? '');
  if (str.includes(',') || str.includes('"') || str.includes('\n')) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

// Build a CSV row from a result object
function buildCSVRow(r, config) {
  const row = [
    escapeCSV(r.repository),
    escapeCSV(r.defaultBranch),
    r.lastUpdated,
    r.isArchived ? 'Yes' : 'No',
    escapeCSV(r.languages),
    r.codeqlEnabled,
    r.lastScanDate,
    escapeCSV(r.scannedLanguages),
    escapeCSV(r.unscannedLanguages),
    r.openAlerts,
    r.criticalAlerts,
    escapeCSV(r.analysisError),
    escapeCSV(r.analysisWarning)
  ];
  if (config.checkWorkflowStatus) {
    row.push(r.workflowStatus);
  }
  return row.join(',');
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
    'Critical Alerts',
    'Analysis Errors',
    'Analysis Warnings'
  ];

  if (config.checkWorkflowStatus) {
    headers.push('Workflow Status');
  }

  const rows = results.map(r => buildCSVRow(r, config));
  return [headers.join(','), ...rows].join('\n');
}

// Generate sub-reports
function generateSubReports(results, outputFile, config) {
  const baseName = outputFile.replace(/\.csv$/, '');
  const headers = generateCSV([], config).split('\n')[0];
  const staleDays = config.staleDays;

  // Helper to write sub-report (skips if no matching repos)
  const writeSubReport = (filename, filter, description) => {
    const filtered = results.filter(filter);
    if (filtered.length === 0) return; // Skip empty sub-reports
    const csv = [headers, ...filtered.map(r => buildCSVRow(r, config))].join('\n');
    fs.writeFileSync(filename, csv);
    console.error(`  - ${description}: ${filename} (${filtered.length} repos)`);
  };

  // Disabled repos (excluding archived repos since they can't be remediated)
  writeSubReport(
    `${baseName}-disabled.csv`,
    r => !r.isArchived && ['Disabled', 'No', 'Requires GHAS', 'No Scans'].includes(r.codeqlEnabled),
    'Disabled/Not scanning'
  );

  // Stale repos (modified after last scan by configured days)
  writeSubReport(
    `${baseName}-stale.csv`,
    r => {
      if (r.lastScanDate === 'Never' || !r.lastUpdated) return false;
      const scanDate = new Date(r.lastScanDate);
      const cutoffDate = new Date(scanDate);
      cutoffDate.setDate(cutoffDate.getDate() + staleDays);
      return new Date(r.lastUpdated) > cutoffDate;
    },
    `Stale scans (modified >${staleDays} days after scan)`
  );

  // Missing languages (only if already scanning)
  writeSubReport(
    `${baseName}-missing-languages.csv`,
    r => r.codeqlEnabled === 'Yes' && r.unscannedLanguages !== 'None' && r.unscannedLanguages !== 'N/A',
    'Missing CodeQL languages'
  );

  // Critical alerts
  writeSubReport(
    `${baseName}-critical-alerts.csv`,
    r => typeof r.criticalAlerts === 'number' && r.criticalAlerts > 0,
    'Repos with critical alerts'
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

  if (config.sample && config.repo) {
    console.error("ERROR: --sample and --repo cannot be used together");
    process.exit(1);
  }

  const octokit = createOctokit();

  // Display rate limit info
  const { data: rateLimit } = await octokit.rest.rateLimit.get();
  const core = rateLimit.resources.core;
  const resetTime = new Date(core.reset * 1000).toLocaleTimeString();
  console.error(`Rate limit: ${core.remaining}/${core.limit} remaining (resets at ${resetTime})`);

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

  // Generate summary statistics
  const summary = results.reduce((acc, r) => {
    acc[r.codeqlEnabled] = (acc[r.codeqlEnabled] || 0) + 1;
    if (r.isArchived) acc.archived = (acc.archived || 0) + 1;
    // Count stale repos (modified after last scan by configured days)
    if (r.lastScanDate !== 'Never' && r.lastUpdated) {
      const scanDate = new Date(r.lastScanDate);
      const cutoffDate = new Date(scanDate);
      cutoffDate.setDate(cutoffDate.getDate() + config.staleDays);
      if (new Date(r.lastUpdated) > cutoffDate) {
        acc.stale = (acc.stale || 0) + 1;
      }
    }
    // Count repos with missing languages (only if already scanning)
    if (r.codeqlEnabled === 'Yes' && r.unscannedLanguages !== 'None' && r.unscannedLanguages !== 'N/A') {
      acc.missingLanguages = (acc.missingLanguages || 0) + 1;
    }
    // Count repos with critical alerts
    if (typeof r.criticalAlerts === 'number' && r.criticalAlerts > 0) {
      acc.criticalAlerts = (acc.criticalAlerts || 0) + 1;
    }
    // Count repos with analysis issues
    if ((r.analysisError && r.analysisError !== 'None') || (r.analysisWarning && r.analysisWarning !== 'None')) {
      acc.analysisIssues = (acc.analysisIssues || 0) + 1;
    }
    return acc;
  }, {});

  const summaryParts = [];
  if (summary['Yes']) summaryParts.push(`${summary['Yes']} enabled`);
  if (summary['No Scans']) summaryParts.push(`${summary['No Scans']} no scans`);
  if (summary['Disabled']) summaryParts.push(`${summary['Disabled']} disabled`);
  if (summary['Requires GHAS']) summaryParts.push(`${summary['Requires GHAS']} requires GHAS`);
  if (summary['Unknown']) summaryParts.push(`${summary['Unknown']} unknown`);
  if (summary.archived) summaryParts.push(`${summary.archived} archived`);
  if (summary.stale) summaryParts.push(`${summary.stale} stale`);
  if (summary.missingLanguages) summaryParts.push(`${summary.missingLanguages} missing languages`);
  if (summary.criticalAlerts) summaryParts.push(`${summary.criticalAlerts} with critical alerts`);
  if (summary.analysisIssues) summaryParts.push(`${summary.analysisIssues} analysis issues`);

  if (config.output) {
    fs.writeFileSync(config.output, csv);
    console.error(`\nReport complete. Processed ${results.length} repositories.`);
    console.error(`Summary: ${summaryParts.join(', ')}`);
    console.error(`Report saved to: ${config.output}`);
    generateSubReports(results, config.output, config);
  } else {
    console.log(csv);
    console.error(`\nReport complete. Processed ${results.length} repositories.`);
    console.error(`Summary: ${summaryParts.join(', ')}`);
  }

  // Display API call count
  console.error(`API calls used: ${apiCallCount}`);
}

// Only run main() if this is the entry point (not being imported for testing)
const isMainModule = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMainModule) {
  main().catch(err => {
    console.error(`ERROR: ${err.message}`);
    process.exit(1);
  });
}

// Export functions for testing
export {
  checkCodeQLStatus,
  fetchScanningInfo,
  fetchAlertCounts,
  hasGitHubWorkflows,
  fetchCodeQLWorkflowStatus,
  isCodeQLLanguage,
  getUnscannedLanguages,
  processRepository,
  processRepositories,
  escapeCSV,
  buildCSVRow,
  generateCSV,
  generateSubReports,
  CODEQL_LANGUAGES,
  LANGUAGE_NORMALIZE
};

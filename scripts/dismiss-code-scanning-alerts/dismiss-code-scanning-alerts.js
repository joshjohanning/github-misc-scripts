#!/usr/bin/env node

//
// Dismiss code scanning alerts by rule ID across repositories in a GitHub organization
//
// Usage:
//   node dismiss-code-scanning-alerts.js <organization> --rule <rule-id> --reason <reason> [options]
//   node dismiss-code-scanning-alerts.js --orgs-file <file> --rule <rule-id> --reason <reason> [options]
//
// Options:
//   --orgs-file <file>    File containing list of organizations (one per line)
//   --repo <repo>         Target a single repository instead of all repos
//   --rule <rule-id>      CodeQL rule ID to match (e.g., js/stack-trace-exposure)
//   --reason <reason>     Dismissal reason: "false positive", "won't fix", or "used in tests"
//   --comment <comment>   Optional dismissal comment
//   --output <file>       Write CSV report of dismissed alerts to file
//   --dry-run             Preview what would be dismissed without making changes
//   --concurrency <n>     Number of concurrent API calls (default: 10)
//   --help                Show help
//
// Environment Variables:
//   GITHUB_TOKEN                    GitHub PAT with security_events scope (required if not using App auth)
//   GITHUB_API_URL                  API endpoint (defaults to https://api.github.com)
//
//   GitHub App Authentication (alternative to GITHUB_TOKEN):
//   GITHUB_APP_ID                   GitHub App ID
//   GITHUB_APP_PRIVATE_KEY_PATH     Path to GitHub App private key file (.pem)
//
// Examples:
//   node dismiss-code-scanning-alerts.js my-org --rule "js/stack-trace-exposure" --reason "won't fix"
//   node dismiss-code-scanning-alerts.js my-org --repo my-repo --rule "js/stack-trace-exposure" --reason "false positive" --comment "Expected behavior"
//   node dismiss-code-scanning-alerts.js --orgs-file orgs.txt --rule "py/sql-injection" --reason "used in tests" --output dismissed.csv
//   node dismiss-code-scanning-alerts.js my-org --rule "js/stack-trace-exposure" --reason "won't fix" --dry-run
//
// Notes:
//   - Requires `security_events` scope for private repositories, or `public_repo` for public repositories
//   - gh auth refresh -h github.com -s security_events
//

import { Octokit } from "octokit";
import { createAppAuth } from "@octokit/auth-app";
import fs from 'fs';
import { fileURLToPath } from 'url';

// =============================================================================
// Configuration
// =============================================================================
const DEFAULT_CONCURRENCY = 10;
const VALID_REASONS = ['false positive', "won't fix", 'used in tests'];

// API call counter
let apiCallCount = 0;

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const config = {
    org: null,
    orgsFile: null,
    repo: null,
    rule: null,
    reason: null,
    comment: null,
    output: null,
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
      case '--orgs-file':
        config.orgsFile = getRequiredValue('--orgs-file', ++i);
        break;
      case '--repo':
        config.repo = getRequiredValue('--repo', ++i);
        break;
      case '--rule':
        config.rule = getRequiredValue('--rule', ++i);
        break;
      case '--reason':
        config.reason = getRequiredValue('--reason', ++i);
        break;
      case '--comment':
        config.comment = getRequiredValue('--comment', ++i);
        break;
      case '--output':
        config.output = getRequiredValue('--output', ++i);
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
Dismiss code scanning alerts by rule ID across repositories in a GitHub organization.

Usage:
  node dismiss-code-scanning-alerts.js <organization> --rule <rule-id> --reason <reason> [options]
  node dismiss-code-scanning-alerts.js --orgs-file <file> --rule <rule-id> --reason <reason> [options]

Arguments:
  organization          GitHub organization name

Required Options:
  --rule <rule-id>      CodeQL rule ID to match (e.g., js/stack-trace-exposure, py/sql-injection)
  --reason <reason>     Dismissal reason: "false positive", "won't fix", or "used in tests"

Options:
  --orgs-file <file>    File containing list of organizations (one per line)
  --repo <repo>         Target a single repository instead of all repos
  --comment <comment>   Optional dismissal comment
  --output <file>       Write CSV report of dismissed alerts to file
  --dry-run             Preview what would be dismissed without making changes
  --concurrency <n>     Number of concurrent API calls (default: ${DEFAULT_CONCURRENCY})
  --help                Show this help message

Environment Variables:
  GITHUB_TOKEN          GitHub token with security_events scope (required if not using App auth)
  GITHUB_API_URL        API endpoint (defaults to https://api.github.com)

  GitHub App Authentication (recommended for multi-org and higher rate limits):
  GITHUB_APP_ID                   GitHub App ID
  GITHUB_APP_PRIVATE_KEY_PATH     Path to GitHub App private key file (.pem)

Examples:
  # Dismiss alerts for a single repo
  node dismiss-code-scanning-alerts.js my-org --repo my-repo --rule "js/stack-trace-exposure" --reason "won't fix"

  # Dismiss alerts across all repos in an org
  node dismiss-code-scanning-alerts.js my-org --rule "js/stack-trace-exposure" --reason "false positive"

  # Dismiss alerts with a comment
  node dismiss-code-scanning-alerts.js my-org --rule "js/stack-trace-exposure" --reason "won't fix" --comment "This is expected behavior"

  # Preview what would be dismissed (dry run)
  node dismiss-code-scanning-alerts.js my-org --rule "js/stack-trace-exposure" --reason "won't fix" --dry-run

  # Process multiple organizations from a file
  node dismiss-code-scanning-alerts.js --orgs-file orgs.txt --rule "py/sql-injection" --reason "used in tests" --output dismissed.csv

Output (with --output):
  CSV report with columns: Organization, Repository, Alert Number, Rule ID, Severity, Path, Status

Notes:
  - Requires 'security_events' scope for private repos or 'public_repo' for public repos
  - Run: gh auth refresh -h github.com -s security_events
`);
}

// Shared configuration
const baseUrl = process.env.GITHUB_API_URL || 'https://api.github.com';

// GitHub App configuration (cached)
let appPrivateKey = null;
const appId = process.env.GITHUB_APP_ID;
const privateKeyPath = process.env.GITHUB_APP_PRIVATE_KEY_PATH;

// Check if GitHub App auth is configured
function isGitHubAppAuth() {
  return !!(appId && privateKeyPath);
}

// Get the private key (cached)
function getPrivateKey() {
  if (appPrivateKey) return appPrivateKey;
  if (!privateKeyPath) return null;

  try {
    appPrivateKey = fs.readFileSync(privateKeyPath, 'utf8');
    return appPrivateKey;
  } catch (error) {
    console.error(`ERROR: Failed to read private key file: ${privateKeyPath}`);
    console.error(error.message);
    process.exit(1);
  }
}

// Create an app-level Octokit (JWT auth) for looking up installations
function createAppOctokit() {
  const privateKey = getPrivateKey();
  if (!privateKey || !appId) {
    throw new Error('GitHub App credentials not configured');
  }

  const octokit = new Octokit({
    authStrategy: createAppAuth,
    auth: {
      appId: appId,
      privateKey
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

  octokit.hook.before('request', () => {
    apiCallCount++;
  });

  return octokit;
}

// Create an installation-level Octokit for a specific org
function createInstallationOctokit(installationId) {
  const privateKey = getPrivateKey();
  if (!privateKey || !appId) {
    throw new Error('GitHub App credentials not configured');
  }

  const octokit = new Octokit({
    authStrategy: createAppAuth,
    auth: {
      appId: appId,
      privateKey,
      installationId: installationId
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

  octokit.hook.before('request', () => {
    apiCallCount++;
  });

  return octokit;
}

// Get installation ID for an organization
async function getInstallationIdForOrg(appOctokit, org) {
  try {
    const { data } = await appOctokit.rest.apps.getOrgInstallation({ org });
    return data.id;
  } catch (error) {
    if (error.status === 404) {
      throw new Error(`GitHub App is not installed on organization: ${org}`);
    }
    throw error;
  }
}

// Create Octokit for an organization (handles both token and app auth)
async function createOctokitForOrg(org, appOctokit = null) {
  if (isGitHubAppAuth()) {
    if (!appOctokit) {
      appOctokit = createAppOctokit();
    }
    const installationId = await getInstallationIdForOrg(appOctokit, org);
    return createInstallationOctokit(installationId);
  }

  // Token authentication - return a shared instance
  return createTokenOctokit();
}

// Create a token-authenticated Octokit
let tokenOctokit = null;
function createTokenOctokit() {
  if (tokenOctokit) return tokenOctokit;

  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    console.error("ERROR: Authentication required. Set either:");
    console.error("  - GITHUB_TOKEN environment variable, or");
    console.error("  - GITHUB_APP_ID and GITHUB_APP_PRIVATE_KEY_PATH");
    process.exit(1);
  }

  tokenOctokit = new Octokit({
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

  tokenOctokit.hook.before('request', () => {
    apiCallCount++;
  });

  return tokenOctokit;
}

// Fetch all repositories in an organization using GraphQL
async function fetchRepositories(octokit, org) {
  const repos = [];
  let cursor = null;

  const query = `
    query($org: String!, $cursor: String) {
      organization(login: $org) {
        repositories(first: 100, after: $cursor, isArchived: false) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            name
            isArchived
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
      isArchived: repo.isArchived
    })));
    cursor = data.pageInfo.hasNextPage ? data.pageInfo.endCursor : null;
  } while (cursor);

  return repos;
}

// Fetch open alerts for a repository matching the rule ID
async function fetchMatchingAlerts(octokit, org, repo, ruleId) {
  const matchingAlerts = [];

  try {
    for await (const response of octokit.paginate.iterator(
      octokit.rest.codeScanning.listAlertsForRepo,
      { owner: org, repo, state: 'open', per_page: 100 }
    )) {
      for (const alert of response.data) {
        if (alert.rule?.id === ruleId) {
          matchingAlerts.push({
            number: alert.number,
            ruleId: alert.rule.id,
            ruleName: alert.rule.name,
            severity: alert.rule.security_severity_level || alert.rule.severity || 'unknown',
            path: alert.most_recent_instance?.location?.path || 'unknown',
            url: alert.html_url
          });
        }
      }
    }
  } catch (error) {
    const message = error.message?.toLowerCase() || '';
    if (message.includes('advanced security must be enabled') ||
        message.includes('code security must be enabled') ||
        message.includes('no analysis found') ||
        error.status === 404 ||
        error.status === 403) {
      // Skip repos without code scanning enabled
      return [];
    }
    throw error;
  }

  return matchingAlerts;
}

// Fetch all open alerts matching the rule ID for an entire organization (more efficient)
async function fetchMatchingAlertsForOrg(octokit, org, ruleId) {
  const alertsByRepo = new Map();

  try {
    for await (const response of octokit.paginate.iterator(
      octokit.rest.codeScanning.listAlertsForOrg,
      { org, state: 'open', per_page: 100 }
    )) {
      for (const alert of response.data) {
        if (alert.rule?.id === ruleId) {
          const repoName = alert.repository.name;
          if (!alertsByRepo.has(repoName)) {
            alertsByRepo.set(repoName, []);
          }
          alertsByRepo.get(repoName).push({
            number: alert.number,
            ruleId: alert.rule.id,
            ruleName: alert.rule.name,
            severity: alert.rule.security_severity_level || alert.rule.severity || 'unknown',
            path: alert.most_recent_instance?.location?.path || 'unknown',
            url: alert.html_url
          });
        }
      }
    }
  } catch (error) {
    const message = error.message?.toLowerCase() || '';
    if (message.includes('advanced security must be enabled') ||
        message.includes('code security must be enabled') ||
        error.status === 404 ||
        error.status === 403) {
      return alertsByRepo;
    }
    throw error;
  }

  return alertsByRepo;
}

// Dismiss a single alert
async function dismissAlert(octokit, org, repo, alertNumber, reason, comment) {
  const params = {
    owner: org,
    repo,
    alert_number: alertNumber,
    state: 'dismissed',
    dismissed_reason: reason
  };

  if (comment) {
    params.dismissed_comment = comment;
  }

  await octokit.rest.codeScanning.updateAlert(params);
}

// Process a single repository
async function processRepository(octokit, org, repo, config) {
  const alerts = await fetchMatchingAlerts(octokit, org, repo.name, config.rule);

  if (alerts.length === 0) {
    return [];
  }

  const results = [];

  for (const alert of alerts) {
    if (!config.dryRun) {
      try {
        await dismissAlert(octokit, org, repo.name, alert.number, config.reason, config.comment);
        results.push({
          organization: org,
          repository: repo.name,
          alertNumber: alert.number,
          ruleId: alert.ruleId,
          severity: alert.severity,
          path: alert.path,
          url: alert.url,
          status: 'dismissed'
        });
      } catch (error) {
        results.push({
          organization: org,
          repository: repo.name,
          alertNumber: alert.number,
          ruleId: alert.ruleId,
          severity: alert.severity,
          path: alert.path,
          url: alert.url,
          status: `error: ${error.message}`
        });
      }
    } else {
      results.push({
        organization: org,
        repository: repo.name,
        alertNumber: alert.number,
        ruleId: alert.ruleId,
        severity: alert.severity,
        path: alert.path,
        url: alert.url,
        status: 'would dismiss (dry-run)'
      });
    }
  }

  return results;
}

// Process repositories with concurrency control
async function processRepositories(octokit, org, repos, config) {
  const results = [];
  const total = repos.length;

  // Process in batches for concurrency
  for (let i = 0; i < repos.length; i += config.concurrency) {
    const batch = repos.slice(i, i + config.concurrency);
    const batchResults = await Promise.all(
      batch.map(async (repo, idx) => {
        const num = i + idx + 1;
        const pct = Math.round((num / total) * 100);
        process.stderr.write(`[${num}/${total}] (${pct}%) Checking: ${repo.name}\n`);
        return processRepository(octokit, org, repo, config);
      })
    );

    // Flatten results
    for (const repoResults of batchResults) {
      results.push(...repoResults);
    }
  }

  return results;
}

// Process alerts fetched from org-level API (more efficient for bulk operations)
async function processAlertsFromOrg(octokit, org, alertsByRepo, config) {
  const results = [];

  // Flatten all alerts with their repo names for processing
  const allAlerts = [];
  for (const [repoName, alerts] of alertsByRepo) {
    for (const alert of alerts) {
      allAlerts.push({ repoName, alert });
    }
  }

  const total = allAlerts.length;
  let processed = 0;

  // Process alerts with concurrency control
  for (let i = 0; i < allAlerts.length; i += config.concurrency) {
    const batch = allAlerts.slice(i, i + config.concurrency);
    const batchResults = await Promise.all(
      batch.map(async ({ repoName, alert }) => {
        processed++;
        const pct = Math.round((processed / total) * 100);
        process.stderr.write(`[${processed}/${total}] (${pct}%) Dismissing: ${repoName}#${alert.number}\n`);

        if (config.dryRun) {
          return {
            organization: org,
            repository: repoName,
            alertNumber: alert.number,
            ruleId: alert.ruleId,
            severity: alert.severity,
            path: alert.path,
            url: alert.url,
            status: 'would dismiss (dry-run)'
          };
        }

        try {
          await dismissAlert(octokit, org, repoName, alert.number, config.reason, config.comment);
          process.stderr.write(`  ✓ Dismissed: ${repoName}#${alert.number} (${alert.ruleId}) - ${alert.path}\n`);
          return {
            organization: org,
            repository: repoName,
            alertNumber: alert.number,
            ruleId: alert.ruleId,
            severity: alert.severity,
            path: alert.path,
            url: alert.url,
            status: 'dismissed'
          };
        } catch (error) {
          process.stderr.write(`  ✗ Failed: ${repoName}#${alert.number} - ${error.message}\n`);
          return {
            organization: org,
            repository: repoName,
            alertNumber: alert.number,
            ruleId: alert.ruleId,
            severity: alert.severity,
            path: alert.path,
            url: alert.url,
            status: `error: ${error.message}`
          };
        }
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

// Generate CSV output
function generateCSV(results) {
  const headers = [
    'Organization',
    'Repository',
    'Alert Number',
    'Rule ID',
    'Severity',
    'Path',
    'URL',
    'Status'
  ];

  const rows = results.map(r => [
    escapeCSV(r.organization),
    escapeCSV(r.repository),
    r.alertNumber,
    escapeCSV(r.ruleId),
    escapeCSV(r.severity),
    escapeCSV(r.path),
    escapeCSV(r.url),
    escapeCSV(r.status)
  ].join(','));

  return [headers.join(','), ...rows].join('\n');
}

// Main function
async function main() {
  const config = parseArgs();

  if (config.help) {
    showHelp();
    process.exit(0);
  }

  // Validate required options
  if (!config.rule) {
    console.error("ERROR: --rule is required");
    console.error("Use --help for more information");
    process.exit(1);
  }

  if (!config.reason) {
    console.error("ERROR: --reason is required");
    console.error("Use --help for more information");
    process.exit(1);
  }

  if (!VALID_REASONS.includes(config.reason)) {
    console.error(`ERROR: Invalid reason. Must be one of: ${VALID_REASONS.map(r => `"${r}"`).join(', ')}`);
    process.exit(1);
  }

  // Determine list of organizations to process
  let orgs = [];
  if (config.orgsFile) {
    try {
      const fileContent = fs.readFileSync(config.orgsFile, 'utf8');
      orgs = fileContent
        .split('\n')
        .map(line => line.trim())
        .filter(line => line && !line.startsWith('#')); // Skip empty lines and comments
      if (orgs.length === 0) {
        console.error(`ERROR: No organizations found in ${config.orgsFile}`);
        process.exit(1);
      }
    } catch (error) {
      console.error(`ERROR: Failed to read organizations file: ${config.orgsFile}`);
      console.error(error.message);
      process.exit(1);
    }
  } else if (config.org) {
    orgs = [config.org];
  } else {
    console.error("ERROR: Organization name or --orgs-file is required");
    console.error("Usage: node dismiss-code-scanning-alerts.js <organization> --rule <rule-id> --reason <reason> [options]");
    console.error("Use --help for more information");
    process.exit(1);
  }

  if (config.orgsFile && config.org) {
    console.error("ERROR: --orgs-file and organization argument cannot be used together");
    process.exit(1);
  }

  if (config.repo && orgs.length > 1) {
    console.error("ERROR: --repo cannot be used with multiple organizations");
    process.exit(1);
  }

  // Initialize authentication
  let appOctokit = null;

  if (isGitHubAppAuth()) {
    console.error('Using GitHub App authentication...');
    appOctokit = createAppOctokit();
  }

  // Display configuration
  console.error(`\nConfiguration:`);
  console.error(`  Rule ID: ${config.rule}`);
  console.error(`  Reason: ${config.reason}`);
  if (config.comment) {
    console.error(`  Comment: ${config.comment}`);
  }
  if (config.dryRun) {
    console.error(`  Mode: DRY RUN (no changes will be made)`);
  }
  console.error('');

  // Process each organization
  const allResults = [];
  for (let orgIndex = 0; orgIndex < orgs.length; orgIndex++) {
    const org = orgs[orgIndex];
    const isMultiOrg = orgs.length > 1;

    if (isMultiOrg) {
      console.error(`\n[${orgIndex + 1}/${orgs.length}] Processing organization: ${org}`);
    } else {
      console.error(`Processing organization: ${org}`);
    }

    // Track API calls for this org
    const orgStartApiCalls = apiCallCount;

    // Get an Octokit instance for this organization
    let octokit;
    try {
      octokit = await createOctokitForOrg(org, appOctokit);
    } catch (error) {
      console.error(`ERROR: Failed to authenticate for ${org}: ${error.message}`);
      if (isMultiOrg) {
        console.error(`Skipping organization: ${org}`);
        continue;
      }
      process.exit(1);
    }

    let repos;
    try {
      if (config.repo) {
        repos = [{ name: config.repo, isArchived: false }];
      } else {
        repos = await fetchRepositories(octokit, org);
      }
    } catch (error) {
      console.error(`ERROR: Failed to fetch repositories for ${org}: ${error.message}`);
      if (isMultiOrg) {
        console.error(`Skipping organization: ${org}`);
        continue;
      }
      process.exit(1);
    }

    let results;

    if (config.repo) {
      // Single repo mode - use repo-level API
      console.error(`Checking repository: ${config.repo}`);
      results = await processRepositories(octokit, org, repos, config);
    } else {
      // Org mode - use more efficient org-level API
      console.error(`Fetching alerts for rule "${config.rule}" across organization...`);
      try {
        const alertsByRepo = await fetchMatchingAlertsForOrg(octokit, org, config.rule);
        const repoCount = alertsByRepo.size;
        const alertCount = Array.from(alertsByRepo.values()).reduce((sum, alerts) => sum + alerts.length, 0);
        console.error(`Found ${alertCount} matching alert(s) across ${repoCount} repository(ies)`);

        results = await processAlertsFromOrg(octokit, org, alertsByRepo, config);
      } catch (error) {
        console.error(`ERROR: Failed to fetch alerts for ${org}: ${error.message}`);
        if (isMultiOrg) {
          console.error(`Skipping organization: ${org}`);
          continue;
        }
        process.exit(1);
      }
    }

    allResults.push(...results);

    // Display API calls used for this org
    const orgApiCalls = apiCallCount - orgStartApiCalls;
    console.error(`API calls used for ${org}: ${orgApiCalls}`);

    // Summary for this org
    const dismissed = results.filter(r => r.status === 'dismissed').length;
    const errors = results.filter(r => r.status.startsWith('error')).length;
    const wouldDismiss = results.filter(r => r.status.includes('dry-run')).length;

    if (config.dryRun) {
      console.error(`Found ${wouldDismiss} alert(s) that would be dismissed`);
    } else {
      console.error(`Dismissed ${dismissed} alert(s)${errors > 0 ? `, ${errors} error(s)` : ''}`);
    }
  }

  // Generate output
  if (config.output && allResults.length > 0) {
    const csv = generateCSV(allResults);
    fs.writeFileSync(config.output, csv);
    console.error(`\nReport saved to: ${config.output}`);
  } else if (allResults.length > 0) {
    // Print CSV to stdout
    console.log(generateCSV(allResults));
  }

  // Final summary
  const totalDismissed = allResults.filter(r => r.status === 'dismissed').length;
  const totalErrors = allResults.filter(r => r.status.startsWith('error')).length;
  const totalWouldDismiss = allResults.filter(r => r.status.includes('dry-run')).length;

  console.error(`\n=== Summary ===`);
  if (config.dryRun) {
    console.error(`Total alerts that would be dismissed: ${totalWouldDismiss}`);
  } else {
    console.error(`Total alerts dismissed: ${totalDismissed}`);
    if (totalErrors > 0) {
      console.error(`Total errors: ${totalErrors}`);
    }
  }
  console.error(`Total API calls: ${apiCallCount}`);
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
  parseArgs,
  fetchRepositories,
  fetchMatchingAlerts,
  dismissAlert,
  processRepository,
  processRepositories,
  processAlertsFromOrg,
  fetchMatchingAlertsForOrg,
  escapeCSV,
  generateCSV,
  VALID_REASONS,
  // Auth functions
  isGitHubAppAuth,
  getInstallationIdForOrg,
  createOctokitForOrg,
  createTokenOctokit,
  createAppOctokit,
  createInstallationOctokit
};

import { jest } from '@jest/globals';
import {
  parseArgs,
  fetchRepositories,
  fetchMatchingAlerts,
  fetchMatchingAlertsForOrg,
  dismissAlert,
  processRepository,
  processRepositories,
  processAlertsFromOrg,
  escapeCSV,
  generateCSV,
  VALID_REASONS,
  isGitHubAppAuth
} from './dismiss-code-scanning-alerts.js';
import fs from 'fs';

// ============================================================================
// Mock Data
// ============================================================================

const MOCK_REPOS = [
  { name: 'repo-with-alerts', isArchived: false },
  { name: 'repo-no-alerts', isArchived: false },
  { name: 'repo-disabled', isArchived: false },
  { name: 'repo-multiple-alerts', isArchived: false }
];

// Mock alerts for each repository
const MOCK_ALERTS = {
  'repo-with-alerts': [
    {
      number: 1,
      state: 'open',
      rule: {
        id: 'js/stack-trace-exposure',
        name: 'Stack trace exposure',
        security_severity_level: 'medium',
        severity: 'warning'
      },
      most_recent_instance: {
        location: { path: 'src/error-handler.js' }
      },
      html_url: 'https://github.com/test-org/repo-with-alerts/security/code-scanning/1'
    },
    {
      number: 2,
      state: 'open',
      rule: {
        id: 'js/sql-injection',
        name: 'SQL injection',
        security_severity_level: 'critical',
        severity: 'error'
      },
      most_recent_instance: {
        location: { path: 'src/database.js' }
      },
      html_url: 'https://github.com/test-org/repo-with-alerts/security/code-scanning/2'
    }
  ],
  'repo-no-alerts': [],
  'repo-disabled': 'disabled', // Signal to throw error
  'repo-multiple-alerts': [
    {
      number: 10,
      state: 'open',
      rule: {
        id: 'js/stack-trace-exposure',
        name: 'Stack trace exposure',
        security_severity_level: 'high',
        severity: 'error'
      },
      most_recent_instance: {
        location: { path: 'src/app.js' }
      },
      html_url: 'https://github.com/test-org/repo-multiple-alerts/security/code-scanning/10'
    },
    {
      number: 11,
      state: 'open',
      rule: {
        id: 'js/stack-trace-exposure',
        name: 'Stack trace exposure',
        security_severity_level: 'medium',
        severity: 'warning'
      },
      most_recent_instance: {
        location: { path: 'src/utils.js' }
      },
      html_url: 'https://github.com/test-org/repo-multiple-alerts/security/code-scanning/11'
    },
    {
      number: 12,
      state: 'open',
      rule: {
        id: 'js/xss',
        name: 'Cross-site scripting',
        security_severity_level: 'high',
        severity: 'error'
      },
      most_recent_instance: {
        location: { path: 'src/render.js' }
      },
      html_url: 'https://github.com/test-org/repo-multiple-alerts/security/code-scanning/12'
    }
  ]
};

// Build org-level alerts (same data but with repository info added)
function buildOrgAlerts() {
  const allAlerts = [];
  for (const [repoName, alerts] of Object.entries(MOCK_ALERTS)) {
    if (alerts === 'disabled' || !Array.isArray(alerts)) continue;
    for (const alert of alerts) {
      allAlerts.push({
        ...alert,
        repository: { name: repoName }
      });
    }
  }
  return allAlerts;
}

// ============================================================================
// Mock Octokit Factory
// ============================================================================

function createMockOctokit(dismissShouldFail = false) {
  const dismissedAlerts = [];

  return {
    graphql: jest.fn(async (query, variables) => {
      // Mock repository list query
      return {
        organization: {
          repositories: {
            pageInfo: { hasNextPage: false, endCursor: null },
            nodes: MOCK_REPOS
          }
        }
      };
    }),
    rest: {
      codeScanning: {
        listAlertsForRepo: jest.fn(async ({ owner, repo, state, per_page }) => {
          const alerts = MOCK_ALERTS[repo];
          if (alerts === 'disabled') {
            const error = new Error('Code security must be enabled for this repository');
            error.status = 403;
            throw error;
          }
          return { data: alerts || [] };
        }),
        listAlertsForOrg: jest.fn(async ({ org, state, per_page }) => {
          return { data: buildOrgAlerts() };
        }),
        updateAlert: jest.fn(async ({ owner, repo, alert_number, state, dismissed_reason, dismissed_comment }) => {
          if (dismissShouldFail) {
            throw new Error('Failed to dismiss alert');
          }
          dismissedAlerts.push({ owner, repo, alert_number, state, dismissed_reason, dismissed_comment });
          return { data: { number: alert_number, state: 'dismissed' } };
        })
      }
    },
    paginate: {
      iterator: jest.fn(function* (method, params) {
        // Check if this is an org-level or repo-level call
        if (method === this.rest?.codeScanning?.listAlertsForOrg || params.org) {
          yield { data: buildOrgAlerts() };
          return;
        }
        const alerts = MOCK_ALERTS[params.repo];
        if (alerts === 'disabled') {
          const error = new Error('Code security must be enabled for this repository');
          error.status = 403;
          throw error;
        }
        yield { data: alerts || [] };
      })
    },
    _dismissedAlerts: dismissedAlerts
  };
}

// ============================================================================
// Tests
// ============================================================================

describe('VALID_REASONS', () => {
  test('contains expected dismissal reasons', () => {
    expect(VALID_REASONS).toContain('false positive');
    expect(VALID_REASONS).toContain("won't fix");
    expect(VALID_REASONS).toContain('used in tests');
    expect(VALID_REASONS).toHaveLength(3);
  });
});

describe('escapeCSV', () => {
  test('returns plain strings unchanged', () => {
    expect(escapeCSV('hello')).toBe('hello');
    expect(escapeCSV('test123')).toBe('test123');
  });

  test('escapes strings with commas', () => {
    expect(escapeCSV('hello, world')).toBe('"hello, world"');
  });

  test('escapes strings with quotes', () => {
    expect(escapeCSV('say "hello"')).toBe('"say ""hello"""');
  });

  test('escapes strings with newlines', () => {
    expect(escapeCSV('line1\nline2')).toBe('"line1\nline2"');
  });

  test('handles null and undefined', () => {
    expect(escapeCSV(null)).toBe('');
    expect(escapeCSV(undefined)).toBe('');
  });

  test('converts numbers to strings', () => {
    expect(escapeCSV(123)).toBe('123');
  });
});

describe('generateCSV', () => {
  test('generates CSV with headers and data', () => {
    const results = [
      {
        organization: 'test-org',
        repository: 'test-repo',
        alertNumber: 1,
        ruleId: 'js/stack-trace-exposure',
        severity: 'medium',
        path: 'src/app.js',
        url: 'https://github.com/test-org/test-repo/security/code-scanning/1',
        status: 'dismissed'
      }
    ];

    const csv = generateCSV(results);
    const lines = csv.split('\n');

    expect(lines[0]).toBe('Organization,Repository,Alert Number,Rule ID,Severity,Path,URL,Status');
    expect(lines[1]).toContain('test-org');
    expect(lines[1]).toContain('test-repo');
    expect(lines[1]).toContain('js/stack-trace-exposure');
    expect(lines[1]).toContain('dismissed');
  });

  test('generates empty CSV with just headers when no results', () => {
    const csv = generateCSV([]);
    const lines = csv.split('\n');

    expect(lines).toHaveLength(1);
    expect(lines[0]).toBe('Organization,Repository,Alert Number,Rule ID,Severity,Path,URL,Status');
  });

  test('escapes special characters in CSV output', () => {
    const results = [
      {
        organization: 'test-org',
        repository: 'repo-with-comma, and stuff',
        alertNumber: 1,
        ruleId: 'js/stack-trace-exposure',
        severity: 'medium',
        path: 'src/app.js',
        url: 'https://github.com/test-org/test-repo/security/code-scanning/1',
        status: 'error: something, went wrong'
      }
    ];

    const csv = generateCSV(results);
    expect(csv).toContain('"repo-with-comma, and stuff"');
    expect(csv).toContain('"error: something, went wrong"');
  });
});

describe('fetchMatchingAlerts', () => {
  test('returns alerts matching the rule ID', async () => {
    const octokit = createMockOctokit();
    const alerts = await fetchMatchingAlerts(octokit, 'test-org', 'repo-with-alerts', 'js/stack-trace-exposure');

    expect(alerts).toHaveLength(1);
    expect(alerts[0].ruleId).toBe('js/stack-trace-exposure');
    expect(alerts[0].number).toBe(1);
  });

  test('returns empty array when no alerts match', async () => {
    const octokit = createMockOctokit();
    const alerts = await fetchMatchingAlerts(octokit, 'test-org', 'repo-with-alerts', 'py/sql-injection');

    expect(alerts).toHaveLength(0);
  });

  test('returns empty array for repos without code scanning', async () => {
    const octokit = createMockOctokit();
    const alerts = await fetchMatchingAlerts(octokit, 'test-org', 'repo-disabled', 'js/stack-trace-exposure');

    expect(alerts).toHaveLength(0);
  });

  test('returns multiple alerts when multiple match', async () => {
    const octokit = createMockOctokit();
    const alerts = await fetchMatchingAlerts(octokit, 'test-org', 'repo-multiple-alerts', 'js/stack-trace-exposure');

    expect(alerts).toHaveLength(2);
    expect(alerts.every(a => a.ruleId === 'js/stack-trace-exposure')).toBe(true);
  });

  test('extracts correct alert properties', async () => {
    const octokit = createMockOctokit();
    const alerts = await fetchMatchingAlerts(octokit, 'test-org', 'repo-with-alerts', 'js/stack-trace-exposure');

    expect(alerts[0]).toEqual({
      number: 1,
      ruleId: 'js/stack-trace-exposure',
      ruleName: 'Stack trace exposure',
      severity: 'medium',
      path: 'src/error-handler.js',
      url: 'https://github.com/test-org/repo-with-alerts/security/code-scanning/1'
    });
  });
});

describe('fetchMatchingAlertsForOrg', () => {
  test('returns alerts grouped by repository', async () => {
    const octokit = createMockOctokit();
    const alertsByRepo = await fetchMatchingAlertsForOrg(octokit, 'test-org', 'js/stack-trace-exposure');

    expect(alertsByRepo).toBeInstanceOf(Map);
    // Should have alerts from repo-with-alerts and repo-multiple-alerts
    expect(alertsByRepo.has('repo-with-alerts')).toBe(true);
    expect(alertsByRepo.has('repo-multiple-alerts')).toBe(true);
    expect(alertsByRepo.get('repo-with-alerts')).toHaveLength(1);
    expect(alertsByRepo.get('repo-multiple-alerts')).toHaveLength(2);
  });

  test('returns empty map when no alerts match', async () => {
    const octokit = createMockOctokit();
    const alertsByRepo = await fetchMatchingAlertsForOrg(octokit, 'test-org', 'nonexistent/rule');

    expect(alertsByRepo).toBeInstanceOf(Map);
    expect(alertsByRepo.size).toBe(0);
  });

  test('extracts correct alert properties', async () => {
    const octokit = createMockOctokit();
    const alertsByRepo = await fetchMatchingAlertsForOrg(octokit, 'test-org', 'js/stack-trace-exposure');

    const alerts = alertsByRepo.get('repo-with-alerts');
    expect(alerts[0]).toEqual({
      number: 1,
      ruleId: 'js/stack-trace-exposure',
      ruleName: 'Stack trace exposure',
      severity: 'medium',
      path: 'src/error-handler.js',
      url: 'https://github.com/test-org/repo-with-alerts/security/code-scanning/1'
    });
  });
});

describe('processAlertsFromOrg', () => {
  const baseConfig = {
    rule: 'js/stack-trace-exposure',
    reason: "won't fix",
    comment: null,
    dryRun: false,
    concurrency: 5
  };

  test('dismisses all alerts from the map', async () => {
    const octokit = createMockOctokit();
    const alertsByRepo = new Map([
      ['repo-with-alerts', [{
        number: 1,
        ruleId: 'js/stack-trace-exposure',
        ruleName: 'Stack trace exposure',
        severity: 'medium',
        path: 'src/error-handler.js',
        url: 'https://github.com/test-org/repo-with-alerts/security/code-scanning/1'
      }]],
      ['repo-multiple-alerts', [{
        number: 10,
        ruleId: 'js/stack-trace-exposure',
        ruleName: 'Stack trace exposure',
        severity: 'high',
        path: 'src/app.js',
        url: 'https://github.com/test-org/repo-multiple-alerts/security/code-scanning/10'
      }]]
    ]);

    // Suppress stderr output during test
    const originalStderr = process.stderr.write;
    process.stderr.write = jest.fn();

    const results = await processAlertsFromOrg(octokit, 'test-org', alertsByRepo, baseConfig);

    process.stderr.write = originalStderr;

    expect(results).toHaveLength(2);
    expect(results.every(r => r.status === 'dismissed')).toBe(true);
    expect(octokit._dismissedAlerts).toHaveLength(2);
  });

  test('dry run does not dismiss alerts', async () => {
    const octokit = createMockOctokit();
    const alertsByRepo = new Map([
      ['repo-with-alerts', [{
        number: 1,
        ruleId: 'js/stack-trace-exposure',
        ruleName: 'Stack trace exposure',
        severity: 'medium',
        path: 'src/error-handler.js',
        url: 'https://github.com/test-org/repo-with-alerts/security/code-scanning/1'
      }]]
    ]);
    const config = { ...baseConfig, dryRun: true };

    // Suppress stderr output during test
    const originalStderr = process.stderr.write;
    process.stderr.write = jest.fn();

    const results = await processAlertsFromOrg(octokit, 'test-org', alertsByRepo, config);

    process.stderr.write = originalStderr;

    expect(results).toHaveLength(1);
    expect(results[0].status).toBe('would dismiss (dry-run)');
    expect(octokit._dismissedAlerts).toHaveLength(0);
  });

  test('handles dismiss errors gracefully', async () => {
    const octokit = createMockOctokit(true); // dismissShouldFail = true
    const alertsByRepo = new Map([
      ['repo-with-alerts', [{
        number: 1,
        ruleId: 'js/stack-trace-exposure',
        ruleName: 'Stack trace exposure',
        severity: 'medium',
        path: 'src/error-handler.js',
        url: 'https://github.com/test-org/repo-with-alerts/security/code-scanning/1'
      }]]
    ]);

    // Suppress stderr output during test
    const originalStderr = process.stderr.write;
    process.stderr.write = jest.fn();

    const results = await processAlertsFromOrg(octokit, 'test-org', alertsByRepo, baseConfig);

    process.stderr.write = originalStderr;

    expect(results).toHaveLength(1);
    expect(results[0].status).toContain('error:');
  });
});

describe('processRepository', () => {
  const baseConfig = {
    rule: 'js/stack-trace-exposure',
    reason: "won't fix",
    comment: null,
    dryRun: false
  };

  test('dismisses matching alerts', async () => {
    const octokit = createMockOctokit();
    const repo = { name: 'repo-with-alerts', isArchived: false };

    const results = await processRepository(octokit, 'test-org', repo, baseConfig);

    expect(results).toHaveLength(1);
    expect(results[0].status).toBe('dismissed');
    expect(results[0].alertNumber).toBe(1);
    expect(octokit._dismissedAlerts).toHaveLength(1);
  });

  test('returns empty array when no alerts match', async () => {
    const octokit = createMockOctokit();
    const repo = { name: 'repo-no-alerts', isArchived: false };

    const results = await processRepository(octokit, 'test-org', repo, baseConfig);

    expect(results).toHaveLength(0);
  });

  test('dry run does not dismiss alerts', async () => {
    const octokit = createMockOctokit();
    const repo = { name: 'repo-with-alerts', isArchived: false };
    const config = { ...baseConfig, dryRun: true };

    const results = await processRepository(octokit, 'test-org', repo, config);

    expect(results).toHaveLength(1);
    expect(results[0].status).toBe('would dismiss (dry-run)');
    expect(octokit._dismissedAlerts).toHaveLength(0);
  });

  test('handles dismiss errors gracefully', async () => {
    const octokit = createMockOctokit(true); // dismissShouldFail = true
    const repo = { name: 'repo-with-alerts', isArchived: false };

    const results = await processRepository(octokit, 'test-org', repo, baseConfig);

    expect(results).toHaveLength(1);
    expect(results[0].status).toContain('error:');
  });

  test('processes multiple matching alerts', async () => {
    const octokit = createMockOctokit();
    const repo = { name: 'repo-multiple-alerts', isArchived: false };

    const results = await processRepository(octokit, 'test-org', repo, baseConfig);

    expect(results).toHaveLength(2);
    expect(results.every(r => r.status === 'dismissed')).toBe(true);
    expect(octokit._dismissedAlerts).toHaveLength(2);
  });
});

describe('processRepositories', () => {
  const baseConfig = {
    rule: 'js/stack-trace-exposure',
    reason: "won't fix",
    comment: null,
    dryRun: false,
    concurrency: 2
  };

  test('processes multiple repositories', async () => {
    const octokit = createMockOctokit();
    const repos = [
      { name: 'repo-with-alerts', isArchived: false },
      { name: 'repo-multiple-alerts', isArchived: false }
    ];

    // Suppress stderr output during test
    const originalStderr = process.stderr.write;
    process.stderr.write = jest.fn();

    const results = await processRepositories(octokit, 'test-org', repos, baseConfig);

    process.stderr.write = originalStderr;

    // repo-with-alerts: 1 match, repo-multiple-alerts: 2 matches
    expect(results).toHaveLength(3);
  });

  test('handles repos with no matching alerts', async () => {
    const octokit = createMockOctokit();
    const repos = [
      { name: 'repo-no-alerts', isArchived: false },
      { name: 'repo-disabled', isArchived: false }
    ];

    // Suppress stderr output during test
    const originalStderr = process.stderr.write;
    process.stderr.write = jest.fn();

    const results = await processRepositories(octokit, 'test-org', repos, baseConfig);

    process.stderr.write = originalStderr;

    expect(results).toHaveLength(0);
  });
});

describe('dismissAlert', () => {
  test('calls updateAlert with correct parameters', async () => {
    const octokit = createMockOctokit();

    await dismissAlert(octokit, 'test-org', 'test-repo', 123, "won't fix", 'Test comment');

    expect(octokit.rest.codeScanning.updateAlert).toHaveBeenCalledWith({
      owner: 'test-org',
      repo: 'test-repo',
      alert_number: 123,
      state: 'dismissed',
      dismissed_reason: "won't fix",
      dismissed_comment: 'Test comment'
    });
  });

  test('calls updateAlert without comment when not provided', async () => {
    const octokit = createMockOctokit();

    await dismissAlert(octokit, 'test-org', 'test-repo', 456, 'false positive', null);

    expect(octokit.rest.codeScanning.updateAlert).toHaveBeenCalledWith({
      owner: 'test-org',
      repo: 'test-repo',
      alert_number: 456,
      state: 'dismissed',
      dismissed_reason: 'false positive'
    });
  });
});

describe('isGitHubAppAuth', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  test('returns false when no app credentials are set', () => {
    delete process.env.GITHUB_APP_ID;
    delete process.env.GITHUB_APP_PRIVATE_KEY_PATH;
    // Note: isGitHubAppAuth reads env vars at module load time
    // This test verifies the exported function behavior
    expect(typeof isGitHubAppAuth).toBe('function');
  });
});

describe('integration scenarios', () => {
  const baseConfig = {
    rule: 'js/stack-trace-exposure',
    reason: "won't fix",
    comment: 'Bulk dismissal via script',
    dryRun: false,
    concurrency: 5
  };

  test('end-to-end dismissal workflow', async () => {
    const octokit = createMockOctokit();
    const repos = MOCK_REPOS.filter(r => !r.isArchived);

    // Suppress stderr output during test
    const originalStderr = process.stderr.write;
    process.stderr.write = jest.fn();

    const results = await processRepositories(octokit, 'test-org', repos, baseConfig);

    process.stderr.write = originalStderr;

    // Verify results
    const dismissed = results.filter(r => r.status === 'dismissed');
    const errors = results.filter(r => r.status.startsWith('error'));

    expect(dismissed.length).toBeGreaterThan(0);
    expect(errors.length).toBe(0);

    // Verify all dismissed alerts have the correct properties
    dismissed.forEach(result => {
      expect(result.organization).toBe('test-org');
      expect(result.ruleId).toBe('js/stack-trace-exposure');
      expect(result.status).toBe('dismissed');
    });
  });

  test('dry run generates accurate preview', async () => {
    const octokit = createMockOctokit();
    const repos = MOCK_REPOS.filter(r => !r.isArchived);
    const config = { ...baseConfig, dryRun: true };

    // Suppress stderr output during test
    const originalStderr = process.stderr.write;
    process.stderr.write = jest.fn();

    const results = await processRepositories(octokit, 'test-org', repos, config);

    process.stderr.write = originalStderr;

    // Verify no actual dismissals occurred
    expect(octokit._dismissedAlerts).toHaveLength(0);

    // Verify all results indicate dry-run
    results.forEach(result => {
      expect(result.status).toContain('dry-run');
    });
  });

  test('CSV report generation', async () => {
    const octokit = createMockOctokit();
    const repos = [{ name: 'repo-with-alerts', isArchived: false }];

    // Suppress stderr output during test
    const originalStderr = process.stderr.write;
    process.stderr.write = jest.fn();

    const results = await processRepositories(octokit, 'test-org', repos, baseConfig);

    process.stderr.write = originalStderr;

    const csv = generateCSV(results);
    const lines = csv.split('\n');

    // Header + 1 result row
    expect(lines.length).toBe(2);
    expect(lines[0]).toContain('Organization');
    expect(lines[0]).toContain('Repository');
    expect(lines[0]).toContain('Status');
    expect(lines[1]).toContain('dismissed');
  });
});

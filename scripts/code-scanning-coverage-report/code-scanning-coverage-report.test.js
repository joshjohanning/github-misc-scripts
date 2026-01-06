import { jest } from '@jest/globals';
import {
  checkCodeQLStatus,
  fetchScanningInfo,
  fetchCriticalAlertsCount,
  hasGitHubWorkflows,
  fetchCodeQLWorkflowStatus,
  isCodeQLLanguage,
  getUnscannedLanguages,
  processRepository,
  processRepositories,
  escapeCSV,
  buildCSVRow,
  generateCSV,
  CODEQL_LANGUAGES,
  LANGUAGE_NORMALIZE
} from './code-scanning-coverage-report.js';

// ============================================================================
// Mock Data - Modify these to test different scenarios
// ============================================================================

const MOCK_REPOS = {
  // Fully enabled with CodeQL, all languages scanned
  'repo-fully-enabled': {
    name: 'repo-fully-enabled',
    updatedAt: '2026-01-05T10:00:00Z',
    isArchived: false,
    defaultBranch: 'main',
    languages: ['JavaScript', 'TypeScript', 'Python']
  },

  // CodeQL enabled but missing some languages
  'repo-missing-languages': {
    name: 'repo-missing-languages',
    updatedAt: '2026-01-04T10:00:00Z',
    isArchived: false,
    defaultBranch: 'main',
    languages: ['JavaScript', 'Python', 'Go', 'Ruby']
  },

  // Code scanning enabled but no analyses uploaded
  'repo-no-scans': {
    name: 'repo-no-scans',
    updatedAt: '2026-01-03T10:00:00Z',
    isArchived: false,
    defaultBranch: 'main',
    languages: ['Java', 'Kotlin']
  },

  // Code scanning disabled
  'repo-disabled': {
    name: 'repo-disabled',
    updatedAt: '2026-01-02T10:00:00Z',
    isArchived: false,
    defaultBranch: 'main',
    languages: ['Python', 'JavaScript']
  },

  // Requires GHAS (Advanced Security not enabled)
  'repo-requires-ghas': {
    name: 'repo-requires-ghas',
    updatedAt: '2026-01-01T10:00:00Z',
    isArchived: false,
    defaultBranch: 'main',
    languages: ['C#', 'TypeScript']
  },

  // Archived repository
  'repo-archived': {
    name: 'repo-archived',
    updatedAt: '2024-06-15T10:00:00Z',
    isArchived: true,
    defaultBranch: 'main',
    languages: ['Python']
  },

  // Repo with critical alerts
  'repo-with-alerts': {
    name: 'repo-with-alerts',
    updatedAt: '2026-01-05T10:00:00Z',
    isArchived: false,
    defaultBranch: 'main',
    languages: ['JavaScript']
  },

  // Repo with analysis errors
  'repo-analysis-error': {
    name: 'repo-analysis-error',
    updatedAt: '2026-01-05T10:00:00Z',
    isArchived: false,
    defaultBranch: 'main',
    languages: ['C++', 'C']
  },

  // Repo with no CodeQL languages (only docs/config)
  'repo-no-codeql-languages': {
    name: 'repo-no-codeql-languages',
    updatedAt: '2026-01-05T10:00:00Z',
    isArchived: false,
    defaultBranch: 'main',
    languages: ['Markdown', 'HTML', 'CSS', 'Shell']
  },

  // Stale repo (scan date much older than last update)
  'repo-stale': {
    name: 'repo-stale',
    updatedAt: '2026-01-05T10:00:00Z',  // Updated recently
    isArchived: false,
    defaultBranch: 'main',
    languages: ['Python']
  }
};

// Mock API responses for code scanning analyses
const MOCK_ANALYSES = {
  'repo-fully-enabled': {
    data: [{
      created_at: '2026-01-05T08:00:00Z',
      tool: { name: 'CodeQL' },
      category: '/language:javascript-typescript',
      error: '',
      warning: ''
    }, {
      created_at: '2026-01-05T08:00:00Z',
      tool: { name: 'CodeQL' },
      category: '/language:python',
      error: '',
      warning: ''
    }]
  },
  'repo-missing-languages': {
    data: [{
      created_at: '2026-01-04T08:00:00Z',
      tool: { name: 'CodeQL' },
      category: '/language:javascript-typescript',
      error: '',
      warning: ''
    }]
    // Missing Python, Go, Ruby scans
  },
  'repo-no-scans': {
    error: { message: 'no analysis found', status: 404 }
  },
  'repo-disabled': {
    error: { message: 'Code security must be enabled for this repository', status: 403 }
  },
  'repo-requires-ghas': {
    error: { message: 'Advanced Security must be enabled for this repository', status: 403 }
  },
  'repo-archived': {
    error: { status: 403 }  // Archived repos return 403
  },
  'repo-with-alerts': {
    data: [{
      created_at: '2026-01-05T08:00:00Z',
      tool: { name: 'CodeQL' },
      category: '/language:javascript-typescript',
      error: '',
      warning: ''
    }]
  },
  'repo-analysis-error': {
    data: [{
      created_at: '2026-01-05T08:00:00Z',
      tool: { name: 'CodeQL' },
      category: '/language:c-cpp',
      error: 'Build failed: missing dependencies',
      warning: ''
    }]
  },
  'repo-no-codeql-languages': {
    error: { message: 'Code security must be enabled for this repository', status: 403 }
  },
  'repo-stale': {
    data: [{
      created_at: '2025-06-01T08:00:00Z',  // Old scan date
      tool: { name: 'CodeQL' },
      category: '/language:python',
      error: '',
      warning: ''
    }]
  }
};

// Mock critical alerts count
const MOCK_ALERTS = {
  'repo-fully-enabled': 0,
  'repo-missing-languages': 0,
  'repo-with-alerts': 5,
  'repo-analysis-error': 2,
  'repo-stale': 1
};

// ============================================================================
// Mock Octokit Factory
// ============================================================================

function createMockOctokit(customResponses = {}) {
  const responses = { ...MOCK_ANALYSES, ...customResponses };

  return {
    rest: {
      codeScanning: {
        listRecentAnalyses: jest.fn(async ({ repo }) => {
          const response = responses[repo];
          if (response?.error) {
            const error = new Error(response.error.message || 'API Error');
            error.status = response.error.status;
            throw error;
          }
          return response || { data: [] };
        }),
        listAlertsForRepo: jest.fn(async ({ repo, severity }) => {
          if (severity === 'critical' && MOCK_ALERTS[repo] !== undefined) {
            return { data: Array(MOCK_ALERTS[repo]).fill({ state: 'open', severity: 'critical' }) };
          }
          return { data: [] };
        })
      },
      repos: {
        getContent: jest.fn(async ({ repo, path }) => {
          // Simulate .github/workflows exists for most repos
          if (path === '.github/workflows') {
            if (repo === 'repo-no-codeql-languages') {
              throw new Error('Not found');
            }
            return { data: [] };
          }
          throw new Error('Not found');
        })
      },
      actions: {
        listRepoWorkflows: jest.fn(async ({ repo }) => {
          // Return CodeQL workflow for enabled repos
          if (['repo-fully-enabled', 'repo-missing-languages', 'repo-with-alerts'].includes(repo)) {
            return {
              data: {
                workflows: [{
                  name: 'CodeQL',
                  path: '.github/workflows/codeql.yml',
                  state: 'active'
                }]
              }
            };
          }
          return { data: { workflows: [] } };
        }),
        listWorkflowRuns: jest.fn(async ({ repo }) => {
          if (['repo-fully-enabled', 'repo-missing-languages', 'repo-with-alerts'].includes(repo)) {
            return {
              data: {
                workflow_runs: [{
                  conclusion: 'success',
                  created_at: '2026-01-05T08:00:00Z'
                }]
              }
            };
          }
          return { data: { workflow_runs: [] } };
        })
      }
    },
    paginate: {
      iterator: jest.fn(function* (method, params) {
        // For alert pagination
        if (params.severity === 'critical' && MOCK_ALERTS[params.repo] !== undefined) {
          yield { data: Array(MOCK_ALERTS[params.repo]).fill({ state: 'open', severity: 'critical' }) };
        } else {
          yield { data: [] };
        }
      })
    }
  };
}

// ============================================================================
// Tests
// ============================================================================

describe('isCodeQLLanguage', () => {
  test('recognizes supported CodeQL languages', () => {
    expect(isCodeQLLanguage('javascript')).toBe(true);
    expect(isCodeQLLanguage('JavaScript')).toBe(true);
    expect(isCodeQLLanguage('python')).toBe(true);
    expect(isCodeQLLanguage('Python')).toBe(true);
    expect(isCodeQLLanguage('java')).toBe(true);
    expect(isCodeQLLanguage('csharp')).toBe(true);
    expect(isCodeQLLanguage('c#')).toBe(true);
    expect(isCodeQLLanguage('go')).toBe(true);
    expect(isCodeQLLanguage('ruby')).toBe(true);
    expect(isCodeQLLanguage('swift')).toBe(true);
    expect(isCodeQLLanguage('kotlin')).toBe(true);
    expect(isCodeQLLanguage('c')).toBe(true);
    expect(isCodeQLLanguage('c++')).toBe(true);
    expect(isCodeQLLanguage('cpp')).toBe(true);
  });

  test('rejects non-CodeQL languages', () => {
    expect(isCodeQLLanguage('html')).toBe(false);
    expect(isCodeQLLanguage('css')).toBe(false);
    expect(isCodeQLLanguage('markdown')).toBe(false);
    expect(isCodeQLLanguage('shell')).toBe(false);
    expect(isCodeQLLanguage('dockerfile')).toBe(false);
    expect(isCodeQLLanguage('yaml')).toBe(false);
  });
});

describe('getUnscannedLanguages', () => {
  test('returns empty when all CodeQL languages are scanned', () => {
    const repoLanguages = ['JavaScript', 'TypeScript', 'Python'];
    const scannedLanguages = ['javascript-typescript', 'python'];
    const result = getUnscannedLanguages(repoLanguages, scannedLanguages, true, false);
    expect(result).toEqual([]);
  });

  test('identifies unscanned CodeQL languages', () => {
    const repoLanguages = ['JavaScript', 'Python', 'Go', 'Ruby'];
    const scannedLanguages = ['javascript-typescript'];
    const result = getUnscannedLanguages(repoLanguages, scannedLanguages, true, false);
    expect(result).toContain('python');
    expect(result).toContain('go');
    expect(result).toContain('ruby');
    expect(result).not.toContain('javascript');
  });

  test('returns empty array for repos with no CodeQL languages', () => {
    const repoLanguages = ['HTML', 'CSS', 'Markdown'];
    const scannedLanguages = [];
    const result = getUnscannedLanguages(repoLanguages, scannedLanguages, true, false);
    // Returns [] because there are no CodeQL languages to scan
    expect(result).toEqual([]);
  });

  test('returns null when no languages detected and no scans', () => {
    const repoLanguages = [];
    const scannedLanguages = [];
    const result = getUnscannedLanguages(repoLanguages, scannedLanguages, false, false);
    expect(result).toBeNull();
  });

  test('normalizes language names correctly', () => {
    const repoLanguages = ['C#', 'Java', 'Kotlin'];
    const scannedLanguages = ['csharp', 'java-kotlin'];
    const result = getUnscannedLanguages(repoLanguages, scannedLanguages, true, false);
    expect(result).toEqual([]);
  });
});

describe('checkCodeQLStatus', () => {
  test('returns Yes when analyses exist', async () => {
    const octokit = createMockOctokit();
    const result = await checkCodeQLStatus(octokit, 'test-org', 'repo-fully-enabled', false);
    expect(result).toBe('Yes');
  });

  test('returns No Scans when no analyses found', async () => {
    const octokit = createMockOctokit();
    const result = await checkCodeQLStatus(octokit, 'test-org', 'repo-no-scans', false);
    expect(result).toBe('No Scans');
  });

  test('returns Disabled when code security not enabled', async () => {
    const octokit = createMockOctokit();
    const result = await checkCodeQLStatus(octokit, 'test-org', 'repo-disabled', false);
    expect(result).toBe('Disabled');
  });

  test('returns Requires GHAS when Advanced Security not enabled', async () => {
    const octokit = createMockOctokit();
    const result = await checkCodeQLStatus(octokit, 'test-org', 'repo-requires-ghas', false);
    expect(result).toBe('Requires GHAS');
  });

  test('returns N/A for archived repos with 403', async () => {
    const octokit = createMockOctokit();
    const result = await checkCodeQLStatus(octokit, 'test-org', 'repo-archived', true);
    expect(result).toBe('N/A');
  });
});

describe('fetchScanningInfo', () => {
  test('extracts scanned languages from analyses', async () => {
    const octokit = createMockOctokit();
    const result = await fetchScanningInfo(octokit, 'test-org', 'repo-fully-enabled', 'main');
    expect(result.scannedLanguages).toContain('javascript-typescript');
    expect(result.scannedLanguages).toContain('python');
  });

  test('captures analysis errors', async () => {
    const octokit = createMockOctokit();
    const result = await fetchScanningInfo(octokit, 'test-org', 'repo-analysis-error', 'main');
    expect(result.analysisError).toContain('Build failed');
  });

  test('returns empty data when scanning not enabled', async () => {
    const octokit = createMockOctokit();
    const result = await fetchScanningInfo(octokit, 'test-org', 'repo-disabled', 'main');
    expect(result.scannedLanguages).toEqual([]);
    expect(result.lastScanDate).toBeNull();
  });
});

describe('escapeCSV', () => {
  test('wraps values with commas in quotes', () => {
    expect(escapeCSV('hello,world')).toBe('"hello,world"');
  });

  test('wraps values with quotes in quotes and escapes them', () => {
    expect(escapeCSV('say "hello"')).toBe('"say ""hello"""');
  });

  test('wraps values with newlines in quotes', () => {
    expect(escapeCSV('line1\nline2')).toBe('"line1\nline2"');
  });

  test('leaves simple values unchanged', () => {
    expect(escapeCSV('simple')).toBe('simple');
  });

  test('handles empty values', () => {
    expect(escapeCSV('')).toBe('');
  });
});

describe('generateCSV', () => {
  const mockResults = [
    {
      repository: 'test-repo',
      defaultBranch: 'main',
      lastUpdated: '2026-01-05',
      isArchived: false,
      languages: 'JavaScript;Python',
      codeqlEnabled: 'Yes',
      lastScanDate: '2026-01-05',
      scannedLanguages: 'javascript-typescript;python',
      unscannedLanguages: 'None',
      criticalAlerts: 0,
      analysisError: 'None',
      analysisWarning: 'None',
      workflowStatus: null
    }
  ];

  test('generates valid CSV with headers', () => {
    const csv = generateCSV(mockResults, { checkWorkflows: false });
    const lines = csv.split('\n');
    expect(lines[0]).toContain('Repository');
    expect(lines[0]).toContain('CodeQL Enabled');
    expect(lines[0]).toContain('Critical Alerts');
    expect(lines.length).toBe(2);  // Header + 1 data row
  });

  test('includes workflow status column when enabled', () => {
    const csv = generateCSV(mockResults, { checkWorkflows: true });
    expect(csv).toContain('Workflow Status');
  });
});

describe('processRepository', () => {
  test('processes fully enabled repository correctly', async () => {
    const octokit = createMockOctokit();
    const repo = MOCK_REPOS['repo-fully-enabled'];
    const config = { checkAlerts: false, checkActions: false, checkWorkflows: false };

    const result = await processRepository(octokit, 'test-org', repo, config);

    expect(result.repository).toBe('repo-fully-enabled');
    expect(result.codeqlEnabled).toBe('Yes');
    expect(result.languages).toBe('JavaScript;TypeScript;Python');
  });

  test('identifies missing languages', async () => {
    const octokit = createMockOctokit();
    const repo = MOCK_REPOS['repo-missing-languages'];
    const config = { checkAlerts: false, checkActions: false, checkWorkflows: false };

    const result = await processRepository(octokit, 'test-org', repo, config);

    expect(result.codeqlEnabled).toBe('Yes');
    expect(result.unscannedLanguages).toContain('python');
    expect(result.unscannedLanguages).toContain('go');
    expect(result.unscannedLanguages).toContain('ruby');
  });

  test('handles archived repository', async () => {
    const octokit = createMockOctokit();
    const repo = MOCK_REPOS['repo-archived'];
    const config = { checkAlerts: false, checkActions: false, checkWorkflows: false };

    const result = await processRepository(octokit, 'test-org', repo, config);

    expect(result.isArchived).toBe(true);
    expect(result.codeqlEnabled).toBe('N/A');
  });

  test('captures analysis errors', async () => {
    const octokit = createMockOctokit();
    const repo = MOCK_REPOS['repo-analysis-error'];
    const config = { checkAlerts: false, checkActions: false, checkWorkflows: false };

    const result = await processRepository(octokit, 'test-org', repo, config);

    expect(result.analysisError).toContain('Build failed');
  });
});

describe('processRepositories', () => {
  test('processes multiple repositories with concurrency', async () => {
    const octokit = createMockOctokit();
    const repos = [
      MOCK_REPOS['repo-fully-enabled'],
      MOCK_REPOS['repo-disabled'],
      MOCK_REPOS['repo-archived']
    ];
    const config = {
      checkAlerts: false,
      checkActions: false,
      checkWorkflows: false,
      concurrency: 2
    };

    // Suppress console.error during test
    const originalError = console.error;
    console.error = jest.fn();

    const results = await processRepositories(octokit, 'test-org', repos, config);

    console.error = originalError;

    expect(results).toHaveLength(3);
    expect(results.find(r => r.repository === 'repo-fully-enabled').codeqlEnabled).toBe('Yes');
    expect(results.find(r => r.repository === 'repo-disabled').codeqlEnabled).toBe('Disabled');
    expect(results.find(r => r.repository === 'repo-archived').codeqlEnabled).toBe('N/A');
  });
});

// ============================================================================
// Integration-style tests with full mock data
// ============================================================================

describe('Full Report Generation', () => {
  test('generates complete report for mixed repository states', async () => {
    const octokit = createMockOctokit();
    const repos = Object.values(MOCK_REPOS);
    const config = {
      checkAlerts: false,
      checkActions: false,
      checkWorkflows: false,
      concurrency: 5
    };

    // Suppress console.error during test
    const originalError = console.error;
    console.error = jest.fn();

    const results = await processRepositories(octokit, 'test-org', repos, config);
    const csv = generateCSV(results, config);

    console.error = originalError;

    // Verify all repos processed
    expect(results).toHaveLength(repos.length);

    // Verify different statuses captured
    const statuses = results.map(r => r.codeqlEnabled);
    expect(statuses).toContain('Yes');
    expect(statuses).toContain('Disabled');
    expect(statuses).toContain('No Scans');
    expect(statuses).toContain('Requires GHAS');
    expect(statuses).toContain('N/A');

    // Verify CSV structure
    expect(csv).toContain('Repository,Default Branch');
    expect(csv).toContain('repo-fully-enabled');
    expect(csv).toContain('repo-archived');
  });
});

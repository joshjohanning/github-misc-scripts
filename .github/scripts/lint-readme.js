// Call manually via: node ./.github/scripts/lint-readme.js
// Defaults to the `./gh-cli` directory
// Check `./scripts` directory by calling: node ./.github/scripts/lint-readme.js ./scripts '##' '# scripts'

// note this is only looking in files committed / staged, not all files in the directory

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const directoryPath = process.argv[2] || './gh-cli';
const headingLevel = process.argv[3] || '###';
const parentHeading = process.argv[4] || '## Scripts';

// Escape RegExp special characters
function escapeRegExp(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
const readmePath = path.join(directoryPath, 'README.md');

// Read README.md content
if (!fs.existsSync(readmePath)) {
  console.log(`README.md not found at ${readmePath}`);
  process.exit(1);
}
const readme = fs.readFileSync(readmePath, 'utf8');

// Get all files tracked by Git
let gitFiles;
try {
  gitFiles = execSync('git ls-files', { cwd: directoryPath, encoding: 'utf-8' });
} catch (error) {
  console.log(`Error running git ls-files in ${directoryPath}: ${error.message}`);
  process.exit(1);
}

// Split the output into an array of file paths
const files = gitFiles.split('\n');

// Filter out .sh files in the root directory (excluding those in subdirectories)
const fileExtensions = ['.sh', '.ps1', '.js', '.mjs', '.py'];

const filteredFiles = files.filter(file => {
  return fileExtensions.some(extension => file.endsWith(extension)) && !file.includes('/');
});

const subdirectories = files.reduce((acc, file) => {
  if (file.includes('/')) {
    const subdirectory = file.split('/')[0];
    if (subdirectory !== 'internal' && !acc.includes(subdirectory)) {
      acc.push(subdirectory);
    }
  }
  return acc;
}, []);

const allScripts = filteredFiles.concat(subdirectories);

// Initialize a counter for the number of issues
let issueCount = 0;

// Helper function to log numbered issues
function logIssue(message) {
  issueCount++;
  console.log(`${issueCount}. ${message}`);
}

// Check if each .sh file is mentioned in the README.md
allScripts.forEach(file => {
  if (!readme.includes(`${headingLevel} ${file}`)) {
    logIssue(`📝 The file ${file} is not mentioned in the README.md`);
  }
});

// Check that all files follow the kebab-case naming convention
allScripts.forEach(file => {
  if (!/^([a-z0-9]+-)*[a-z0-9]+(\.[a-z0-9]+)*$/.test(file)) {
    logIssue(`🔤 The file ${file} does not follow the kebab-case naming convention`);
  }
});

// Check that all .sh files have execution permissions
allScripts.forEach(file => {
  if (!file.endsWith('.sh')) {
    return;
  }

  const filePath = path.join(directoryPath, file);
  const stats = fs.statSync(filePath);
  const isExecutable = (stats.mode & fs.constants.X_OK) !== 0;

  if (!isExecutable) {
    logIssue(`🔒 The file ${file} does not have execution permissions`);
  }
});

// Check bash syntax for all .sh files
allScripts.forEach(file => {
  if (!file.endsWith('.sh')) {
    return;
  }

  const filePath = path.join(directoryPath, file);
  try {
    execSync(`bash -n "${filePath}"`, { stdio: 'pipe' });
  } catch (error) {
    logIssue(`🐛 The file ${file} has a bash syntax error`);
    const errorLines = error.stderr.toString().trim().split('\n');
    errorLines.forEach(line => console.log(`        ${line}`));
  }
});

// Extract the part of the README under the ## Scripts heading
const scriptsSection = readme.split(`${parentHeading}\n`)[1];
if (!scriptsSection) {
  console.log(`Section "${parentHeading}" not found in README.md`);
  process.exit(1);
}

// Extract all ### headings from the scripts section
const regex = new RegExp(`${escapeRegExp(headingLevel)} .*`, 'g');
const headings = scriptsSection.match(regex);

if (!headings || headings.length === 0) {
  console.log(`No headings found with level "${headingLevel}" in the scripts section`);
  process.exit(1);
}

// Check that all scripts mentioned in the README.md actually exist in the repository
headings.forEach(heading => {
  const script = heading.slice(headingLevel.length + 1); // Remove the '### ' prefix
  if (!allScripts.includes(script)) {
    logIssue(`📁 The script ${script} is mentioned in the README.md but does not exist in the repository`);
  }
});

// Check that certain short words are not used in the .sh file names
const shortWords = {
  'repo': 'repository',
  'repos': 'repositories',
  'org': 'organization',
  'orgs': 'organizations'
};

allScripts.forEach(file => {
  Object.keys(shortWords).forEach(word => {
    const regex = new RegExp(`\\b${word}\\b`, 'g');
    if (regex.test(file)) {
      logIssue(`📏 The file name "${file}" uses the short word "${word}". Consider using "${shortWords[word]}" instead.`);
    }
  });
});

// Check if the headings are in alphabetical order
for (let i = 0; i < headings.length - 1; i++) {
  const current = headings[i].toLowerCase();
  const next = headings[i + 1].toLowerCase();

  if (next.startsWith(current + '-') || (current > next && !current.startsWith(next + '-'))) {
    logIssue(`📋 The heading "${headings[i + 1]}" is out of order. It should come before "${headings[i]}".`);
    break;
  }
}

// Output final summary
if (issueCount === 0) {
  console.log('✅ No issues found.');
} else {
  console.log('');
  console.log(`❌ Found ${issueCount} issue${issueCount === 1 ? '' : 's'} that need to be addressed.`);
  process.exit(1);
}

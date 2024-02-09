// Call manually via: node ./.github/scripts/lint-gh-cli-readme.js

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const directoryPath = './gh-cli';
const readmePath = path.join(directoryPath, 'README.md');

// Read README.md content
const readme = fs.readFileSync(readmePath, 'utf8');

// Get all files tracked by Git
const gitFiles = execSync('git ls-files', { cwd: directoryPath, encoding: 'utf-8' });

// Split the output into an array of file paths
const files = gitFiles.split('\n');

// Filter out .sh files in the root directory (excluding those in subdirectories)
const shFiles = files.filter(file => file.endsWith('.sh') && !file.includes('/'));

// Initialize a counter for the number of issues
let issueCount = 0;

// Check if each .sh file is mentioned in the README.md
shFiles.forEach(file => {
  if (!readme.includes(`### ${file}`)) {
    console.log(`The file ${file} is not mentioned in the README.md`);
    issueCount++;
  }
});

// Extract the part of the README under the ## Scripts heading
const scriptsSection = readme.split('## Scripts\n')[1];

// Extract all ### headings from the scripts section
const headings = scriptsSection.match(/### .*/g);

// Check if the headings are in alphabetical order
for (let i = 0; i < headings.length - 1; i++) {
  const current = headings[i].toLowerCase();
  const next = headings[i + 1].toLowerCase();

  if (next.startsWith(current + '-') || (current > next && !current.startsWith(next + '-'))) {
    console.log(`The heading "${headings[i + 1]}" is out of order. It should come before "${headings[i]}".`);
    issueCount++;
    break;
  }
}

// If there are no issues, print a message
if (issueCount === 0) {
  console.log('No issues found. ✅');
} else {
  console.log(`Found ${issueCount} issue(s). ❌`);
  process.exit(1);
}

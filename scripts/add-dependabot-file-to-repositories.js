//
// This script will add a dependabot.yml file to all repositories in provided in a txt file.
// Generate a list of repos with ../gh-cli/generate-repositories-list.sh
// input file should look like this:
//      joshjohanning-org/test-repo-1
//      joshjohanning-org/test-repo-2
//
// Usage:
//   node add-dependabot-file-to-repositories.js ./repos.txt ./dependabot.yml
//

const { Octokit } = require("octokit");
const fs = require('fs');

// TODO: USER CONFIG - CHANGE THESE VALUES
const gitUsername = 'josh-issueops-bot[bot]'; // name of GitHub App with [bot] appended
const gitEmail = '149130343+josh-issueops-bot[bot]@users.noreply.github.com'; // if using GitHub App, find the user ID number by calling: gh api '/users/josh-issueops-bot[bot]' --jq .id
const overwrite = false; // if true, will overwrite existing dependabot.yml file
//

// const - do not change these values
const repositoriesInput = process.argv[2];
const dependabotYml = process.argv[3];
const path = '.github/dependabot.yml';
//

// pre-run checks
if (!process.env.GITHUB_TOKEN) {
    console.error("Please set the GITHUB_TOKEN environment variable.");
    process.exit(1);
}

if (!fs.existsSync(repositoriesInput)) {
    console.error(`Could not find ${repositoriesInput}`);
    process.exit(1);
}

if (!fs.existsSync(dependabotYml)) {
    console.error(`Could not find ${dependabotYml}`);
    process.exit(1);
}
//

let octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN,
  baseUrl: 'https://api.github.com'
});

const repositories = fs.readFileSync(repositoriesInput, 'utf8');

async function main() {
    await findDependabotYml({repositories});
}

const findDependabotYml = async ({repositories}) => {
    const repos = repositories
        .split("\n")
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
    for (const url of repos) {
        let parts = url.split("/");
        let org = parts[parts.length-2];
        let repo = parts[parts.length-1];
        let sha;
        console.log(`\n>>> Processing ${org}/${repo} ... `)

        try {
            res = await octokit.request('GET /repos/{owner}/{repo}/contents/{path}', {
                owner: org,
                repo: repo,
                path: path,
                headers: {
                    'X-GitHub-Api-Version': '2022-11-28'
                }
            })

            sha=sha=res.data.sha;
        }
        catch (error) {
            console.debug(`Could not find dependabot.yml file in ${path}`);
        }
        
        // only if file doesn't exist or overwrite is true
        if (!sha || overwrite) {
            await addDependabotYml(org, repo, sha);
        } else {
            console.log(`${path} already exists in ${org}/${repo}`)
        }

    };
}

async function addDependabotYml(org, repo, sha) {
    let commitMessage;
    if (sha) {
        commitMessage = 'Updating dependabot.yml file';
    }
    else {
        commitMessage = 'Adding dependabot.yml file';
    }

    console.log(`Doing: ${commitMessage} in ${org}/${repo}`);

    // convert local dependabot.yml file to base64
    const buffer = fs.readFileSync(dependabotYml);
    const base64Content = buffer.toString('base64');

    try {
        await octokit.request('PUT /repos/{owner}/{repo}/contents/{path}', {
            owner: org,
            repo: repo,
            path: path,
            sha: sha,
            message: commitMessage,
            committer: {
                name: gitUsername,
                email: gitEmail
            },
            content: base64Content,
            headers: {
                'X-GitHub-Api-Version': '2022-11-28'
            }
        })
        console.log(`Successful: ${commitMessage} in ${org}/${repo}`);
    }

    catch (error) {
        console.error(error);
    }
}

main();

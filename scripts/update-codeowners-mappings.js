const { Octokit } = require("octokit");
const fs = require('fs');
const Papa = require('papaparse');

let octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN,
  baseUrl: 'https://api.github.com'
});

const repositories = process.env.REPOSITORIES;

async function main() {
    await findCodeowners({repositories});
}

const findCodeowners = async ({repositories}) => {
    const repos = repositories
        .split("\n")
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
    for (const url of repos) {
        let parts = url.split("/");
        let org = parts[parts.length-2];
        let repo = parts[parts.length-1];
        let path;
        let codeownersPath;
        console.log(`\n>>> Processing ${org}/${repo} ... `)

        try {
            path='CODEOWNERS';
            res = await octokit.request('GET /repos/{owner}/{repo}/contents/{path}', {
                owner: org,
                repo: repo,
                path: path,
                headers: {
                    'X-GitHub-Api-Version': '2022-11-28'
                }
            })
            codeownersPath=res.data.path;
            content=res.data.content;
            sha=res.data.sha;
        }
        catch (error) {
            console.debug(`Could not find CODEOWNERS file in ${path}`);
        }

        try {
            path='.github/CODEOWNERS';
            res = await octokit.request('GET /repos/{owner}/{repo}/contents/{path}', {
                owner: org,
                repo: repo,
                path: path,
                headers: {
                    'X-GitHub-Api-Version': '2022-11-28'
                }
            })
            codeownersPath=res.data.path;
            content=res.data.content;
            sha=res.data.sha;
        }
        catch (error) {
            console.debug(`Could not find CODEOWNERS file in ${path}`);
        }

        try {
            path='docs/CODEOWNERS';
            res = await octokit.request('GET /repos/{owner}/{repo}/contents/{path}', {
                owner: org,
                repo: repo,
                path: path,
                headers: {
                    'X-GitHub-Api-Version': '2022-11-28'
                }
            })
            codeownersPath=res.data.path;
            content=res.data.content;
            sha=res.data.sha;
        }
        catch (error) {
            console.debug(`Could not find CODEOWNERS file in ${path}`);
        }
        
        // if path is not empty
        if (codeownersPath) {
            await updateCodeowners(codeownersPath, content, sha, org, repo);
        } else {
            console.log(`Could not find CODEOWNERS file in ${org}/${repo}`)
        }

    };
}

async function updateCodeowners(codeownersPath, content, sha, org, repo) {
    console.log(`Processing CODEOWNERS file at ${codeownersPath}`);
    // Decode the content from base64
    const buff = Buffer.from(content, 'base64');
    let newContent = buff.toString('ascii');

    // Read the CSV file
    let csvData = fs.readFileSync('codeowners-mappings.csv', 'utf8');

    // Parse the CSV data
    let parsedData = Papa.parse(csvData, {
        header: true,
        dynamicTyping: true,
        skipEmptyLines: true
    }).data;

    // Iterate over the parsed data and update newContent
    parsedData.forEach(item => {
        let oldValue = item.oldValue;
        let newValue = item.newValue;
        console.log(`Replacing ${oldValue} with ${newValue}`);
        newContent = newContent.replace(oldValue, newValue);
    });

    // bas64 encode newContent
    const newBuff = Buffer.from(newContent, 'ascii');
    const newBase64Content = newBuff.toString('base64');

    try {
        await octokit.request('PUT /repos/{owner}/{repo}/contents/{path}', {
            owner: org,
            repo: repo,
            path: codeownersPath,
            sha: sha,
            message: 'Updating codeowners file',
            committer: {
                name: 'github-actions[bot]',
                email: 'github-actions[bot]@users.noreply.github.com'
            },
            content: newBase64Content,
            headers: {
                'X-GitHub-Api-Version': '2022-11-28'
            }
        })
        console.log(`Successfully updated CODEOWNERS file at ${codeownersPath}`);
    }

    catch (error) {
        console.error(error);
    }

    // we want to make sure we exit as to not run the other API calls
    // process.exit(0);
}

main();

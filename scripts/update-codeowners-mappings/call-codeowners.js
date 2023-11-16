const repositories = process.env.REPOSITORIES;

// Define an async function
async function main() {
    await require('./codeowners.js')({repositories});
}

// Call the async function
main();

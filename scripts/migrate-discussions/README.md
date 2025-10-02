# migrate-discussions.js

Migrate GitHub Discussions between repositories, including categories, labels, comments, and replies. This script can migrate discussions across different GitHub instances and enterprises with comprehensive rate limit handling and resume capabilities.

## Prerequisites

- `SOURCE_TOKEN` environment variable with GitHub PAT that has `repo` scope and read access to source repository discussions
- `TARGET_TOKEN` environment variable with GitHub PAT that has `repo` scope and write access to target repository discussions
- Dependencies installed via `npm i octokit`
- Both source and target repositories must have GitHub Discussions enabled

## Script usage

Basic usage:

```bash
export SOURCE_TOKEN=ghp_abc
export TARGET_TOKEN=ghp_xyz
npm i octokit
node ./migrate-discussions.js source-org source-repo target-org target-repo
```

Resume from a specific discussion number (useful if interrupted):

```bash
node ./migrate-discussions.js source-org source-repo target-org target-repo --start-from 50
```

## Optional environment variables

- `SOURCE_API_URL` - API endpoint for source (defaults to `https://api.github.com`)
- `TARGET_API_URL` - API endpoint for target (defaults to `https://api.github.com`)

Example with GitHub Enterprise Server:

```bash
export SOURCE_API_URL=https://github.mycompany.com/api/v3
export TARGET_API_URL=https://api.github.com
export SOURCE_TOKEN=ghp_abc
export TARGET_TOKEN=ghp_xyz
npm i octokit
node ./migrate-discussions.js source-org source-repo target-org target-repo
```

## Features

### Content Migration

- Automatically creates missing discussion categories in the target repository
- Creates labels in the target repository if they don't exist
- Copies all comments and threaded replies with proper attribution
- Copies poll results as static snapshots (with table and optional Mermaid chart)
- Preserves reaction counts on discussions, comments, and replies
- Maintains locked status of discussions
- Indicates pinned discussions with a visual indicator
- Marks answered discussions and preserves the accepted answer

### Rate Limiting & Reliability

- **Automatic rate limit handling** with Octokit's built-in throttling plugin
- **Intelligent retry logic** for both primary and secondary rate limits (up to 3 retries)
- **GitHub-recommended delays** - 3 seconds between discussions/comments to stay under secondary rate limits
- **Resume capability** - Use `--start-from <number>` to resume from a specific discussion if interrupted
- **Rate limit tracking** - Summary shows how many times primary and secondary rate limits were hit

### User Experience

- Colored console output with timestamps for better visibility
- Comprehensive summary statistics at completion
- Detailed progress logging for each discussion, comment, and reply

## Configuration options

Edit these constants at the top of the script:

- `INCLUDE_POLL_MERMAID_CHART` - Set to `false` to disable Mermaid pie charts for polls (default: `true`)
- `RATE_LIMIT_SLEEP_SECONDS` - Sleep duration between API calls (default: `0.5` seconds)
- `DISCUSSION_PROCESSING_DELAY_SECONDS` - Delay between processing discussions/comments (default: `3` seconds)
- `MAX_RETRIES` - Maximum retries for non-rate-limit errors (default: `3`)

## Summary output

After completion, the script displays comprehensive statistics:

- Total discussions found and created
- Discussions skipped (when using `--start-from`)
- Total comments found and copied
- **Primary rate limits hit** - How many times the script hit GitHub's primary rate limit
- **Secondary rate limits hit** - How many times the script hit GitHub's secondary rate limit
- List of missing categories that need manual creation

## Notes

### Category handling

- If a category doesn't exist in the target repository, discussions will be created in the "General" category as a fallback
- Missing categories are tracked and reported at the end of the script

### Content preservation

- The script preserves discussion metadata by adding attribution text to the body and comments
- Poll results are copied as static snapshots - voting is not available in copied discussions
- Reactions are copied as read-only summaries (users cannot add new reactions to the migrated content)
- Attachments (images and files) will not copy over and require manual handling

### Discussion states

- Locked discussions will be locked in the target repository
- Closed discussions will be closed in the target repository
- Answered discussions will have the same comment marked as the answer
- Pinned status is indicated in the discussion body (GitHub API doesn't allow pinning via GraphQL)

### Rate limiting

- GitHub limits content-generating requests to avoid abuse
  - No more than 80 content-generating requests per minute
  - No more than 500 content-generating requests per hour
- The script stays under 1 discussion or comment created every 3 seconds (GitHub's recommendation)
- Automatic retry with wait times from GitHub's `retry-after` headers
- If rate limits are consistently hit, the script will retry up to 3 times before failing

### Resume capability

- Use `--start-from <number>` to skip discussions before a specific discussion number
- Useful for resuming after interruptions or failures
- Discussion numbers are the user-friendly numbers (e.g., #50), not GraphQL IDs

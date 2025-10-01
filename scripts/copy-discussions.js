#!/usr/bin/env node

//
// Copy Discussions between repositories in different enterprises
// This script copies discussions from a source repository to a target repository
// using different GitHub tokens for authentication to support cross-enterprise copying
//
// Usage:
//   node copy-discussions.js <source_org> <source_repo> <target_org> <target_repo>
//
// Example:
//   node copy-discussions.js source-org repo1 target-org repo2
//
// Prerequisites:
// - SOURCE_TOKEN environment variable with read access to source repository discussions
// - TARGET_TOKEN environment variable with write access to target repository discussions
// - Both tokens must have the 'repo' scope
// - Dependencies installed via `npm i octokit`
//
// Note: This script copies discussion content, comments, replies, polls, reactions, locked status,
// and pinned status. Reactions are copied as read-only summaries.
// Attachments (images and files) will not copy over - they need manual handling.

// Configuration
const INCLUDE_POLL_MERMAID_CHART = true; // Set to false to disable Mermaid pie chart for polls

const { Octokit } = require("octokit");

// Parse command line arguments
const args = process.argv.slice(2);

// Check for help flag
if (args.includes('--help') || args.includes('-h')) {
  console.log('Copy Discussions between GitHub repositories');
  console.log('');
  console.log('Usage:');
  console.log('  node copy-discussions.js <source_org> <source_repo> <target_org> <target_repo>');
  console.log('');
  console.log('Arguments:');
  console.log('  source_org    Source organization name');
  console.log('  source_repo   Source repository name');
  console.log('  target_org    Target organization name');
  console.log('  target_repo   Target repository name');
  console.log('');
  console.log('Environment Variables:');
  console.log('  SOURCE_TOKEN  GitHub token with read access to source repository discussions');
  console.log('  TARGET_TOKEN  GitHub token with write access to target repository discussions');
  console.log('');
  console.log('Example:');
  console.log('  node copy-discussions.js source-org repo1 target-org repo2');
  console.log('');
  console.log('Note:');
  console.log('  - Both tokens must have the "repo" scope');
  console.log('  - This script copies discussion content, comments, replies, polls, reactions,');
  console.log('    locked status, and pinned status');
  console.log('  - Attachments (images and files) will not copy over and require manual handling');
  process.exit(0);
}

if (args.length !== 4) {
  console.error("Usage: node copy-discussions.js <source_org> <source_repo> <target_org> <target_repo>");
  console.error("\nExample:");
  console.error("  node copy-discussions.js source-org repo1 target-org repo2");
  console.error("\nFor more information, use --help");
  process.exit(1);
}

const [SOURCE_ORG, SOURCE_REPO, TARGET_ORG, TARGET_REPO] = args;

// Validate environment variables
if (!process.env.SOURCE_TOKEN) {
  console.error("ERROR: SOURCE_TOKEN environment variable is required");
  process.exit(1);
}

if (!process.env.TARGET_TOKEN) {
  console.error("ERROR: TARGET_TOKEN environment variable is required");
  process.exit(1);
}

// Initialize Octokit instances
const sourceOctokit = new Octokit({
  auth: process.env.SOURCE_TOKEN
});

const targetOctokit = new Octokit({
  auth: process.env.TARGET_TOKEN
});

// Tracking variables
let missingCategories = [];
let totalDiscussions = 0;
let createdDiscussions = 0;
let skippedDiscussions = 0;
let totalComments = 0;
let copiedComments = 0;

// Helper functions
function log(message) {
  const timestamp = new Date().toISOString().replace('T', ' ').split('.')[0];
  console.log(`\x1b[32m[${timestamp}]\x1b[0m ${message}`);
}

function warn(message) {
  const timestamp = new Date().toISOString().replace('T', ' ').split('.')[0];
  console.warn(`\x1b[33m[${timestamp}] WARNING:\x1b[0m ${message}`);
}

function error(message) {
  const timestamp = new Date().toISOString().replace('T', ' ').split('.')[0];
  console.error(`\x1b[31m[${timestamp}] ERROR:\x1b[0m ${message}`);
}

async function sleep(seconds) {
  return new Promise(resolve => setTimeout(resolve, seconds * 1000));
}

async function rateLimitSleep(seconds = 2) {
  log(`Waiting ${seconds}s to avoid rate limiting...`);
  await sleep(seconds);
}

function formatPollData(poll) {
  if (!poll || !poll.options || poll.options.nodes.length === 0) {
    return '';
  }

  const options = poll.options.nodes;
  const totalVotes = poll.totalVoteCount || 0;
  
  let pollMarkdown = '\n\n---\n\n### 📊 Poll Results (from source discussion)\n\n';
  pollMarkdown += `**${poll.question}**\n\n`;
  
  // Create table
  pollMarkdown += '| Option | Votes | Percentage |\n';
  pollMarkdown += '|--------|-------|------------|\n';
  
  options.forEach(option => {
    const votes = option.totalVoteCount || 0;
    const percentage = totalVotes > 0 ? ((votes / totalVotes) * 100).toFixed(1) : '0.0';
    pollMarkdown += `| ${option.option} | ${votes} | ${percentage}% |\n`;
  });
  
  pollMarkdown += `\n**Total votes:** ${totalVotes}\n`;
  
  // Add Mermaid pie chart if enabled
  if (INCLUDE_POLL_MERMAID_CHART && totalVotes > 0) {
    pollMarkdown += '\n<details>\n<summary><i>Visual representation</i></summary>\n\n';
    pollMarkdown += '```mermaid\n';
    pollMarkdown += '%%{init: {"pie": {"textPosition": 0.5}, "themeVariables": {"pieOuterStrokeWidth": "5px"}}}%%\n';
    pollMarkdown += 'pie showData\n';
    pollMarkdown += `    title ${poll.question}\n`;
    
    options.forEach(option => {
      const votes = option.totalVoteCount || 0;
      if (votes > 0) {
        // Escape backslashes and quotes in option text for Mermaid
        const escapedOption = option.option.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
        pollMarkdown += `    "${escapedOption}" : ${votes}\n`;
      }
    });
    
    pollMarkdown += '```\n\n';
    pollMarkdown += '</details>\n';
  }
  
  pollMarkdown += '\n_Note: This is a static snapshot of poll results from the source discussion. Voting is not available in copied discussions._\n';
  
  return pollMarkdown;
}

function formatReactions(reactionGroups) {
  if (!reactionGroups || reactionGroups.length === 0) {
    return '';
  }

  const reactionMap = {
    'THUMBS_UP': '👍',
    'THUMBS_DOWN': '👎',
    'LAUGH': '😄',
    'HOORAY': '🎉',
    'CONFUSED': '😕',
    'HEART': '❤️',
    'ROCKET': '🚀',
    'EYES': '👀'
  };

  const formattedReactions = reactionGroups
    .filter(group => group.users.totalCount > 0)
    .map(group => {
      const emoji = reactionMap[group.content] || group.content;
      return `${emoji} ${group.users.totalCount}`;
    })
    .join(' | ');

  return formattedReactions ? `\n\n**Reactions:** ${formattedReactions}` : '';
}

// GraphQL Queries and Mutations
const CHECK_DISCUSSIONS_ENABLED_QUERY = `
  query($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
      hasDiscussionsEnabled
      id
    }
  }
`;

const FETCH_CATEGORIES_QUERY = `
  query($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
      discussionCategories(first: 100) {
        nodes {
          id
          name
          slug
          emoji
          description
        }
      }
    }
  }
`;

const FETCH_LABELS_QUERY = `
  query($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
      labels(first: 100) {
        nodes {
          id
          name
          color
          description
        }
      }
    }
  }
`;

const FETCH_DISCUSSIONS_QUERY = `
  query($owner: String!, $repo: String!, $cursor: String) {
    repository(owner: $owner, name: $repo) {
      discussions(first: 100, after: $cursor, orderBy: {field: CREATED_AT, direction: ASC}) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          title
          body
          category {
            id
            name
            slug
            description
            emoji
          }
          labels(first: 100) {
            nodes {
              id
              name
              color
              description
            }
          }
          answer {
            id
          }
          author {
            login
          }
          createdAt
          closed
          locked
          upvoteCount
          url
          number
          poll {
            question
            totalVoteCount
            options(first: 100) {
              nodes {
                option
                totalVoteCount
              }
            }
          }
          reactionGroups {
            content
            users {
              totalCount
            }
          }
        }
      }
      pinnedDiscussions(first: 100) {
        nodes {
          discussion {
            id
          }
        }
      }
    }
  }
`;

const FETCH_DISCUSSION_COMMENTS_QUERY = `
  query($discussionId: ID!) {
    node(id: $discussionId) {
      ... on Discussion {
        comments(first: 100) {
          nodes {
            id
            body
            author {
              login
            }
            createdAt
            upvoteCount
            reactionGroups {
              content
              users {
                totalCount
              }
            }
            replies(first: 50) {
              nodes {
                id
                body
                author {
                  login
                }
                createdAt
                upvoteCount
                reactionGroups {
                  content
                  users {
                    totalCount
                  }
                }
              }
            }
          }
        }
      }
    }
  }
`;

const CREATE_DISCUSSION_MUTATION = `
  mutation($repositoryId: ID!, $categoryId: ID!, $title: String!, $body: String!) {
    createDiscussion(input: {
      repositoryId: $repositoryId,
      categoryId: $categoryId,
      title: $title,
      body: $body
    }) {
      discussion {
        id
        title
        url
        number
      }
    }
  }
`;

const CREATE_LABEL_MUTATION = `
  mutation($repositoryId: ID!, $name: String!, $color: String!, $description: String) {
    createLabel(input: {
      repositoryId: $repositoryId,
      name: $name,
      color: $color,
      description: $description
    }) {
      label {
        id
        name
      }
    }
  }
`;

const ADD_LABELS_MUTATION = `
  mutation($labelableId: ID!, $labelIds: [ID!]!) {
    addLabelsToLabelable(input: {
      labelableId: $labelableId,
      labelIds: $labelIds
    }) {
      labelable {
        labels(first: 100) {
          nodes {
            name
          }
        }
      }
    }
  }
`;

const ADD_DISCUSSION_COMMENT_MUTATION = `
  mutation($discussionId: ID!, $body: String!) {
    addDiscussionComment(input: {
      discussionId: $discussionId,
      body: $body
    }) {
      comment {
        id
        body
        createdAt
      }
    }
  }
`;

const ADD_DISCUSSION_COMMENT_REPLY_MUTATION = `
  mutation($discussionId: ID!, $replyToId: ID!, $body: String!) {
    addDiscussionComment(input: {
      discussionId: $discussionId,
      replyToId: $replyToId,
      body: $body
    }) {
      comment {
        id
        body
        createdAt
      }
    }
  }
`;

const CLOSE_DISCUSSION_MUTATION = `
  mutation($discussionId: ID!, $reason: DiscussionCloseReason) {
    closeDiscussion(input: {
      discussionId: $discussionId,
      reason: $reason
    }) {
      discussion {
        id
        closed
      }
    }
  }
`;

const LOCK_DISCUSSION_MUTATION = `
  mutation($discussionId: ID!) {
    lockLockable(input: {
      lockableId: $discussionId
    }) {
      lockedRecord {
        locked
      }
    }
  }
`;

const MARK_DISCUSSION_COMMENT_AS_ANSWER_MUTATION = `
  mutation($commentId: ID!) {
    markDiscussionCommentAsAnswer(input: {
      id: $commentId
    }) {
      discussion {
        id
      }
    }
  }
`;

// Main functions
async function checkDiscussionsEnabled(octokit, owner, repo) {
  log(`Checking if discussions are enabled in ${owner}/${repo}...`);
  
  await rateLimitSleep(2);
  
  try {
    const response = await octokit.graphql(CHECK_DISCUSSIONS_ENABLED_QUERY, {
      owner,
      repo
    });
    
    if (!response.repository.hasDiscussionsEnabled) {
      error(`Discussions are not enabled in ${owner}/${repo}`);
      return null;
    }
    
    log(`✓ Discussions are enabled in ${owner}/${repo}`);
    return response.repository.id;
  } catch (err) {
    error(`Failed to check discussions status: ${err.message}`);
    throw err;
  }
}

async function fetchCategories(octokit, owner, repo) {
  log(`Fetching categories from ${owner}/${repo}...`);
  
  await rateLimitSleep(2);
  
  try {
    const response = await octokit.graphql(FETCH_CATEGORIES_QUERY, {
      owner,
      repo
    });
    
    const categories = response.repository.discussionCategories.nodes;
    log(`Found ${categories.length} categories`);
    
    return categories;
  } catch (err) {
    error(`Failed to fetch categories: ${err.message}`);
    throw err;
  }
}

async function fetchLabels(octokit, owner, repo) {
  log(`Fetching labels from ${owner}/${repo}...`);
  
  await rateLimitSleep(2);
  
  try {
    const response = await octokit.graphql(FETCH_LABELS_QUERY, {
      owner,
      repo
    });
    
    const labels = response.repository.labels.nodes;
    log(`Found ${labels.length} labels`);
    
    return labels;
  } catch (err) {
    error(`Failed to fetch labels: ${err.message}`);
    throw err;
  }
}

function findCategoryId(categories, categoryName, categorySlug) {
  const category = categories.find(c => 
    c.name === categoryName || c.slug === categorySlug
  );
  
  return category ? category.id : null;
}

function getCategoryIdOrFallback(categories, categoryName, categorySlug) {
  let categoryId = findCategoryId(categories, categoryName, categorySlug);
  
  if (categoryId) {
    return categoryId;
  }
  
  warn(`Category '${categoryName}' (${categorySlug}) not found in target repository`);
  
  // Track missing category
  if (!missingCategories.includes(categoryName)) {
    missingCategories.push(categoryName);
  }
  
  // Try to find "General" category
  const generalCategory = categories.find(c => 
    c.name === "General" || c.slug === "general"
  );
  
  if (generalCategory) {
    warn(`Using 'General' category as fallback for '${categoryName}'`);
    return generalCategory.id;
  }
  
  // Use first category as last resort
  if (categories.length > 0) {
    warn(`Using '${categories[0].name}' category as fallback for '${categoryName}'`);
    return categories[0].id;
  }
  
  error("No available categories found in target repository");
  return null;
}

function findLabelId(labels, labelName) {
  const label = labels.find(l => l.name === labelName);
  return label ? label.id : null;
}

async function createLabel(octokit, repositoryId, name, color, description, targetLabels) {
  log(`Creating new label: '${name}'`);
  
  await rateLimitSleep(2);
  
  try {
    const response = await octokit.graphql(CREATE_LABEL_MUTATION, {
      repositoryId,
      name,
      color,
      description
    });
    
    const newLabel = response.createLabel.label;
    log(`✓ Created label '${name}' with ID: ${newLabel.id}`);
    
    // Update local cache
    targetLabels.push({
      id: newLabel.id,
      name,
      color,
      description
    });
    
    return newLabel.id;
  } catch (err) {
    error(`Failed to create label '${name}': ${err.message}`);
    return null;
  }
}

async function getOrCreateLabelId(octokit, repositoryId, labelName, labelColor, labelDescription, targetLabels) {
  let labelId = findLabelId(targetLabels, labelName);
  
  if (labelId) {
    return labelId;
  }
  
  return await createLabel(octokit, repositoryId, labelName, labelColor, labelDescription, targetLabels);
}

async function addLabelsToDiscussion(octokit, discussionId, labelIds) {
  if (labelIds.length === 0) {
    return true;
  }
  
  log(`Adding ${labelIds.length} labels to discussion`);
  
  await rateLimitSleep(2);
  
  try {
    await octokit.graphql(ADD_LABELS_MUTATION, {
      labelableId: discussionId,
      labelIds
    });
    
    log("✓ Successfully added labels to discussion");
    return true;
  } catch (err) {
    error(`Failed to add labels to discussion: ${err.message}`);
    return false;
  }
}

async function createDiscussion(octokit, repositoryId, categoryId, title, body, sourceUrl, sourceAuthor, sourceCreated, poll = null, locked = false, isPinned = false, reactionGroups = []) {
  let enhancedBody = body;
  
  // Add pinned indicator if discussion was pinned
  if (isPinned) {
    enhancedBody = `📌 _This discussion was pinned in the source repository_\n\n${enhancedBody}`;
  }
  
  // Add reactions if present
  const reactionsMarkdown = formatReactions(reactionGroups);
  if (reactionsMarkdown) {
    enhancedBody += reactionsMarkdown;
  }
  
  // Add poll data if present
  if (poll) {
    const pollMarkdown = formatPollData(poll);
    enhancedBody += pollMarkdown;
  }
  
  // Add metadata
  enhancedBody += `\n---\n<details>\n<summary><i>Original discussion metadata</i></summary>\n\n_Original discussion by @${sourceAuthor} on ${sourceCreated}_\n_Source: ${sourceUrl}_\n${locked ? '\n_🔒 This discussion was locked in the source repository_' : ''}\n</details>`;
  
  log(`Creating discussion: '${title}'`);
  
  await rateLimitSleep(3);
  
  try {
    const response = await octokit.graphql(CREATE_DISCUSSION_MUTATION, {
      repositoryId,
      categoryId,
      title,
      body: enhancedBody
    });
    
    const newDiscussion = response.createDiscussion.discussion;
    
    // Lock the discussion if it was locked in the source
    if (locked) {
      await lockDiscussion(octokit, newDiscussion.id);
    }
    
    return newDiscussion;
  } catch (err) {
    error(`Failed to create discussion: ${err.message}`);
    throw err;
  }
}

async function lockDiscussion(octokit, discussionId) {
  log(`Locking discussion ${discussionId}...`);
  
  await rateLimitSleep(2);
  
  try {
    await octokit.graphql(LOCK_DISCUSSION_MUTATION, {
      discussionId
    });
    log(`Discussion locked successfully`);
  } catch (err) {
    error(`Failed to lock discussion: ${err.message}`);
  }
}

async function fetchDiscussionComments(octokit, discussionId) {
  log(`Fetching comments for discussion ${discussionId}...`);
  
  await rateLimitSleep(2);
  
  try {
    const response = await octokit.graphql(FETCH_DISCUSSION_COMMENTS_QUERY, {
      discussionId
    });
    
    return response.node.comments.nodes || [];
  } catch (err) {
    error(`Failed to fetch comments: ${err.message}`);
    return [];
  }
}

async function addDiscussionComment(octokit, discussionId, body, originalAuthor, originalCreated, reactionGroups = []) {
  let enhancedBody = body;
  
  // Add reactions if present
  const reactionsMarkdown = formatReactions(reactionGroups);
  if (reactionsMarkdown) {
    enhancedBody += reactionsMarkdown;
  }
  
  enhancedBody += `\n---\n<details>\n<summary><i>Original comment metadata</i></summary>\n\n_Original comment by @${originalAuthor} on ${originalCreated}_\n</details>`;
  
  log("Adding comment to discussion");
  
  await rateLimitSleep(2);
  
  try {
    const response = await octokit.graphql(ADD_DISCUSSION_COMMENT_MUTATION, {
      discussionId,
      body: enhancedBody
    });
    
    const commentId = response.addDiscussionComment.comment.id;
    log(`✓ Added comment with ID: ${commentId}`);
    return commentId;
  } catch (err) {
    error(`Failed to add comment: ${err.message}`);
    return null;
  }
}

async function addDiscussionCommentReply(octokit, discussionId, replyToId, body, originalAuthor, originalCreated, reactionGroups = []) {
  let enhancedBody = body;
  
  // Add reactions if present
  const reactionsMarkdown = formatReactions(reactionGroups);
  if (reactionsMarkdown) {
    enhancedBody += reactionsMarkdown;
  }
  
  enhancedBody += `\n---\n_Original reply by @${originalAuthor} on ${originalCreated}_`;
  
  log(`Adding reply to comment ${replyToId}`);
  
  await rateLimitSleep(2);
  
  try {
    const response = await octokit.graphql(ADD_DISCUSSION_COMMENT_REPLY_MUTATION, {
      discussionId,
      replyToId,
      body: enhancedBody
    });
    
    const replyId = response.addDiscussionComment.comment.id;
    log(`✓ Added reply with ID: ${replyId}`);
    return replyId;
  } catch (err) {
    error(`Failed to add reply: ${err.message}`);
    return null;
  }
}

async function closeDiscussion(octokit, discussionId) {
  log("Closing discussion...");
  
  await rateLimitSleep(2);
  
  try {
    await octokit.graphql(CLOSE_DISCUSSION_MUTATION, {
      discussionId,
      reason: "RESOLVED"
    });
    
    log("✓ Discussion closed");
    return true;
  } catch (err) {
    error(`Failed to close discussion: ${err.message}`);
    return false;
  }
}

async function markCommentAsAnswer(octokit, commentId) {
  log("Marking comment as answer...");
  
  await rateLimitSleep(2);
  
  try {
    await octokit.graphql(MARK_DISCUSSION_COMMENT_AS_ANSWER_MUTATION, {
      commentId
    });
    
    log("✓ Comment marked as answer");
    return true;
  } catch (err) {
    error(`Failed to mark comment as answer: ${err.message}`);
    return false;
  }
}

async function copyDiscussionComments(octokit, discussionId, comments, answerCommentId = null) {
  if (!comments || comments.length === 0) {
    log("No comments to copy for this discussion");
    return null;
  }
  
  log(`Copying ${comments.length} comments...`);
  totalComments += comments.length;
  
  // Map to track source comment ID to target comment ID
  const commentIdMap = new Map();
  
  for (const comment of comments) {
    if (!comment.body) continue;
    
    const author = comment.author?.login || "unknown";
    const createdAt = comment.createdAt || "";
    
    log(`Copying comment by @${author}`);
    
    const newCommentId = await addDiscussionComment(
      octokit,
      discussionId,
      comment.body,
      author,
      createdAt,
      comment.reactionGroups || []
    );
    
    if (newCommentId) {
      copiedComments++;
      
      // Track the mapping
      commentIdMap.set(comment.id, newCommentId);
      
      // Copy replies if any
      const replies = comment.replies?.nodes || [];
      if (replies.length > 0) {
        log(`Copying ${replies.length} replies to comment...`);
        
        for (const reply of replies) {
          if (!reply.body) continue;
          
          const replyAuthor = reply.author?.login || "unknown";
          const replyCreated = reply.createdAt || "";
          
          log(`Copying reply by @${replyAuthor}`);
          
          await addDiscussionCommentReply(
            octokit,
            discussionId,
            newCommentId,
            reply.body,
            replyAuthor,
            replyCreated,
            reply.reactionGroups || []
          );
        }
      }
    } else {
      warn(`Failed to copy comment by @${author}, skipping replies`);
    }
  }
  
  log("✓ Finished copying comments");
  
  // Return the new comment ID if this was the answer comment
  if (answerCommentId && commentIdMap.has(answerCommentId)) {
    return commentIdMap.get(answerCommentId);
  }
  
  return null;
}

async function processDiscussionsPage(sourceOctokit, targetOctokit, owner, repo, targetRepoId, targetCategories, targetLabels, cursor = null) {
  log(`Fetching discussions page (cursor: ${cursor || "null"})...`);
  
  await rateLimitSleep(3);
  
  try {
    const response = await sourceOctokit.graphql(FETCH_DISCUSSIONS_QUERY, {
      owner,
      repo,
      cursor
    });
    
    const discussions = response.repository.discussions.nodes;
    const pageInfo = response.repository.discussions.pageInfo;
    const pinnedDiscussions = response.repository.pinnedDiscussions.nodes || [];
    
    // Create a set of pinned discussion IDs for quick lookup
    const pinnedDiscussionIds = new Set(pinnedDiscussions.map(p => p.discussion.id));
    
    log(`Found ${discussions.length} discussions to process on this page`);
    
    for (const discussion of discussions) {
      totalDiscussions++;
      
      log(`\n=== Processing discussion #${discussion.number}: '${discussion.title}' ===`);
      
      // Get or fallback category
      const targetCategoryId = getCategoryIdOrFallback(
        targetCategories,
        discussion.category.name,
        discussion.category.slug
      );
      
      if (!targetCategoryId) {
        error(`No valid category found for discussion #${discussion.number}`);
        skippedDiscussions++;
        continue;
      }
      
      // Check if discussion is pinned
      const isPinned = pinnedDiscussionIds.has(discussion.id);
      
      // Create discussion
      try {
        const newDiscussion = await createDiscussion(
          targetOctokit,
          targetRepoId,
          targetCategoryId,
          discussion.title,
          discussion.body || "",
          discussion.url,
          discussion.author?.login || "unknown",
          discussion.createdAt,
          discussion.poll || null,
          discussion.locked || false,
          isPinned,
          discussion.reactionGroups || []
        );
        
        createdDiscussions++;
        log(`✓ Created discussion #${discussion.number}: '${discussion.title}'`);
        
        // Log additional metadata info
        if (discussion.poll && discussion.poll.options?.nodes?.length > 0) {
          log(`  ℹ️  Poll included with ${discussion.poll.options.nodes.length} options (${discussion.poll.totalVoteCount} total votes)`);
        }
        if (discussion.locked) {
          log(`  🔒 Discussion was locked in source and has been locked in target`);
        }
        if (isPinned) {
          log(`  📌 Discussion was pinned in source (indicator added to body)`);
        }
        const totalReactions = discussion.reactionGroups?.reduce((sum, group) => sum + (group.users.totalCount || 0), 0) || 0;
        if (totalReactions > 0) {
          log(`  ❤️  ${totalReactions} reaction${totalReactions !== 1 ? 's' : ''} copied`);
        }
        
        // Process labels
        if (discussion.labels.nodes.length > 0) {
          const labelIds = [];
          
          for (const label of discussion.labels.nodes) {
            log(`Processing label: '${label.name}' (color: ${label.color})`);
            
            const labelId = await getOrCreateLabelId(
              targetOctokit,
              targetRepoId,
              label.name,
              label.color,
              label.description || "",
              targetLabels
            );
            
            if (labelId) {
              labelIds.push(labelId);
            }
          }
          
          if (labelIds.length > 0) {
            await addLabelsToDiscussion(targetOctokit, newDiscussion.id, labelIds);
          }
        }
        
        // Copy comments
        log("Processing comments for discussion...");
        const comments = await fetchDiscussionComments(sourceOctokit, discussion.id);
        const answerCommentId = discussion.answer?.id || null;
        const newAnswerCommentId = await copyDiscussionComments(
          targetOctokit, 
          newDiscussion.id, 
          comments,
          answerCommentId
        );
        
        // Mark answer if applicable
        if (newAnswerCommentId) {
          log("Source discussion has an answer comment, marking it in target...");
          await markCommentAsAnswer(targetOctokit, newAnswerCommentId);
        }
        
        // Close discussion if it was closed in source
        if (discussion.closed) {
          log("Source discussion is closed, closing target discussion...");
          await closeDiscussion(targetOctokit, newDiscussion.id);
        }
        
        log(`✅ Finished processing discussion #${discussion.number}: '${discussion.title}'`);
        
        // Delay between discussions
        await sleep(5);
        
      } catch (err) {
        error(`Failed to create discussion #${discussion.number}: '${discussion.title}' - ${err.message}`);
        skippedDiscussions++;
      }
    }
    
    // Process next page if exists
    if (pageInfo.hasNextPage) {
      log(`Processing next page with cursor: ${pageInfo.endCursor}`);
      await processDiscussionsPage(
        sourceOctokit,
        targetOctokit,
        owner,
        repo,
        targetRepoId,
        targetCategories,
        targetLabels,
        pageInfo.endCursor
      );
    } else {
      log("No more pages to process");
    }
    
  } catch (err) {
    error(`Failed to fetch discussions: ${err.message}`);
    throw err;
  }
}

// Main execution
async function main() {
  try {
    log("Starting discussion copy process...");
    log(`Source: ${SOURCE_ORG}/${SOURCE_REPO}`);
    log(`Target: ${TARGET_ORG}/${TARGET_REPO}`);
    log("");
    log("⚡ This script uses conservative rate limiting to avoid GitHub API limits");
    log("");
    
    // Verify source repository
    log("Verifying access to source repository...");
    const sourceRepoId = await checkDiscussionsEnabled(sourceOctokit, SOURCE_ORG, SOURCE_REPO);
    if (!sourceRepoId) {
      process.exit(1);
    }
    log(`Source repository ID: ${sourceRepoId}`);
    
    // Verify target repository
    log("Getting target repository ID...");
    const targetRepoId = await checkDiscussionsEnabled(targetOctokit, TARGET_ORG, TARGET_REPO);
    if (!targetRepoId) {
      process.exit(1);
    }
    log(`Target repository ID: ${targetRepoId}`);
    
    // Fetch target categories
    const targetCategories = await fetchCategories(targetOctokit, TARGET_ORG, TARGET_REPO);
    if (targetCategories.length === 0) {
      error("No categories found in target repository");
      process.exit(1);
    }
    
    log("Available categories in target repository:");
    targetCategories.forEach(cat => {
      log(`  ${cat.name} (${cat.slug})`);
    });
    
    // Fetch target labels
    const targetLabels = await fetchLabels(targetOctokit, TARGET_ORG, TARGET_REPO);
    log(`Available labels in target repository: ${targetLabels.length} labels`);
    
    // Start processing discussions
    log("\nStarting to fetch and copy discussions...");
    await processDiscussionsPage(
      sourceOctokit,
      targetOctokit,
      SOURCE_ORG,
      SOURCE_REPO,
      targetRepoId,
      targetCategories,
      targetLabels
    );
    
    // Summary
    log("\n");
    log("=".repeat(60));
    log("Discussion copy completed!");
    log(`Total discussions found: ${totalDiscussions}`);
    log(`Discussions created: ${createdDiscussions}`);
    log(`Discussions skipped: ${skippedDiscussions}`);
    log(`Total comments found: ${totalComments}`);
    log(`Comments copied: ${copiedComments}`);
    
    if (missingCategories.length > 0) {
      warn("\nThe following categories were missing and need to be created manually:");
      missingCategories.forEach(cat => {
        warn(`  - ${cat}`);
      });
      warn("");
      warn("To create categories manually:");
      warn(`1. Go to https://github.com/${TARGET_ORG}/${TARGET_REPO}/discussions`);
      warn("2. Click 'New discussion'");
      warn("3. Look for category management options");
      warn("4. Create the missing categories with appropriate names and descriptions");
    }
    
    if (skippedDiscussions > 0) {
      warn("\nSome discussions were skipped. Please check the categories in the target repository.");
    }
    
    log("\nAll done! ✨");
    
  } catch (err) {
    error(`Fatal error: ${err.message}`);
    if (err.stack) {
      console.error(err.stack);
    }
    process.exit(1);
  }
}

// Run main function
main();

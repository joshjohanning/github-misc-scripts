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
// Note: This script copies discussion content, comments, replies, and basic metadata.
// Reactions and other advanced interactions are not copied.
// Attachments (images and files) will not copy over - they need manual handling.
//
// TODO: Polls don't copy options
// TODO: Mark as answers

const { Octokit } = require("octokit");

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length !== 4) {
  console.error("Usage: node copy-discussions.js <source_org> <source_repo> <target_org> <target_repo>");
  console.error("\nExample:");
  console.error("  node copy-discussions.js source-org repo1 target-org repo2");
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
          author {
            login
          }
          createdAt
          closed
          locked
          upvoteCount
          url
          number
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
            replies(first: 50) {
              nodes {
                id
                body
                author {
                  login
                }
                createdAt
                upvoteCount
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

async function createDiscussion(octokit, repositoryId, categoryId, title, body, sourceUrl, sourceAuthor, sourceCreated) {
  const enhancedBody = `${body}\n\n---\n<details>\n<summary><i>Original discussion metadata</i></summary>\n\n_Original discussion by @${sourceAuthor} on ${sourceCreated}_\n_Source: ${sourceUrl}_\n</details>`;
  
  log(`Creating discussion: '${title}'`);
  
  await rateLimitSleep(3);
  
  try {
    const response = await octokit.graphql(CREATE_DISCUSSION_MUTATION, {
      repositoryId,
      categoryId,
      title,
      body: enhancedBody
    });
    
    return response.createDiscussion.discussion;
  } catch (err) {
    error(`Failed to create discussion: ${err.message}`);
    throw err;
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

async function addDiscussionComment(octokit, discussionId, body, originalAuthor, originalCreated) {
  const enhancedBody = `${body}\n\n---\n<details>\n<summary><i>Original comment metadata</i></summary>\n\n_Original comment by @${originalAuthor} on ${originalCreated}_\n</details>`;
  
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

async function addDiscussionCommentReply(octokit, discussionId, replyToId, body, originalAuthor, originalCreated) {
  const enhancedBody = `${body}\n\n---\n_Original reply by @${originalAuthor} on ${originalCreated}_`;
  
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

async function copyDiscussionComments(octokit, discussionId, comments) {
  if (!comments || comments.length === 0) {
    log("No comments to copy for this discussion");
    return;
  }
  
  log(`Copying ${comments.length} comments...`);
  totalComments += comments.length;
  
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
      createdAt
    );
    
    if (newCommentId) {
      copiedComments++;
      
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
            replyCreated
          );
        }
      }
    } else {
      warn(`Failed to copy comment by @${author}, skipping replies`);
    }
  }
  
  log("✓ Finished copying comments");
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
          discussion.createdAt
        );
        
        createdDiscussions++;
        log(`✓ Created discussion #${discussion.number}: '${discussion.title}'`);
        
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
        await copyDiscussionComments(targetOctokit, newDiscussion.id, comments);
        
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

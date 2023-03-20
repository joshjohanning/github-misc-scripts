#!/bin/bash

# credits: @stoe

gh api graphql --paginate -F owner='joshjohanning-org' -F name='ghas-demo' -f query='query labels($owner: String!, $name: String!, $endCursor: String = null) {
  repository(owner: $owner, name: $name) {
    labels(
      first: 100
      after: $endCursor
      orderBy: { field: NAME, direction: ASC }
    ) {
      nodes {
        url
        description
        issues_open: issues(first: 1, states: [OPEN]) { totalCount }
        issues_closed: issues(first: 1, states: [CLOSED]) { totalCount }
        prs_open: pullRequests(first: 1, states: [OPEN]) { totalCount }
        prs_closed: pullRequests(first: 1, states: [CLOSED, MERGED]) { totalCount }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}' | jq -r '.data.repository.labels.nodes[] | [.url, .description, .issues_open.totalCount, .issues_closed.totalCount, .prs_open.totalCount, .prs_closed.totalCount] | @tsv'

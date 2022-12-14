# How to Paginate in GraphQL

See:

https://graphql.org/learn/pagination/#complete-connection-model

To see how to do pagination in `gh api` call, see this as an example: [link](../gh-cli/get-enterprise-organizations.sh)

For example, this GraphQL command only retrieves 1 user, but there are more than 1 user in our Organization:

Query: 

```graphql
query listSSOUserIdentities ($organizationName:String!) {
  organization(login: $organizationName) {
      samlIdentityProvider {
        externalIdentities(first: 1) {
          totalCount
          edges {
            node {
              samlIdentity {
                nameId
              }
            }
          }
          pageInfo {
            hasNextPage
	          endCursor
          }
        }
      }
  }
}
```

Response:

```json
{
    "data": {
        "organization": {
            "samlIdentityProvider": {
                "externalIdentities": {
                    "totalCount": 2,
                    "edges": [
                        {
                            "node": {
                                "samlIdentity": {
                                    "nameId": "soccerjoshj07_gmail.com#EXT#@soccerjoshj07gmail.onmicrosoft.com"
                                }
                            }
                        }
                    ],
                    "pageInfo": {
                        "hasNextPage": true,
                        "endCursor": "Y3Vyc29yOnYyOpHOAI2Q7w=="
                    }
                }
            }
        }
    }
}
```

We see the `pageInfo.hasNextPage` is set to `true`, and the `endCursor` is `Y3Vyc29yOnYyOpHOAI2Q7w==`. We can use that in our next query:

Query: 

```graphql
query listSSOUserIdentities ($organizationName:String!) {
  organization(login: $organizationName) {
      samlIdentityProvider {
        externalIdentities(first: 1 after: "Y3Vyc29yOnYyOpHOAI2Q7w==" ) {
          totalCount
          edges {
            node {
              samlIdentity {
                nameId
              }
            }
          }
          pageInfo {
            hasNextPage
	          endCursor
          }
        }
      }
  }
}
```

Response: 

```json
{
    "data": {
        "organization": {
            "samlIdentityProvider": {
                "externalIdentities": {
                    "totalCount": 2,
                    "edges": [
                        {
                            "node": {
                                "samlIdentity": {
                                    "nameId": "fluffycarlton@soccerjoshj07gmail.onmicrosoft.com"
                                }
                            }
                        }
                    ],
                    "pageInfo": {
                        "hasNextPage": false,
                        "endCursor": "Y3Vyc29yOnYyOpHOAI2YSg=="
                    }
                }
            }
        }
    }
}
```

You will notice that we have retrieved the next user, and the `hasNextPage` is now set to `false` since we only have 2 users in our organization.

The `externalIdentities` object can only retreive 100 items at a time, so you can extrapulate how you can do this with my example of using `first: 1` above. 

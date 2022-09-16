
gh api graphql -f enterprise='my-enterprise-name' -f query='
query ($enterprise: String!)
  { enterprise(slug: $enterprise) { 
    id 
  } 
}
'
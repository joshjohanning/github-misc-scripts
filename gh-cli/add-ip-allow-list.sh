gh api graphql -f owner_id='O_kgDOBbB18g' -f allow_list_value='1.2.3.4' -f name='test ip' -f query='
mutation ($owner_id: ID! $allow_list_value: String! $name: String!) { 
  createIpAllowListEntry(input: { ownerId: $owner_id allowListValue: $allow_list_value name: $name isActive: true }) { 
      ipAllowListEntry {
        id
        allowListValue
        name
        isActive
      }
   } 
}'

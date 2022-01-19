# graphql

Some of the queries are provided as `.json` files. To use `post_gql.sh` to call GraphQL query, use this as an example:

```bash
./post_gql.sh --file list-enterprise-id.json --pat <github-token>
```

## Notes

### list-enterprise-id.json

Obtain the enterprise ID used for other GraphQL calls. Use the URL slug not the friendly name of the Enterprise.

[Documentation](https://docs.github.com/en/graphql/reference/queries#enterprise)

### create-organization.json

Creates the organization - you just need to pass in the enterprise ID (obtained above) along with billing email, admin logins, and organization name.

[Documentation](https://docs.github.com/en/graphql/reference/mutations#createenterpriseorganization)

## download-latest-package-from-github-packages.sh

Script to download a file from the latest version of a GitHub Package

## download-specific-version-from-github-packages

Script to download a file from a specific version of a GitHub Package

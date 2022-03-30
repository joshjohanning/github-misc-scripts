curl -LX GET https://github.com/terraform-linters/tflint/releases/download/v0.35.0/tflint_darwin_arm64.zip \
    --header "Accept: application/vnd.github.v3+json" \
    --header "Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}" \
    -O

#!/bin/bash

# This script updates GitHub Actions workflows that have 'contents: write' permissions
# to use 'persist-credentials: false' in their checkout actions for better security

# Running:
#
# run:
# multi-gitter run ./update-checkout-persist-credentials.sh -m "ci: disable persist-credentials in actions/checkout" -b "For security purposes, don't persist checkout credentials for the entire job when using contents:write." -B update-actions-checkout --git-type=cmd --config update-checkout-persist-credentials.yml --dry-run

# merge:
# multi-gitter merge --config update-checkout-persist-credentials.yml --merge-type=squash -B update-actions-checkout

set -e

# Function to check if a file contains 'contents: write' permission
has_contents_write() {
    local file="$1"
    grep -q "contents: write" "$file"
}

# Function to check if checkout action already has persist-credentials
has_persist_credentials() {
    local file="$1"
    # Check if the file has a checkout action followed by persist-credentials
    awk '/- uses: actions\/checkout@/ {found=1; next} found && /persist-credentials:/ {print; exit} found && /- / {exit}' "$file" | grep -q "persist-credentials:"
}

# Function to update checkout action to include persist-credentials: false
update_checkout_action() {
    local file="$1"
    local temp_file="${file}.tmp"

    # Use awk to process the file
    awk '
    /- uses: actions\/checkout@/ {
        print $0
        in_checkout = 1
        has_with = 0
        checkout_indent = match($0, /[^ ]/)
        next
    }
    in_checkout && /^[[:space:]]*with:[[:space:]]*$/ {
        print $0
        has_with = 1
        with_indent = match($0, /[^ ]/)
        next
    }
    in_checkout && /^[[:space:]]*persist-credentials:/ {
        # Already has persist-credentials, skip updating
        print $0
        in_checkout = 0
        next
    }
    in_checkout && /^[[:space:]]*[^[:space:]]/ && !/^[[:space:]]*$/ {
        # New key at same or less indentation means checkout block ended
        current_indent = match($0, /[^ ]/)
        if (current_indent <= checkout_indent || (has_with && current_indent <= with_indent)) {
            if (!has_with) {
                # Add with block
                for (i = 1; i < checkout_indent; i++) printf " "
                print "  with:"
                for (i = 1; i < checkout_indent; i++) printf " "
                print "    persist-credentials: false"
            } else {
                # Add persist-credentials to existing with block
                for (i = 1; i < with_indent; i++) printf " "
                print "  persist-credentials: false"
            }
            in_checkout = 0
        }
        print $0
        next
    }
    {
        print $0
    }
    END {
        # If file ended while still in checkout block
        if (in_checkout) {
            if (!has_with) {
                for (i = 1; i < checkout_indent; i++) printf " "
                print "  with:"
                for (i = 1; i < checkout_indent; i++) printf " "
                print "    persist-credentials: false"
            } else {
                for (i = 1; i < with_indent; i++) printf " "
                print "  persist-credentials: false"
            }
        }
    }
    ' "$file" > "$temp_file"

    mv "$temp_file" "$file"
}

# Main logic
workflows_dir=".github/workflows"

if [ ! -d "$workflows_dir" ]; then
    echo "No .github/workflows directory found. Skipping."
    exit 0
fi

changed=false

# Iterate through all workflow files
for workflow in "$workflows_dir"/*.yml "$workflows_dir"/*.yaml; do
    # Skip if no files match
    [ -e "$workflow" ] || continue

    echo "Checking workflow: $workflow"

    # Check if workflow has 'contents: write' permission
    if has_contents_write "$workflow"; then
        echo "  Found 'contents: write' permission"

        # Check if it has checkout action
        if grep -q "uses: actions/checkout@" "$workflow"; then
            echo "  Found checkout action"

            # Check if already has persist-credentials
            if has_persist_credentials "$workflow"; then
                echo "  Already has persist-credentials configured. Skipping."
            else
                echo "  Updating checkout action to include persist-credentials: false"
                update_checkout_action "$workflow"
                changed=true
            fi
        else
            echo "  No checkout action found. Skipping."
        fi
    else
        echo "  No 'contents: write' permission found. Skipping."
    fi
done

if [ "$changed" = true ]; then
    echo ""
    echo "✓ Updated workflow files to include persist-credentials: false"
    exit 0
else
    echo ""
    echo "No changes needed."
    exit 0
fi

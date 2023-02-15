# useful for force pushing / updating a tag so that you can update the tag atomically

git tag test            # Create tag
git push origin test    # Push to remote
git tag test HEAD~2 -f  # Forcibly create tag pointing to old version
git push origin test -f # Force overwriting the remote tag

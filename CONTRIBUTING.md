# How to contribute

Thank you for your interest in contributing back to this collection 🚀. I welcome all suggestions, bug reports, enhancements, documentation improvements, etc.

## Getting started

### The Basics

Contributing to a project on GitHub is pretty straight forward. If this is your first time, these are the steps you should take:

1. [Fork this repo](https://github.com/joshjohanning/github-misc-scripts/fork)
2. Make your change(s) in your fork - it doesn't matter which branch
3. If you're adding a new script to the `gh-cli` or `scripts` directory, add it to the appropriate `README.md` file
4. Likewise, if you're significantly modifying a script, consider double checking that the respective `README.md` is still accurate
5. [Create a pull request](https://github.com/joshjohanning/github-misc-scripts/compare) back to the **main** branch of this repo
6. A [linting job](https://github.com/joshjohanning/github-misc-scripts/actions/workflows/lint-readme.yml) will run on your PR to ensure the file has been added to the appropriate `README.md` file correctly
7. That's it! Give me some time to review and approve the PR

### Linting and the README.md

When adding new scripts to the `gh-cli` or `scripts` directory, you must also add the script to the appropriate `README.md` file. This is done to ensure that it is still possible to search/find relevant scripts effectively. A linting job will run on your PR to ensure the file has been added to the appropriate `README.md` file correctly.

This means:

1. There are no scripts that aren't added to the `README.md`
2. There are no headings in the `README.md` that don't exist as scripts in the directory
3. That scripts are in alphabetical order (using VS Code / GitHub sorting)
4. That the file is named correctly (kebab casing)
5. That `.sh` files have executable permissions (i.e.: `chmod +x ./my-file.sh`)
6. That you aren't using the shorthand `repo`, `repos`, `org`, or `orgs` in the filenames; spell out the full word (i.e.: `repository`, `repositories`, `organization`, and `organizations`)

### Documentation

I strive to maintain well-commented code. If a code segment is complex or not immediately clear, it should be accompanied by comments for clarity. When introducing new code or modifying existing code in a way that changes its function or usage, ensure it is properly documented both in the script and the respective `README.md` file.

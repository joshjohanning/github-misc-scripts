# git cherry-pick

[Documentation](https://git-scm.com/docs/git-cherry-pick)

## cherry-pick from different branch

1. Find the first and last commit in the range you want to `cherry-pick` in. 
    - You can use this `https://github.com/my-org/my-repo/compare/xyz1234^..abc1234` to compare the changes between two commits in GitHub
1. Start the `git cherry-pick`:
    - To cherry-pick a range of commits (more common): `git cherry-pick "xyz1234^..abc1234"`
    - The `^` is important otherwise you will not be including the first commit - but the commit might get picked up in the maintainer's merge commit for the release anyways - and the quotes are necessary around the commits in `zsh` b/c of the `^`
    - To cherry-pick a single commit (probably not as common): `git cherry-pick abc1234`
1. Review merge conflicts - use a combination of `git cherry-pick --skip` (for when readme/starter posts are updated) and `cherry-pick --continue` (to continue after you resolve real merge conflicts)

## example cherry-picking from a different remote

1. Ensure other repository is set as a remote: `git remote add other-repository https://github.com/my-org/my-repo.git`
1. Ensure you have the latest upstream commit: `git fetch other-repository`
1. Find the first and last commit in the range you want to `cherry-pick` in. 
    - You can use this `https://github.com/my-org/my-repo/compare/xyz1234^..abc1234` to compare the changes between two commits in GitHub
1. Start the `git cherry-pick`:
    - To cherry-pick a range of commits (more common): `git cherry-pick "xyz1234^..abc1234" -m 1`
    - The `^` is important otherwise you will not be including the first commit - but the commit might get picked up in the maintainer's merge commit for the release anyways - and the quotes are necessary around the commits in `zsh` b/c of the `^`
    - To cherry-pick a single commit (probably not as common): `git cherry-pick abc1234 -m 1`
1. Review merge conflicts - use a combination of `git cherry-pick --skip` (for when readme/starter posts are updated) and `cherry-pick --continue` (to continue after you resolve real merge conflicts)

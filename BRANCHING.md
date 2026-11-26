# Branching Strategy

## Workflow Followed

I followed a feature-branch Git workflow with `main` and `develop` as the two long-lived branches.

- `main`: Kept as the stable, deployable branch for the final submission.
- `develop`: Used as the integration branch for completed features.
- `feature/application`: Used for the frontend, backend, database, and Docker Compose implementation.
- `feature/kubernetes`: Used for Kubernetes manifests and deployment automation.
- `feature/git-workflow`: Used for Git workflow-related work.
- `feature/documentation`: Used for the final documentation and evidence updates.

Feature branches were created from `develop`, and completed work was integrated through pull requests. The Kubernetes implementation was merged into `develop` through PR #5. The application implementation was developed incrementally on its feature branch.

The final integration will be promoted from `develop` to `main` through a pull request after validation.

## Commit and Review Practices

I used separate commits for meaningful implementation steps instead of one large end-of-project commit. Commit messages describe the purpose of each change, such as adding an API, containerizing a service, or configuring Kubernetes resources.

For pull requests, I review the changed files and add review comments to explain the changes and identify anything that needs attention before merging.

## Would I Recommend This for a Team of Five?

Yes. I would recommend this workflow for a team of five shipping daily.

Each developer can work on an isolated feature branch, reducing conflicts and preventing incomplete changes from reaching the integration branch. Pull requests provide a review point before integration, while `develop` gives the team a shared place to test features together.

For a team shipping daily, I would also require automated CI checks on pull requests, branch protection for `main`, and short-lived feature branches to avoid long-running integration conflicts.

# Branching Strategy

## Model

This project follows a simplified GitFlow workflow.
- main: Always deployable release branch.
- develop: Integration branch for completed features.
- feature/*: Isolated development branches.

## Workflow

1. Create feature branches from develop.
2. Implement one logical assignment part per branch.
3. Commit changes with descriptive messages.
4. Open a Pull Request into develop.
5. Review the diff and document review comments.
6. Merge after testing.
7. Promote validated releases to main through a PR.

## Release Tags

- v1.0.0: Docker Compose deployment verified.
- v1.1.0: Kubernetes deployment verified.

## Suitability for a Team of Five

This model provides clear feature isolation and release control.
However, for a five-person team shipping daily, I would prefer
a simplified trunk-based development workflow with short-lived
feature branches and automated CI checks. It reduces long-lived
branch divergence and merge overhead.
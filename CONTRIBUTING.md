# Contributing to Gleisner

Thank you for your interest in contributing to Gleisner! This document explains how to get involved.

## Branch Strategy

We use **GitHub Flow**:

1. **`main`** is always the stable, deployable branch
2. Create a **feature branch** from `main` for your work
3. Open a **Pull Request** to merge back into `main`

Direct pushes to `main` are not allowed — all changes go through PRs.

### Branch naming

Use descriptive names with a prefix:

- `feat/multi-track-player` — new feature
- `fix/timeline-scroll-bug` — bug fix
- `docs/update-adr-format` — documentation
- `refactor/api-response-types` — refactoring

## How to Contribute

### Reporting Issues

- Search existing issues before creating a new one
- Include steps to reproduce for bug reports
- For feature requests, explain the use case and motivation

### Submitting a Pull Request

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Ensure your code follows the existing style
5. Open a PR with a clear description using the PR template

### Architecture Decision Records

Significant design decisions are documented in `docs/decisions/`. If your contribution involves an architectural change, please propose an ADR as part of your PR.

## License

By contributing, you agree that your contributions will be licensed under the [AGPL v3](LICENSE).

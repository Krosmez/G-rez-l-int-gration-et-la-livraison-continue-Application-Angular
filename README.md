# Olympic Participation Tracker

## Context

The **Olympic Participation Tracker** is an application designed to record and analyze countries' participation in the Olympic Games. It provides statistics on medals obtained by each country, helping users gain insights into historical performance. Although the application is currently in its early development stages, we aim to create a robust and user-friendly tool for Olympic enthusiasts.

## Technical Context

The application is built using **Angular 20** and relies on **npm** for package management. Angular offers a powerful framework for creating dynamic web applications, and npm simplifies the process of managing dependencies and scripts. The production build is served as static files by **Nginx**.

Summary:

- **NodeJS**: version 20.19+ required (the Angular 20 CLI needs Node >= 20.19; tested with 20.19)
- **NPM**: Tested with version 10.2.4
- **NGINX**: Tested with version 1.27
- **Docker**: required to build and run the containerized application

## Getting Started

### Install dependencies

Run `npm i` in local development to install NodeJS dependencies. If you are installing the app on a CI environment prefer to use `npm ci`. You can also change the npm cache directory to your working directory as following:

```bash
npm ci --cache .npm --prefer-offline
```

## Development server

Run `ng serve` for a dev server. Navigate to `http://localhost:4200/`. The application will automatically reload if you change any of the source files.

### Build

Run `npm run build` to build the project. The build artifacts are stored in the `dist/` directory.

> **Output directory note**: with Angular 20 (`@angular/build:application` builder), the compiled site is generated under **`dist/olympic-games-starter/browser/`**. This `browser/` sub-folder — and not its parent — is what must be served by the web server (see the Docker section).

### Test

To run tests and ensure the application's functionality, use the following command:

```bash
npm test
```

This runs the unit tests once (`ng test --watch false`) in a headless Chrome browser (Karma + Jasmine). A JUnit XML report is produced (see below), which is what the CI pipeline consumes.

Our test suite covers critical components, ensuring stability and reliability.

#### Unified test script (`run-tests.sh`)

The repository ships a **unified test runner**, [`run-tests.sh`](./run-tests.sh), that automatically detects the project type and runs the appropriate test suite:

- **Node / Angular** project (detected via `package.json`) → `npm test` (Karma).
- **Java / Gradle** project (detected via `gradlew` / `build.gradle`) → `./gradlew test`.

It generates a **JUnit XML report** in the `test-results/` directory, cleans previous artifacts, verifies that dependencies are present before running, and returns a non-zero exit code if any project fails.

```bash
# Test the current project
./run-tests.sh

# Test several projects at once (e.g. front-end + back-end)
./run-tests.sh . ../backend
```

### Packaging

To package the application for distribution, run:

```bash
npm pack
```

This will create a distributable package containing the compiled code and necessary assets.

## Docker

The application is containerized with a **multi-stage** [`Dockerfile`](./Dockerfile):

1. **Build stage** (`node:20.19-alpine`): installs dependencies with `npm ci` and builds the Angular project.
2. **Runtime stage** (`nginx:1.27-alpine`): serves the compiled static files from `dist/olympic-games-starter/browser/` at the Nginx root folder `/app`, using the configuration in [`nginx/nginx.conf`](./nginx/nginx.conf).

A [`.dockerignore`](./.dockerignore) keeps the build context small by excluding `node_modules`, `dist`, caches and other unnecessary files.

### Run with Docker Compose

A simple [`docker-compose.yml`](./docker-compose.yml) runs the front-end on its own:

```bash
docker compose up -d --build
```

The application is then accessible at **http://localhost**.

To stop and remove the container:

```bash
docker compose down
```

## Continuous Integration & Delivery

A single, generic GitHub Actions workflow — [`.github/workflows/ci.yml`](./.github/workflows/ci.yml) — powers the pipeline. The same file works for both the Angular front-end and the Java back-end: a detection step identifies the project type and the following steps activate conditionally. The pipeline is made of three sequential jobs:

1. **`test`** — detects the project type, installs dependencies (with dependency caching), runs `run-tests.sh`, and publishes the JUnit report as a GitHub check.
2. **`build`** — builds the Docker image, runs a smoke test to validate it, then pushes it to the **GitHub Container Registry (GHCR)** tagged as `<branch>-<short-sha>` (e.g. `main-508ef00`).
3. **`release`** — runs only on `main`; uses **semantic-release** to compute the next version from the commit history, generate the changelog and the GitHub release, then re-tags the already-built image with the semantic version (e.g. `1.2.3`) and `latest`.

### Conventional Commits

Versioning is fully automated with [semantic-release](https://semantic-release.gitbook.io/), configured in [`.releaserc.json`](./.releaserc.json). All commits **must** follow the [Conventional Commits](https://www.conventionalcommits.org/) specification, as they drive the next version number:

| Commit type | Example | Version bump |
| --- | --- | --- |
| `fix:` | `fix: correct medal count` | patch (`1.2.3` → `1.2.4`) |
| `feat:` | `feat: add country details page` | minor (`1.2.3` → `1.3.0`) |
| `feat!:` / `BREAKING CHANGE:` | `feat!: drop legacy API` | major (`1.2.3` → `2.0.0`) |

Other types (`chore:`, `docs:`, `test:`, `ci:`, `refactor:`, …) do not trigger a release.

## Publishing to the GitHub Container Registry

Docker images are published automatically by the CI pipeline to the **GitHub Container Registry** (`ghcr.io`); no manual publishing step is required.

- **On every branch push**: the image is pushed as `ghcr.io/<owner>/<repo>:<branch>-<short-sha>`.
- **On a push to `main`**: `semantic-release` additionally tags the image with the semantic version and `latest`, e.g. `ghcr.io/<owner>/<repo>:1.2.3` and `ghcr.io/<owner>/<repo>:latest`.

### Requirements

1. **Workflow permissions** — in the repository settings, enable **Settings → Actions → General → Workflow permissions → Read and write permissions**. This lets the built-in `GITHUB_TOKEN` push packages and create releases. No additional secret is needed: the pipeline uses the automatically provided `secrets.GITHUB_TOKEN`.
2. **Package visibility** — the first published image is private by default. Change it to public (if desired) from the package page: **Packages → <image> → Package settings → Change visibility**.

### Pulling the image

```bash
# Log in (personal access token with read:packages scope)
echo "$CR_PAT" | docker login ghcr.io -u <your-github-username> --password-stdin

# Pull a specific version...
docker pull ghcr.io/<owner>/<repo>:1.2.3

# ...or the latest release
docker pull ghcr.io/<owner>/<repo>:latest

# Run it (front-end served on port 80)
docker run -d -p 80:80 ghcr.io/<owner>/<repo>:latest
```

> Replace `<owner>/<repo>` with your GitHub repository path in lowercase (GHCR requires lowercase image names).

# GitHub Issues Viewer

A modern Rails 8.1.0 application for viewing and managing GitHub issues with smart caching and real-time API integration. Browse issues from multiple repositories across GitHub.com and GitHub Enterprise with a GitHub.com-quality UI.

## Features

- **Multi-Repository Support** - Track and view issues from multiple GitHub repositories
- **Smart Hybrid Caching** - Fast local cache with automatic real-time fallback when data is stale
- **GitHub.com Clone UI** - Full-featured issue viewing with labels, assignees, comments, and metadata
- **Dual Search Modes** - Toggle between fast local SQLite search and comprehensive GitHub API search
- **GitHub Enterprise Support** - Works with both GitHub.com and self-hosted GitHub Enterprise servers
- **Per-User GitHub Tokens** - Each user connects their own GitHub account with secure token storage
- **Real-Time Sync** - Manual refresh with staleness indicators and graceful error handling
- **Component-Based UI** - ViewComponent architecture for maintainable GitHub-style components
- **Comprehensive Testing** - 99%+ test coverage with SimpleCov

## Tech Stack

- **Rails 8.1.0** with modern asset pipeline (Propshaft)
- **SQLite3** for all environments including production
- **Octokit** for GitHub REST and GraphQL API integration
- **ImportMap** for JavaScript (no Node.js bundling required)
- **Hotwire** (Turbo + Stimulus) for interactive features with minimal JS
- **Tailwind CSS** via CDN for GitHub-style UI
- **ViewComponent** for reusable GitHub UI components
- **Solid Libraries** for database-backed cache, queue, and cable

## Getting Started

### Prerequisites

- Ruby 3.4.7
- Rails 8.1.0+
- SQLite3

### Installation

1. Clone the repository
2. Install dependencies:
  ```bash
  bin/setup
  ```

3. Start the development server:
  ```bash
  bin/rails server
  ```

4. Visit `http://localhost:3000` and create an account

### GitHub Token Setup

To use the application, you'll need a GitHub Personal Access Token:

1. Go to GitHub Settings > Developer Settings > Personal Access Tokens > Fine-grained tokens
2. Create a new token with these permissions:
  - **Repository access**: Select repositories you want to view
  - **Repository permissions**:
    - Issues: Read-only
    - Metadata: Read-only
    - Pull requests: Read-only (if viewing PRs)
3. Copy the token
4. In the application, go to your user profile settings
5. Enter your GitHub token and domain:
  - Domain: `github.com` (or your GitHub Enterprise domain like `foo.ghe.com`)
  - Token: Paste your personal access token
6. Save and start adding repositories!

## Development

### Code Quality

Run the full CI pipeline (formatting, linting, security scan, tests):

```bash
bin/ci
```

Auto-fix formatting issues:

```bash
bin/ci --fix
```

Watch CI status in real-time:

```bash
bin/watch-ci
```

### Testing

Run tests:

```bash
bin/rails test
```

Generate coverage report:

```bash
bin/coverage
```

### Code Standards

- **EditorConfig**: UTF-8, LF line endings, 2-space indentation
- **RuboCop**: Rails Omakase configuration
- **SimpleCov**: 95% minimum coverage requirement
- **Conventional Commits**: Structured commit messages

## Architecture

### Database Setup

Multi-database configuration with separate SQLite databases:
- **Primary database**: Users, repositories, issues, and comments (with caching layer)
- **Cache database**: Solid Cache for application-level caching
- **Queue database**: Solid Queue for background jobs
- **Cable database**: Solid Cable for WebSocket connections

### Caching Strategy

**Hybrid on-demand caching** for optimal performance:
- Issues and repository data are cached per-user in SQLite
- On page load, serve cached data if available
- If cache is cold (no data), fetch from GitHub API in the request
- Manual refresh button shows staleness (time since last sync)
- When API errors occur (rate limit, invalid token), show stale cached data with warnings

**Cache keying**: Each user maintains separate caches for their repositories, even if multiple users track the same repo. This simplifies permissions (handled by per-user GitHub tokens).

### GitHub Service Layer

Located in `app/services/github/`:
- **ApiClient**: GitHub REST API client with rate limiting, retries, and exponential backoff
- **GraphqlClient**: GitHub GraphQL client for efficient batch queries
- **ApiConfiguration**: Centralized configuration for rate limits, retries, and pagination
- **RepositorySyncService**: Syncs repository metadata from GitHub
- **IssueSyncService**: Syncs issues with full metadata (labels, assignees, comments)
- **IssueSearchService**: Handles both local SQLite search and GitHub API search

### Component System

The application uses ViewComponent for UI components:
- **Auth Components**: `Auth::*` for authentication flows
- **GitHub Components**: Issue cards, labels, assignees, state badges, comments
- **Common Components**: `AvatarComponent`, `AlertComponent`, `UserPageComponent`
- **Layout Components**: Repository cards, issue lists, search forms

## Contributing

1. Follow the existing code style and conventions
2. Ensure tests pass: `bin/ci`
3. Maintain test coverage above 95%
4. Use conventional commit messages

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

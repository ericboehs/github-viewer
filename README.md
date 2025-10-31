# GitHub Issues Viewer

A modern Rails 8.1.0 application for viewing and managing GitHub issues with smart caching and real-time API integration. Browse issues from multiple repositories across GitHub.com and GitHub Enterprise with a GitHub.com-quality UI.

**Status**: ✅ Production-ready with all core features implemented (October 2025)

## Features

### Core Functionality

- **Multi-Repository Support** - Track and view issues from multiple GitHub repositories with flexible URL parsing
- **Smart Hybrid Caching** - Fast local cache with on-demand API fetching and graceful degradation
- **GitHub.com Clone UI** - Full-featured issue viewing with labels, assignees, comments, and metadata
- **Advanced Search & Filtering** - GitHub query syntax parser with filter dropdowns and keyboard navigation
- **GitHub Enterprise Support** - Works with both GitHub.com and self-hosted GitHub Enterprise servers
- **Per-User GitHub Tokens** - Each user connects their own GitHub account with encrypted token storage
- **Real-Time Sync** - Manual refresh at repository and individual issue level with staleness indicators

### Technical Highlights

- **Component-Based UI** - ViewComponent architecture with reusable GitHub-style components
- **GitHub-Flavored Markdown** - Full markdown rendering for issue bodies and comments
- **Dual Search Modes** - Local SQLite search and GitHub API search with automatic mode switching
- **Comprehensive Testing** - 98.18% line coverage, 91.84% branch coverage (341 tests, 897 assertions)
- **Dark Mode Support** - Full dark mode throughout the application
- **Accessibility** - WCAG 2.1 AA compliant with automated accessibility testing

## Tech Stack

### Backend
- **Rails 8.1.0** with modern asset pipeline (Propshaft)
- **Ruby 3.4.7**
- **SQLite3** for all environments including production (multi-database setup)
- **Octokit 10.0+** for GitHub REST API integration with rate limiting and retries
- **CommonMarker** for GitHub-flavored markdown rendering
- **BCrypt** for secure password hashing
- **Solid Libraries** for database-backed cache, queue, and cable

### Frontend
- **Hotwire** (Turbo + Stimulus) for interactive features with minimal JavaScript
- **Tailwind CSS** via CDN for GitHub-style UI
- **ViewComponent** for reusable GitHub UI components
- **ImportMap** for JavaScript (no Node.js bundling required)
- **Custom markdown.css** for GitHub-inspired styling with dark mode

### Testing & Quality
- **Minitest** with Mocha for comprehensive testing
- **SimpleCov** for code coverage analysis (98.18% line, 91.84% branch)
- **RuboCop** (Rails Omakase configuration)
- **Brakeman** for security scanning
- **Capybara + Selenium** for system tests
- **Axe-core** for accessibility testing

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
- **ApiClient**: GitHub REST API client with rate limiting, retries, exponential backoff, and search API support
- **ApiConfiguration**: Centralized configuration for rate limits, retries, and pagination
- **RepositorySyncService**: Syncs repository metadata from GitHub
- **IssueSyncService**: Syncs issues with full metadata (labels, assignees, comments); supports single issue or full repo sync
- **IssueSearchService**: Dual-mode search (local SQLite + GitHub API) with GitHub query syntax parser

### Component System

The application uses ViewComponent for UI components:
- **Auth Components**: `Auth::*` for authentication forms and flows
- **Issue Components**: `IssueCardComponent`, `IssueLabelComponent`, `IssueStateComponent`, `IssueCommentComponent`
- **Filter Components**: `FilterDropdown::*` namespace for reusable dropdown filters with search and keyboard navigation
- **Common Components**: `AvatarComponent` (with Gravatar fallback), `AlertComponent`, `UserPageComponent`

### Stimulus Controllers

Client-side JavaScript controllers for enhanced interactivity:
- **TimeController**: Relative time formatting with hover tooltips
- **FilterDropdownController**: Keyboard navigation, search, and intelligent positioning for filter dropdowns
- **AccordionController**: Collapsible sections for UI elements

## Search Syntax

The application supports GitHub's search syntax for powerful filtering:

- **State filters**: `is:open`, `is:closed`, `state:open`, `state:closed`
- **Label filters**: `label:bug`, `label:"needs review"` (use quotes for labels with spaces)
- **Assignee filters**: `assignee:username`
- **Sorting**: `sort:created`, `sort:updated`, `sort:comments` (add `-desc` for descending, e.g., `sort:updated-desc`)

Examples:
```
is:open label:bug memory leak
assignee:alice label:"high priority" sort:updated-desc
state:closed sort:comments-desc
```

The search automatically switches to GitHub API mode when qualifiers are detected, otherwise it uses fast local SQLite search.

## Contributing

1. Follow the existing code style and conventions (Rails Omakase)
2. Ensure tests pass: `bin/ci`
3. Maintain test coverage above 95% line, 90% branch
4. Use conventional commit messages (see CLAUDE.md)
5. Add tests for all new features

For detailed development guidelines, see `CLAUDE.md` and `docs/` directory.

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

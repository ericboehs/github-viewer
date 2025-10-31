# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rails 8.1.0 application called **GitHub Issues Viewer** (`GithubViewer` module) - a fully implemented, production-ready application for viewing and managing GitHub issues with smart caching. The application provides a GitHub.com-quality UI for browsing issues from multiple repositories across GitHub.com and GitHub Enterprise, with per-user GitHub tokens and hybrid on-demand caching.

**Status**: ✅ All core features complete (October 2025) with 98.18% test coverage

Uses modern Rails features including Solid libraries (Cache, Queue, Cable) and is configured for deployment with Kamal.

## Development Commands

### Code Quality & Testing
- `bin/ci` - Run full CI pipeline (formatting, linting, security scan, tests, coverage)
- `bin/ci --fix` - Auto-fix formatting issues before running CI checks  
- `bin/coverage` - Generate detailed test coverage report with line/branch analysis
- `bin/watch-ci` - Monitor CI status in real-time during development

### Standard Rails Commands
- `bin/rails server` - Start development server
- `bin/rails test` - Run test suite
- `bin/rails test:system` - Run system tests
- `bin/setup` - Initial application setup

### Individual Quality Tools
- `rubocop` - Ruby style checking (Rails Omakase style)
- `rubocop -A` - Auto-fix Ruby style violations
- `bundle exec reek` - Code smell detection
- `bin/rails zeitwerk:check` - Verify Rails autoloading
- `bundle exec bundle-audit check` - Check for vulnerable gem versions
- `brakeman` - Security vulnerability scanning
- `npx eclint check` - EditorConfig compliance checking
- `npx eclint fix` - Auto-fix EditorConfig violations

## Architecture & Configuration

### Modern Rails Stack
- **Rails 8.1.0** with modern asset pipeline (Propshaft)
- **Ruby 3.4.7**
- **SQLite3** for all environments including production
- **Octokit 10.0+** for GitHub REST and GraphQL API integration
- **ImportMap** for JavaScript (no Node.js bundling)
- **Hotwire** (Turbo + Stimulus) for interactivity
- **Tailwind CSS** via CDN for GitHub-style UI
- **ViewComponent** for reusable UI components
- **Solid Libraries**: Database-backed cache, queue, and cable

### Multi-Database Setup
The application uses separate SQLite databases:
- **Primary database**: Users, repositories, issues, comments (with per-user caching)
- **Cache database**: Solid Cache for application-level caching
- **Queue database**: Solid Queue for background jobs
- **Cable database**: Solid Cable for WebSocket connections

### GitHub Integration Architecture

#### Service Layer (`app/services/github/`)
- **ApiConfiguration**: Centralized constants for rate limiting, retries, pagination
- **ApiClient**: GitHub REST API client with rate limiting, retries, exponential backoff, search API support
- **RepositorySyncService**: Syncs repository metadata from GitHub API
- **IssueSyncService**: Syncs issues with labels, assignees, comments (supports single issue or full repository sync)
- **IssueSearchService**: Handles both local SQLite and GitHub API search with GitHub query syntax parser

#### Caching Strategy
- **Hybrid on-demand caching**: Serve cached data if available, fetch from API if cache is cold
- **Per-user cache keying**: Each user maintains separate caches (user_id + repository_id)
- **Manual refresh**: Users can refresh with staleness indicators
- **Graceful degradation**: Show stale cached data with warnings when API fails (rate limit, invalid token)
- **No background jobs initially**: All syncing happens on-demand in requests

#### Models
- **User**: Authentication + encrypted GitHub token + domain (github.com or GHE)
- **Repository**: Per-user tracked repos (owner, name, metadata, cached_at)
- **Issue**: Cached issues with full metadata (number, title, state, body, labels, assignees, cached_at)
- **IssueComment**: Issue comments with author info and markdown body

#### ViewComponents for GitHub UI (`app/components/`)
- **Issue components**: IssueCardComponent, IssueLabelComponent, IssueStateComponent, IssueCommentComponent
- **Filter components**: FilterDropdown namespace (BaseComponent, ButtonComponent, MenuComponent, SearchComponent, ItemComponent)
- **Auth components**: Auth namespace (FormContainerComponent, InputComponent, ButtonComponent, LinkComponent)
- **Common components**: AvatarComponent (with Gravatar fallback), AlertComponent, UserPageComponent

#### Stimulus Controllers (`app/javascript/controllers/`)
- **TimeController**: Client-side relative time formatting with hover tooltips
- **FilterDropdownController**: Keyboard navigation, search, and intelligent positioning for filter dropdowns
- **AccordionController**: Collapsible sections for UI elements

#### Helpers (`app/helpers/`)
- **MarkdownHelper**: GitHub-flavored markdown rendering with CommonMarker
- **RepositoriesHelper**: URL parsing for repository imports (supports multiple formats)
- **ApplicationHelper**: time_ago_tag for semantic time elements

### Code Quality Standards
- **EditorConfig**: UTF-8, LF line endings, 2-space indentation
- **RuboCop**: Rails Omakase configuration (DHH's opinionated style)
- **Reek**: Code smell detection for maintainability
- **Zeitwerk**: Autoloading verification for Rails constants
- **bundler-audit**: Vulnerability scanning for gem dependencies
- **Brakeman**: Security scanning for Rails-specific vulnerabilities
- **SimpleCov**: Test coverage with detailed HTML reports

### Testing Setup
- **Minitest** (Rails default) for unit and integration tests
- **Mocha** for mocking and stubbing (used in service tests)
- **Capybara + Selenium** for system tests
- **Axe-core** for automated accessibility testing (WCAG 2.1 AA)
- **SimpleCov** for coverage analysis with branch coverage tracking
- **Current Coverage**: 98.18% line coverage, 91.84% branch coverage (341 tests, 897 assertions)
- Pre-commit hooks run full CI pipeline to ensure quality

See `docs/accessibility.md` for detailed accessibility testing guide.

## Key Files & Directories

### Application Structure
- `app/models/` - User, Repository, Issue, IssueComment models
- `app/controllers/` - Authentication, repositories, issues controllers
- `app/components/` - ViewComponents for GitHub UI (issues, labels, comments, etc.)
- `app/services/github/` - GitHub API integration services
- `app/views/` - Slim templates for layouts and pages
- `config/application.rb` - Main application configuration
- `config/database.yml` - Multi-database SQLite configuration
- `config/deploy.yml` - Kamal deployment configuration

### Development Tools
- `bin/ci` - Comprehensive CI script with formatting, linting, security, and testing
- `bin/coverage` - Advanced coverage reporting with HTML parsing
- `bin/watch-ci` - Real-time CI monitoring using GitHub CLI
- `.editorconfig` - Code formatting standards

### Quality Assurance
- `rubocop` configured with Rails Omakase
- `brakeman` for security scanning
- `eclint` for EditorConfig enforcement
- Pre-commit hooks ensure code quality

### Commit Messages

This project follows [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only changes
- `style:` Code style changes (formatting, missing semi-colons, etc)
- `refactor:` Code change that neither fixes a bug nor adds a feature
- `perf:` Performance improvements
- `test:` Adding missing tests or correcting existing tests
- `build:` Changes that affect the build system or external dependencies
- `ci:` Changes to CI configuration files and scripts
- `chore:` Other changes that don't modify src or test files

**Examples:**
```bash
git commit -m "feat: add issue comment viewing with markdown rendering"
git commit -m "fix: handle API rate limiting in issue sync service"
git commit -m "docs: update GitHub token setup instructions in README"
git commit -m "refactor: extract repository URL parsing to helper"
```

### Code Coverage

The project enforces comprehensive test coverage using SimpleCov:
- **Target coverage**: 95% line, 90% branch
- **Current coverage**: 98.18% line, 91.84% branch ✅
- **Per-file minimum**: 80%
- **Test count**: 341 tests, 897 assertions
- **Coverage reports**: Generated in `coverage/` directory
- **CI integration**: Coverage reports generated automatically with tests

Coverage configuration in `test/test_helper.rb`:
- Excludes test files, config, vendor, and database files
- Groups results by component type (Controllers, Models, Services, etc.)
- Fails CI if coverage drops below thresholds
- Parallel test support with SimpleCov worker consolidation

## Development Workflow

1. **Setup**: Run `bin/setup` for initial configuration
2. **Development**: Use `bin/watch-ci` for real-time feedback during coding
3. **Quality Check**: Run `bin/ci --fix` to auto-fix issues and verify code quality
4. **Testing**: Use `bin/rails test` and `bin/rails test:system` for targeted testing
5. **Coverage**: Check `bin/coverage` for detailed test coverage analysis

The application emphasizes code quality with automated formatting, comprehensive testing, security scanning, and 95% code coverage requirement integrated into the development workflow.

## Current Feature Set (October 2025)

### ✅ Implemented Features

All core features from the PRD are fully implemented and tested:

1. **User Authentication & GitHub Token Management**
    - Email/password authentication with BCrypt
    - Encrypted GitHub token storage (Rails encrypted attributes)
    - Multi-domain support (github.com + GitHub Enterprise)
    - Token management UI

2. **Multi-Repository Tracking**
    - Flexible URL parsing (owner/repo, full URLs, domain/owner/repo)
    - Repository metadata syncing from GitHub
    - Staleness indicators and manual refresh
    - Per-user repository isolation

3. **Issue Viewing with Full Metadata**
    - GitHub.com-style issue list and detail views
    - Markdown rendering (CommonMarker with GitHub-flavored markdown)
    - Labels with dynamic colors and WCAG-compliant contrast
    - Full comment threads with avatars
    - Relative time display with hover tooltips

4. **Smart Hybrid Caching**
    - On-demand fetching (cold cache → API, warm cache → instant)
    - Per-user cache keying with staleness tracking
    - Graceful degradation with error handling
    - Manual refresh at repository and individual issue level

5. **Advanced Search & Filtering**
    - Dual search modes (local SQLite + GitHub API)
    - GitHub query syntax parser (is:, state:, label:, assignee:, sort:)
    - Automatic mode switching based on query qualifiers
    - Filter dropdowns with keyboard navigation
    - Active filters display with removal chips

### 🔮 Potential Future Enhancements

See PRD.md for complete list of Phase 2 features including:
- Pull request viewing
- Real-time WebSocket updates
- Background sync jobs
- Issue creation/editing (write operations)
- GitHub OAuth integration
- Multi-repo aggregate views
- Analytics dashboard

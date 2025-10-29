# Product Requirements Document (PRD)
# GitHub Issues Viewer

**Version**: 1.0
**Date**: October 2025
**Status**: In Development

## Executive Summary

GitHub Issues Viewer is a modern Rails 8.1.0 application that provides a GitHub.com-quality interface for viewing and managing issues from multiple GitHub repositories. The application supports both GitHub.com and GitHub Enterprise, with smart hybrid caching, per-user GitHub token authentication, and dual search modes (local and API-based). Users can track multiple repositories, view issues with full metadata (labels, assignees, comments), and enjoy fast performance through intelligent on-demand caching with graceful degradation.

## Goals & Objectives

### Primary Goals
1. **GitHub.com Clone Experience** - Provide a familiar, high-quality UI matching GitHub's issue browsing experience
2. **Multi-Repository Support** - Allow users to track and view issues from multiple GitHub repositories
3. **Smart Performance** - Balance freshness and speed through hybrid caching with on-demand fetching
4. **Enterprise Support** - Work with both GitHub.com and self-hosted GitHub Enterprise servers
5. **Graceful Degradation** - Continue functioning with stale data when API limits or errors occur

### User Stories

#### Repository Management
- As a user, I can add repositories by pasting GitHub URLs
- As a user, I can view all my tracked repositories with metadata
- As a user, I can remove repositories I no longer want to track
- As a user, I can see when repository data was last synced

#### Issue Viewing
- As a user, I can browse issues in a GitHub.com-style list with labels, assignees, and metadata
- As a user, I can click an issue to view full details including description and comments
- As a user, I can see issue comments with proper markdown rendering
- As a user, I can manually refresh issue data to get the latest from GitHub
- As a user, I can see how stale my cached data is

#### Search & Filter
- As a user, I can toggle between fast local search and comprehensive GitHub API search
- As a user, I can filter issues by state (open/closed)
- As a user, I can filter issues by labels
- As a user, I can filter issues by assignees
- As a user, I can sort issues by various criteria

#### Account & Settings
- As a user, I can securely store my GitHub personal access token
- As a user, I can configure my GitHub domain (github.com or custom GHE)
- As a user, I can see error messages when my token is invalid or rate limited
- As a user, I can continue viewing stale cached data when API errors occur

## Core Features

### 1. User Authentication & GitHub Token Management

#### User Authentication
- Email-based registration and login
- Session-based authentication with secure password hashing (BCrypt)
- Password reset functionality
- User profile management

#### GitHub Token Configuration
- **Encrypted token storage** - GitHub personal access tokens stored with Rails encrypted attributes
- **Domain configuration** - Support for github.com and custom GitHub Enterprise domains
- **Token validation** - Test GitHub API connection when saving token
- **Per-user tokens** - Each user uses their own GitHub credentials for API access

### 2. Multi-Repository Tracking

#### Repository Import
- **URL-based import** - Parse GitHub URLs in various formats (e.g., https://github.com/owner/repo)
- **Owner/repo extraction** - Intelligent parsing of repository identifiers
- **Validation** - Verify repository exists and user has access via their GitHub token

#### Repository Management
- **Repository list** - View all tracked repositories with metadata
- **Repository metadata** - Name, description, URL, issue counts, last sync time
- **Remove repositories** - Delete repositories from tracking
- **Per-user isolation** - Each user maintains their own repository list

### 3. Issue Viewing with Full Metadata

#### Issue List View (GitHub.com Clone)
- **Comprehensive issue cards** - Issue number, title, state (open/closed)
- **Visual metadata** - Labels with colors, assigned user avatars, comment counts
- **Timestamps** - Created/updated times in relative format
- **State badges** - Clear visual indicators for open/closed issues
- **Author information** - Issue creator with avatar
- **Responsive layout** - Works on mobile and desktop

#### Issue Detail View
- **Full issue body** - Markdown-rendered description
- **Complete metadata** - All labels, assignees, state, timestamps
- **Comment thread** - Full comment history with authors, avatars, timestamps
- **Markdown rendering** - Proper formatting for issue bodies and comments
- **GitHub-style formatting** - Code blocks, links, images, etc.

### 4. Smart Hybrid Caching

#### Caching Strategy
- **On-demand fetching** - Fetch from GitHub API only when cache is cold (no data)
- **Per-user cache keying** - Each user maintains separate caches (user_id + repository_id)
- **No background jobs** - All syncing happens in-request, no automated background polling
- **SQLite storage** - Cache stored in primary database with timestamps

#### Staleness Management
- **Timestamp tracking** - Record `cached_at` for all synced data
- **Staleness indicators** - Show users how old their cached data is
- **Manual refresh** - "Refresh" button to force sync from GitHub API
- **Visual feedback** - Clear indicators when viewing stale data

#### Graceful Degradation
- **Error handling** - Catch API errors (rate limits, invalid tokens, network issues)
- **Stale data fallback** - Display cached data with prominent warnings when API fails
- **Error banners** - Explain why data might be stale (e.g., "Rate limit reached, showing cached data from 2 hours ago")
- **Retry options** - Allow users to retry once rate limits reset

### 5. Dual Search Modes

#### Local SQLite Search
- **Fast performance** - No API calls, instant results
- **Full-text search** - Search issue titles and bodies
- **Limited scope** - Only searches cached data
- **Filter support** - Combine with state, label, assignee filters

#### GitHub API Search
- **Comprehensive results** - Use GitHub's powerful search API
- **Always fresh** - Real-time results from GitHub
- **Advanced queries** - Leverage GitHub's search syntax
- **Rate limit aware** - Count against user's API limits

#### Search UI
- **Toggle control** - Easy switch between local and API search modes
- **Search preference persistence** - Remember user's preferred search mode
- **Filter combination** - Apply filters (state, labels, assignees) to both modes
- **Sort options** - Sort by created, updated, comments, etc.

## Technical Implementation

### Technology Stack

#### Backend
- **Rails 8.1.0** with modern asset pipeline (Propshaft)
- **Ruby 3.4.7**
- **SQLite3** for all environments including production
- **Octokit 10.0+** for GitHub REST and GraphQL API integration
- **Faraday-Retry** for HTTP retry middleware
- **BCrypt** for secure password hashing

#### Frontend
- **Hotwire** (Turbo + Stimulus) for interactive features with minimal JavaScript
- **Tailwind CSS** via CDN for GitHub-style UI
- **ViewComponent** for reusable UI components
- **ImportMap** for JavaScript (no Node.js bundling)
- **Markdown rendering** for issue bodies and comments

#### Infrastructure
- **Solid Cache** - Database-backed caching
- **Solid Queue** - Database-backed job queue (for future use)
- **Solid Cable** - Database-backed WebSockets
- **Kamal** - Deployment configuration

### Database Schema

#### Users Table
- `id` (primary key)
- `email_address` (string, unique)
- `password_digest` (string)
- `github_token` (encrypted text) - Encrypted GitHub personal access token
- `github_domain` (string, default: "github.com") - GitHub.com or GHE domain
- `admin` (boolean)
- `created_at`, `updated_at` (timestamps)

#### Repositories Table
- `id` (primary key)
- `user_id` (foreign key) - Owner of this repository cache
- `owner` (string) - GitHub repository owner
- `name` (string) - GitHub repository name
- `full_name` (string) - "owner/repo"
- `description` (text)
- `url` (string) - GitHub URL
- `cached_at` (datetime) - Last sync time
- `issue_count` (integer)
- `open_issue_count` (integer)
- `created_at`, `updated_at` (timestamps)
- **Index**: `[user_id, owner, name]` (unique per user)

#### Issues Table
- `id` (primary key)
- `repository_id` (foreign key)
- `number` (integer) - GitHub issue number
- `title` (string)
- `state` (string) - "open" or "closed"
- `body` (text) - Markdown description
- `author_login` (string)
- `author_avatar_url` (string)
- `labels` (json) - Array of label objects `[{name, color}]`
- `assignees` (json) - Array of assignee objects `[{login, avatar_url}]`
- `comments_count` (integer)
- `github_created_at` (datetime)
- `github_updated_at` (datetime)
- `cached_at` (datetime) - Last sync time
- `created_at`, `updated_at` (timestamps)
- **Index**: `[repository_id, number]` (unique per repo)
- **Index**: `[repository_id, state]` (for filtering)

#### IssueComments Table
- `id` (primary key)
- `issue_id` (foreign key)
- `github_id` (bigint) - GitHub comment ID
- `author_login` (string)
- `author_avatar_url` (string)
- `body` (text) - Markdown comment text
- `github_created_at` (datetime)
- `github_updated_at` (datetime)
- `created_at`, `updated_at` (timestamps)
- **Index**: `[issue_id, github_id]` (unique per issue)

### Service Layer Architecture

Located in `app/services/github/`:

#### ApiConfiguration
Centralized configuration constants:
- Rate limit thresholds (critical: 50, warning: 200)
- Retry settings (max 3 retries, exponential backoff: 1s, 2s, 4s)
- Default delays between calls (0.1s)
- Pagination sizes (100 items per page)

#### ApiClient
GitHub REST API client:
- Per-user Octokit client initialization (token + domain)
- Rate limit tracking and enforcement
- Automatic retries with exponential backoff
- Graceful error handling (return errors, don't raise)
- Request logging and monitoring

#### GraphqlClient
GitHub GraphQL client:
- Per-user GraphQL endpoint configuration
- Batch query support (up to 5 queries per request)
- Issue and repository queries
- Pagination handling for large result sets
- Rate limit awareness from GraphQL responses

#### RepositorySyncService
Repository metadata sync:
- Fetch repository details from GitHub API
- Upsert repository record with metadata
- Update issue counts and cached_at timestamp
- Handle API errors gracefully
- Return sync status (success/error)

#### IssueSyncService
Issue sync with full metadata:
- Fetch issues from GitHub API (with pagination)
- Include labels, assignees, comment counts
- Fetch and store all comments for each issue
- Batch upsert for performance
- Update cached_at timestamps
- Handle API errors, preserve existing cache on failure

#### IssueSearchService
Dual search implementation:
- **Local mode**: SQLite full-text search on cached issues
- **API mode**: GitHub search API with advanced syntax
- Apply filters (state, labels, assignees)
- Sort results by multiple criteria
- Return unified result format

### Security

#### Authentication & Authorization
- **BCrypt** password hashing with secure defaults
- **Session-based authentication** with secure random tokens
- **CSRF protection** on all forms
- **Authorization checks** - Users can only access their own repositories and settings

#### GitHub Token Security
- **Encrypted storage** - Rails encrypted attributes for GitHub tokens
- **No logging** - Tokens never appear in logs
- **No display** - Tokens never rendered in views (masked input)
- **Per-user isolation** - Tokens never shared between users

#### API Security
- **Rate limit compliance** - Respect GitHub API rate limits
- **Error handling** - Never expose sensitive error details to users
- **Input validation** - Validate all user inputs (URLs, search queries)
- **CSRF tokens** - Protect all state-changing operations

#### Security Scanning
- **Brakeman** - Rails security vulnerability scanning
- **bundler-audit** - Gem vulnerability checking
- **RuboCop** - Code quality and security linting

### Testing & Quality Assurance

#### Test Coverage
- **95%+ overall coverage** with SimpleCov
- **80%+ per-file minimum**
- **Branch coverage** enabled and tracked

#### Test Types
- **Model tests** - Associations, validations, scopes
- **Service tests** - GitHub API integration (mocked), sync logic, error handling
- **Controller tests** - Authentication, authorization, params, responses
- **Component tests** - ViewComponent rendering and logic
- **System tests** - End-to-end user flows with Capybara

#### CI/CD Pipeline
- **Code formatting** - RuboCop with Rails Omakase config
- **Code smells** - Reek for maintainability
- **Security scan** - Brakeman for vulnerabilities
- **Test suite** - Full test run with coverage
- **EditorConfig** - Consistent code formatting
- **Pre-commit hooks** - Run full CI before every commit

### Performance Considerations

#### Caching Strategy
- **On-demand loading** - Fetch only when cache is empty
- **Timestamp-based staleness** - Track age of all cached data
- **Batch operations** - Bulk upsert for issues and comments
- **Index optimization** - Indexes on foreign keys and query fields

#### API Efficiency
- **GraphQL batching** - Multiple queries in single request
- **Pagination** - Fetch 100 items per page
- **Rate limit awareness** - Pause before hitting limits
- **Exponential backoff** - Retry failed requests intelligently

#### UI Performance
- **Turbo Frames** - Partial page updates
- **Minimal JavaScript** - Keep client-side logic light
- **CDN assets** - Tailwind via CDN
- **Responsive images** - Optimize avatar and image loading

## Dependencies

### Application Dependencies
- **Ruby 3.4.7** - Application runtime
- **Rails 8.1.0** - Web framework with Solid libraries
- **SQLite3** - Database for all environments
- **Octokit ~> 10.0** - GitHub API client (Ruby)
- **Faraday-Retry** - HTTP retry middleware for resilience
- **BCrypt** - Secure password hashing
- **ViewComponent** - UI component framework

### Development & Testing Dependencies
- **SimpleCov** - Test coverage analysis (95% minimum)
- **RuboCop** - Code style enforcement (Rails Omakase)
- **Reek** - Code smell detection
- **Brakeman** - Security vulnerability scanning
- **bundler-audit** - Gem vulnerability checking
- **Capybara** - System testing framework
- **Selenium WebDriver** - Browser automation for tests

### Deployment
- **Kamal** - Dockerized deployment to any server
- **Docker** - Containerization for consistent deployments
- **SQLite3** - Production database (no external database server required)
- **Solid Cache, Queue, Cable** - Database-backed infrastructure

## Future Enhancements

### Phase 2 Potential Features
- **Pull Request viewing** - Extend to view PRs alongside issues
- **Real-time updates** - WebSocket updates for issue changes
- **Background sync** - Optional automatic background refresh jobs
- **Advanced filters** - Saved filter presets, complex queries
- **Issue creation/editing** - Write operations (create, comment, close)
- **Multiple user collaboration** - Shared repository lists with permissions
- **GitHub OAuth** - Alternative to personal access tokens
- **Notifications** - Track issue updates and mentions
- **Export functionality** - Export issue lists to CSV/JSON
- **Analytics dashboard** - Issue trends, velocity, time-to-close metrics

### Performance Optimizations
- **Partial issue sync** - Only fetch changed issues (delta sync)
- **Virtual scrolling** - For very long issue lists
- **Image caching** - Cache avatars locally
- **Service worker** - Offline support for cached issues

### Advanced Features
- **Multi-repo views** - Aggregate issues across multiple repos
- **Custom labels** - User-defined label taxonomy
- **Issue linking** - Track relationships between issues
- **Markdown editor** - WYSIWYG editor for creating issues
- **Keyboard shortcuts** - Power user navigation

## Success Metrics

### User Engagement
- **Daily active users** - Track user logins and activity
- **Repositories tracked** - Average repos per user
- **Issues viewed** - Page views and unique issue views
- **Search usage** - Local vs API search mode preference

### Performance
- **Page load times** - Target < 200ms for cached data
- **API response times** - Track GitHub API latency
- **Cache hit rate** - Percentage of requests served from cache
- **Error rate** - Track API failures and graceful degradations

### Quality
- **Test coverage** - Maintain 95%+ coverage
- **Security scans** - Zero high-severity vulnerabilities
- **Uptime** - Target 99.9% availability
- **User-reported bugs** - Track and resolve issues quickly

## Conclusion

GitHub Issues Viewer provides a modern, performant, and user-friendly interface for managing GitHub issues across multiple repositories. By combining GitHub.com-quality UI with smart caching and graceful degradation, the application delivers both speed and freshness. Per-user GitHub tokens ensure secure, isolated access while supporting both GitHub.com and GitHub Enterprise deployments.

The hybrid caching strategy balances performance with data freshness, allowing users to browse cached issues instantly while fetching fresh data on-demand. Dual search modes give users flexibility to choose between fast local search and comprehensive GitHub API search based on their needs.

With comprehensive testing, security measures, and modern Rails architecture, the application provides a solid foundation for viewing and managing GitHub issues at scale.

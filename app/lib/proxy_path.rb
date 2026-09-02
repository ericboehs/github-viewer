# frozen_string_literal: true

# Parses the GitHub-shaped URLs the proxy route accepts, so pasting a GitHub
# link against this host lands on the equivalent page here.
#
#   va.ghe.com/software/eert/issues/185
#   rails/rails/pull/123                     (domain defaults to github.com)
#   va.ghe.com/software/eert/blob/main/README.md
#   rails/rails/tree/main/app/models
#
# Returns nil for anything it does not recognise.
class ProxyPath
  ISSUE_KINDS = %w[issues pull].freeze

  # blob and tree differ on GitHub only in whether the target is a file or a
  # directory. Ours serves both from one action, so they parse identically.
  FILE_KINDS = %w[blob tree].freeze

  def self.parse(path)
    segments = path.to_s.split("/").reject(&:blank?)

    parse_file(segments) || parse_issue(segments)
  end

  # A ref may itself contain slashes (`release/2025-01`), which is genuinely
  # ambiguous with the file path that follows it and cannot be resolved without
  # asking GitHub which refs exist. The first segment wins, so a branch with a
  # slash in its name needs the ref given by hand.
  # :reek:TooManyStatements - Locates the marker, then splits repository from ref and path
  def self.parse_file(segments)
    index = file_kind_index(segments)
    return unless index

    repository = repository_from(segments[0...index])
    ref = segments[index + 1]
    return unless repository && ref.present?

    repository.merge(kind: :tree, ref: ref, path: segments[(index + 2)..].to_a.join("/"))
  end

  # The marker sits immediately after the repository, so it is at index 2 for
  # owner/repo and 3 for domain/owner/repo. Checking the domain form first
  # keeps a repository actually named "blob" from being mistaken for a marker.
  def self.file_kind_index(segments)
    return 3 if segments[0].to_s.include?(".") && FILE_KINDS.include?(segments[3])

    2 if FILE_KINDS.include?(segments[2])
  end

  # :reek:TooManyStatements - Validates the kind and number, then splits the repository
  def self.parse_issue(segments)
    return unless segments.length >= 4

    kind = segments[-2]
    return unless ISSUE_KINDS.include?(kind)

    number = segments[-1].to_i
    return if number <= 0

    repository = repository_from(segments[0..-3])
    return unless repository

    repository.merge(kind: :issue, issue_number: number, scope: scope_for(kind))
  end

  # GitHub spells the pull request path "pull"; everything else we accept is an
  # issue.
  SCOPES = { "pull" => IssueScoped::PULLS_SCOPE }.freeze

  def self.scope_for(kind)
    SCOPES.fetch(kind, IssueScoped::ISSUES_SCOPE)
  end

  # Two segments mean github.com is implied; three name the host explicitly,
  # which is only plausible if the first one looks like a hostname.
  def self.repository_from(segments)
    first, second, third = segments

    case segments.length
    when 2
      { domain: "github.com", owner: first, name: second }
    when 3
      { domain: first, owner: second, name: third } if first.include?(".")
    end
  end

  private_class_method :parse_file, :file_kind_index, :parse_issue, :scope_for, :repository_from
end

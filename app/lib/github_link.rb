# frozen_string_literal: true

# Turns something a person pasted into the path for the same thing here.
#
#   https://github.com/rails/rails/pull/1     -> /rails/rails/pull/1
#   https://va.ghe.com/software/eert/issues/2 -> /va.ghe.com/software/eert/issues/2
#   github.com/rails/rails                    -> /rails/rails
#   rails/rails#123                           -> /rails/rails/issues/123
#
# Our URLs are GitHub's, so most of the work is stripping the parts of a
# pasted URL that a path does not have: the scheme, a github.com host (which
# is implied), a query string, a fragment, a `.git` suffix.
#
# What is left may still name a page GitHub has and we do not - Actions,
# Wiki, Settings. Rather than send the user to a 404, anything the router does
# not recognise falls back to the repository root, which is the closest page
# we can actually show.
module GithubLink
  DEFAULT_DOMAIN = RepositoryUrls::DEFAULT_DOMAIN

  # `owner/repo#123`, the shorthand GitHub itself renders as a link to an issue.
  ISSUE_SHORTHAND = %r{\A(?<repo>[^/#\s]+/[^/#\s]+)\#(?<number>\d+)\z}

  module_function

  # Returns a path, or nil if there is nothing repository-shaped in the input.
  def path_for(input)
    segments = segments_for(input)
    return if segments.length < 2

    recognized_path(segments) || root_path_for(segments)
  end

  # The path as pasted, if it names a page this application serves.
  #
  # :reek:UtilityFunction - Parsing helper, at home alongside the rest of the module
  def recognized_path(segments)
    path = "/#{segments.join('/')}"
    Rails.application.routes.recognize_path(path)
    path
  rescue ActionController::RoutingError
    nil
  end

  # The repository itself: the fallback for a page we cannot show, and the
  # answer for a bare `owner/repo`.
  #
  # :reek:UtilityFunction - Parsing helper, at home alongside the rest of the module
  def root_path_for(segments)
    "/#{segments.first(host?(segments.first) ? 3 : 2).join('/')}"
  end

  # Splits the input into the path segments of the equivalent local URL.
  #
  # :reek:TooManyStatements - Sanitising pasted input is a sequence of small removals
  def segments_for(input)
    text = input.to_s.strip
    return [] if text.empty?

    shorthand = ISSUE_SHORTHAND.match(text)
    text = "#{shorthand[:repo]}/issues/#{shorthand[:number]}" if shorthand

    text = text.split(/[?#]/).first.to_s      # drop query strings and fragments
    text = text.sub(%r{\Ahttps?://}i, "")     # and the scheme, leaving host/owner/repo
    text = text.sub(/\.git\z/, "")            # a clone URL names the same repository

    strip_implied_host(text.split("/").reject(&:blank?))
  end

  # github.com is the implied host here, so a pasted github.com URL keeps only
  # what follows it. Any other host is what tells the router where to look.
  #
  # :reek:UtilityFunction - Parsing helper, at home alongside the rest of the module
  def strip_implied_host(segments)
    first = segments.first.to_s
    implied = first.casecmp?(DEFAULT_DOMAIN) || first.casecmp?("www.#{DEFAULT_DOMAIN}")

    implied ? segments.drop(1) : segments
  end

  # A host is recognised by having a dot in it, exactly as the router does it.
  #
  # :reek:UtilityFunction - Parsing helper, at home alongside the rest of the module
  def host?(segment)
    segment.to_s.match?(RepositoryUrls::CONSTRAINTS[:github_domain])
  end

  private_class_method :recognized_path, :root_path_for, :segments_for, :strip_implied_host, :host?
end

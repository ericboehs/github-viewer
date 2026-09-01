# frozen_string_literal: true

# Renders a single inline pull request review comment: the file and line it is
# anchored to, the tail of the diff hunk for context, and the comment body.
#
# :reek:InstanceVariableAssumption - ViewComponent sets ivars in the initializer
class ReviewCommentComponent < ViewComponent::Base
  # GitHub sends the whole hunk leading up to the commented line. Only the last
  # few lines are useful context; the rest just pushes the comment off screen.
  CONTEXT_LINES = 4

  ADDITION_CLASSES = "bg-green-50 dark:bg-green-950 text-green-900 dark:text-green-200"
  DELETION_CLASSES = "bg-red-50 dark:bg-red-950 text-red-900 dark:text-red-200"
  CONTEXT_CLASSES = "text-gray-600 dark:text-gray-400"

  def initialize(comment:)
    @comment = comment
    super()
  end

  def path
    @comment[:path]
  end

  def line
    @comment[:line]
  end

  def body
    @comment[:body]
  end

  def actor
    @comment[:actor]
  end

  def avatar_url
    @comment[:avatar_url]
  end

  def created_at
    @comment[:created_at]
  end

  def outdated?
    @comment[:outdated].present?
  end

  # The trailing context lines of the diff hunk, newest last, with the leading
  # @@ header dropped.
  # :reek:FeatureEnvy - Splitting the hunk string is the point of the method
  def hunk_lines
    hunk = @comment[:diff_hunk]
    return [] if hunk.blank?

    hunk.split("\n").reject { |line| line.start_with?("@@") }.last(CONTEXT_LINES)
  end

  # :reek:UtilityFunction - Maps a diff line to its colour classes
  def line_classes(line)
    case line[0]
    when "+" then ADDITION_CLASSES
    when "-" then DELETION_CLASSES
    else CONTEXT_CLASSES
    end
  end
end

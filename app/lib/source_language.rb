# Maps a file path to the Prism language used to highlight it.
#
# Shared by the file source view and the diff view so a path highlights the
# same way wherever it appears. Only the languages the layout actually loads
# are listed; anything else renders as plain text, because guessing wrong
# looks worse than not colouring at all.
module SourceLanguage
  EXTENSIONS = {
    "rb" => "ruby", "rake" => "ruby", "gemspec" => "ruby", "ru" => "ruby",
    "erb" => "erb",
    "js" => "javascript", "mjs" => "javascript", "cjs" => "javascript", "jsx" => "jsx",
    "ts" => "typescript", "tsx" => "tsx",
    "py" => "python",
    "sh" => "bash", "bash" => "bash", "zsh" => "bash",
    "yml" => "yaml", "yaml" => "yaml",
    "json" => "json",
    "sql" => "sql",
    "css" => "css", "scss" => "css",
    "html" => "markup", "xml" => "markup", "svg" => "markup",
    "go" => "go",
    "tf" => "hcl", "hcl" => "hcl",
    "md" => "markdown", "markdown" => "markdown"
  }.freeze

  # Filenames with no useful extension that still have an obvious language.
  FILENAMES = {
    "gemfile" => "ruby", "rakefile" => "ruby", "guardfile" => "ruby",
    "dockerfile" => "docker", "makefile" => "makefile"
  }.freeze

  def self.for(path)
    name = path.to_s
    extension = File.extname(name).delete_prefix(".").downcase

    EXTENSIONS[extension] || FILENAMES[File.basename(name).downcase]
  end
end

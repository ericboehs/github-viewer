# frozen_string_literal: true

# Component for displaying a GitHub issue label with color
# :reek:TooManyInstanceVariables - Requires label data, repository, and query for link generation
class IssueLabelComponent < ViewComponent::Base
  # :reek:FeatureEnvy - Extracting values from label hash is initialization responsibility
  def initialize(label:, repository: nil, query: nil)
    @label = label
    @name = label["name"] || label[:name]
    @color = label["color"] || label[:color]
    @repository = repository
    @query = query
  end

  def call
    if @repository
      link_to label_url, class: label_classes, style: label_styles do
        @name
      end
    else
      tag.span(class: label_classes, style: label_styles) do
        @name
      end
    end
  end

  private

  # :reek:TooManyStatements - Building label filter URL requires multiple transformations
  def label_url
    query_text = @query || ""
    # Remove any existing label: qualifier
    query_without_label = query_text.gsub(/\blabel:("[^"]*"|\S+)/i, "").gsub(/\s+/, " ").strip
    # Add this label to the query
    label_name = @name.include?(" ") ? "\"#{@name}\"" : @name
    new_query = query_without_label.present? ? "#{query_without_label} label:#{label_name}" : "label:#{label_name}"

    helpers.repository_issues_path(@repository, q: new_query)
  end

  def label_classes
    "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium hover:opacity-80 transition-opacity"
  end

  def label_styles
    return "" unless @color

    bg_color = "##{@color}"
    text_color = text_color_for_background(@color)

    "background-color: #{bg_color}; color: #{text_color};"
  end

  # Calculate contrasting text color based on background color
  # Uses relative luminance formula from WCAG
  # :reek:TooManyStatements - Color calculation algorithm requires multiple steps
  # :reek:UtilityFunction - Pure calculation method, appropriate as private helper
  # :reek:UncommunicativeVariableName { accept: ['r', 'g', 'b'] } - Standard RGB abbreviations
  def text_color_for_background(hex_color)
    return "#000000" unless hex_color

    # Convert hex to RGB
    r = hex_color[0..1].to_i(16)
    g = hex_color[2..3].to_i(16)
    b = hex_color[4..5].to_i(16)

    # Calculate relative luminance
    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255

    # Return black for light backgrounds, white for dark backgrounds
    luminance > 0.5 ? "#000000" : "#FFFFFF"
  end
end

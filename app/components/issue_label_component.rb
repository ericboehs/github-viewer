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
    # Use default query if none provided (matches controller default)
    query_text = @query.presence || "is:issue state:open"
    # Remove any existing label: qualifier
    query_without_label = query_text.gsub(/\blabel:("[^"]*"|\S+)/i, "").gsub(/\s+/, " ").strip
    # Add this label to the query with trailing space
    label_name = @name.include?(" ") ? "\"#{@name}\"" : @name
    new_query = query_without_label.present? ? "#{query_without_label} label:#{label_name} " : "label:#{label_name} "

    helpers.repository_issues_path(@repository, q: new_query)
  end

  def label_classes
    "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium hover:opacity-80 transition-opacity border"
  end

  # Generates inline styles for label colors using GitHub's algorithm
  # :reek:TooManyStatements - Color calculation requires multiple steps for WCAG compliance
  # :reek:UncommunicativeVariableName { accept: ['r', 'g', 'b', 'h', 's', 'l'] } - Standard color abbreviations
  # :reek:DuplicateMethodCall - HSL calculations repeated for text and border, intentional for clarity
  def label_styles
    return "" unless @color

    # Convert hex to RGB
    r = @color[0..1].to_i(16)
    g = @color[2..3].to_i(16)
    b = @color[4..5].to_i(16)

    # Convert to HSL for text/border color
    h, s, l = rgb_to_hsl(r / 255.0, g / 255.0, b / 255.0)

    # Calculate perceived lightness using WCAG formula (same as GitHub)
    perceived_lightness = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 255.0
    lightness_threshold = 0.6

    # Lightness switch: 1 if we need to lighten, 0 otherwise
    lightness_switch = perceived_lightness < lightness_threshold ? 1 : 0

    # Calculate how much to lighten
    lighten_by = ((lightness_threshold - perceived_lightness) * 100 * lightness_switch).round(1)

    # Adjust HSL lightness
    adjusted_l = l * 100 + lighten_by

    # Background: original RGB at 18% opacity
    bg_color = "rgba(#{r}, #{g}, #{b}, 0.18)"

    # Text: HSL with adjusted lightness
    text_color = "hsl(#{(h * 360).round}, #{(s * 100).round}%, #{adjusted_l.round(1)}%)"

    # Border: same HSL at 30% opacity
    border_color = "hsla(#{(h * 360).round}, #{(s * 100).round}%, #{adjusted_l.round(1)}%, 0.3)"

    "background-color: #{bg_color}; color: #{text_color}; border-color: #{border_color};"
  end

  # Convert RGB (0-1) to HSL
  # :reek:UtilityFunction - Pure calculation method, appropriate as private helper
  # :reek:TooManyStatements - Color conversion algorithm requires multiple calculations
  # :reek:UncommunicativeParameterName { accept: ['r', 'g', 'b'] } - Standard color abbreviations
  # :reek:UncommunicativeVariableName { accept: ['r', 'g', 'b', 'h', 's', 'l', 'd'] } - Standard color abbreviations
  # :reek:DuplicateMethodCall - Standard RGB to HSL algorithm
  def rgb_to_hsl(r, g, b)
    max = [ r, g, b ].max
    min = [ r, g, b ].min
    l = (max + min) / 2.0

    if max == min
      h = s = 0 # achromatic
    else
      d = max - min
      s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min)

      h = case max
      when r then ((g - b) / d + (g < b ? 6 : 0)) / 6.0
      when g then ((b - r) / d + 2) / 6.0
      when b then ((r - g) / d + 4) / 6.0
      end
    end

    [ h, s, l ]
  end
end

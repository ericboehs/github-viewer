# frozen_string_literal: true

# Component for displaying a GitHub issue label with color
class IssueLabelComponent < ViewComponent::Base
  # :reek:FeatureEnvy - Extracting values from label hash is initialization responsibility
  def initialize(label:)
    @label = label
    @name = label["name"] || label[:name]
    @color = label["color"] || label[:color]
  end

  def call
    tag.span(class: label_classes, style: label_styles) do
      @name
    end
  end

  private

  def label_classes
    "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
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

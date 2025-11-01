# Renders a user avatar image from Gravatar or external URL with fallback to initials
# :reek:TooManyInstanceVariables { max_instance_variables: 6 }
# :reek:RepeatedConditional
# :reek:LongParameterList - Component needs flexibility for user/src, alt, size, text_size, and loading
class AvatarComponent < ViewComponent::Base
  def initialize(user: nil, src: nil, alt: nil, size: 8, text_size: "sm", loading: "eager")
    @user = user
    @src = src
    @alt = alt
    @size = normalize_size(size)
    @text_size = text_size
    @loading = loading
  end

  private

  attr_reader :user, :src, :alt, :size, :text_size, :loading

  def avatar_url
    return user.avatar_url(size: 256) if using_user_avatar?
    src
  end

  def avatar_alt
    return user.email_address if using_user_avatar?
    alt || "User avatar"
  end

  def initials
    return user.initials if using_user_avatar?
    return alt[0..1].upcase if alt
    "?"
  end

  # :reek:RepeatedConditional - Checking user presence is necessary pattern for polymorphic avatar sources
  def using_user_avatar?
    user.present?
  end

  def size_classes
    "size-#{size} rounded-full"
  end

  def text_classes
    "text-#{text_size} font-medium text-white hidden"
  end

  # Convert symbol sizes to numeric values
  def normalize_size(size_value)
    case size_value
    when :small then 6
    when :medium then 10
    when :large then 16
    else size_value
    end
  end
end

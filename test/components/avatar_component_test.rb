require "test_helper"

# Tests the AvatarComponent component
class AvatarComponentTest < ViewComponent::TestCase
  test "renders avatar with default size" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    render_inline(AvatarComponent.new(user: user))

    assert_selector "div.size-8.rounded-full.bg-emerald-600"
    assert_selector "img.size-8.rounded-full"
    assert_selector "span.text-sm.font-medium.text-white.hidden"
  end

  test "renders avatar with custom size" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    render_inline(AvatarComponent.new(user: user, size: 20, text_size: "2xl"))

    assert_selector "div.size-20.rounded-full.bg-emerald-600"
    assert_selector "img.size-20.rounded-full"
    assert_selector "span.text-2xl.font-medium.text-white.hidden"
  end

  test "includes user email as alt text" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    render_inline(AvatarComponent.new(user: user))

    assert_selector "img[alt='#{user.email_address}']"
  end

  test "includes fallback initials" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    render_inline(AvatarComponent.new(user: user))

    assert_text user.initials
  end

  test "renders with external src and no user" do
    render_inline(AvatarComponent.new(src: "https://example.com/avatar.png", alt: "Test User"))

    assert_selector "img[src='https://example.com/avatar.png']"
    assert_selector "img[alt='Test User']"
  end

  test "uses alt text for initials when no user" do
    render_inline(AvatarComponent.new(src: "https://example.com/avatar.png", alt: "John Doe"))

    assert_text "JO"  # First two characters uppercase
  end

  test "shows question mark initials when no user and no alt" do
    render_inline(AvatarComponent.new(src: "https://example.com/avatar.png"))

    assert_text "?"
  end

  test "normalizes small symbol size" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    render_inline(AvatarComponent.new(user: user, size: :small))

    assert_selector "div.size-6.rounded-full"
  end

  test "normalizes medium symbol size" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    render_inline(AvatarComponent.new(user: user, size: :medium))

    assert_selector "div.size-10.rounded-full"
  end

  test "normalizes large symbol size" do
    user = User.create!(email_address: "test@example.com", password: "password123")
    render_inline(AvatarComponent.new(user: user, size: :large))

    assert_selector "div.size-16.rounded-full"
  end
end

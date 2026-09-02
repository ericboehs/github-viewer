require "test_helper"
require "axe/matchers/be_axe_clean"

# Silence Puma server output during system tests
Capybara.server = :puma, { Silent: true }

# Base class for system tests with Capybara and accessibility testing setup
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Assert that the current page is accessible according to WCAG 2.1 AA standards
  def assert_accessible(page = self.page, matcher = Axe::Matchers::BeAxeClean.new.according_to(:wcag21aa, "best-practice"))
    audit_result = matcher.audit(page)
    assert(audit_result.passed?, audit_result.failure_message)
  end
end

module SignInAsSystem
  # Capybara's fill_in can return before Selenium has registered the value,
  # which under load submits the form with an empty field and lands back on
  # the sign-in page. Setting the value and then verifying it — falling back
  # to writing the attribute directly — makes the submit never half-empty.
  def sign_in_as(user, password: "password123")
    visit new_session_path
    fill_session_field("Email address", user.email_address)
    fill_session_field("Password", password)
    click_button "Sign in"
  end

  private

  def fill_session_field(locator, value)
    field = find_field(locator)
    field.set(value)
    return if field.value == value

    page.execute_script(
      "arguments[0].value = arguments[1];" \
      "arguments[0].dispatchEvent(new Event('input', { bubbles: true }));",
      field, value
    )
    assert_equal value, field.value, "could not set the #{locator} field"
  end
end

ApplicationSystemTestCase.include SignInAsSystem

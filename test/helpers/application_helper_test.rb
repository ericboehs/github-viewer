# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "time_ago_tag returns empty string for nil datetime" do
    assert_equal "", time_ago_tag(nil)
  end

  test "time_ago_tag returns empty string for blank datetime" do
    assert_equal "", time_ago_tag("")
  end

  test "time_ago_tag returns time element with correct attributes" do
    datetime = 2.hours.ago
    result = time_ago_tag(datetime)

    assert_match(/<time/, result)
    assert_match(/data-controller="time"/, result)
    assert_match(/datetime="#{Regexp.escape(datetime.utc.iso8601)}"/, result)
    assert_match(/ago<\/time>/, result)
  end

  test "time_ago_tag displays relative time text" do
    datetime = 2.hours.ago
    result = time_ago_tag(datetime)

    assert_match(/2 hours ago/, result)
  end

  test "time_ago_tag accepts additional HTML options" do
    datetime = 1.day.ago
    result = time_ago_tag(datetime, class: "custom-class", id: "custom-id")

    assert_match(/class="custom-class"/, result)
    assert_match(/id="custom-id"/, result)
  end

  test "time_ago_tag preserves data-controller when additional data attributes provided" do
    datetime = 3.days.ago
    result = time_ago_tag(datetime, data: { action: "click->test#handler" })

    assert_match(/data-controller="time"/, result)
    # HTML entities are escaped in the output
    assert_match(/data-action="click-&gt;test#handler"/, result)
  end

  test "time_ago_tag uses ISO 8601 format for datetime attribute" do
    datetime = Time.zone.parse("2025-01-15 14:30:45")
    result = time_ago_tag(datetime)

    # Should be in UTC and ISO 8601 format
    assert_match(/datetime="2025-01-15T\d{2}:30:45Z"/, result)
  end
end

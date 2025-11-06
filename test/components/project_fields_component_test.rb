require "test_helper"

class ProjectFieldsComponentTest < ViewComponent::TestCase
  test "renders project with fields" do
    project_items = [
      {
        project_title: "Sprint Board",
        project_url: "https://github.com/orgs/test/projects/1",
        fields: {
          "Status" => "In Progress",
          "Estimate" => 5
        }
      }
    ]

    render_inline(ProjectFieldsComponent.new(project_items: project_items))

    assert_text "Projects"
    assert_text "Sprint Board"
    assert_text "Status"
    assert_text "In Progress"
    assert_text "Estimate"
    assert_text "5"
  end

  test "does not render when project_items empty" do
    render_inline(ProjectFieldsComponent.new(project_items: []))

    assert_no_text "Projects"
  end

  test "handles numeric values" do
    project_items = [
      {
        project_title: "Test",
        project_url: "https://example.com",
        fields: { "Number" => 42 }
      }
    ]

    render_inline(ProjectFieldsComponent.new(project_items: project_items))

    assert_text "42"
  end

  test "handles decimal values" do
    project_items = [
      {
        project_title: "Test",
        project_url: "https://example.com",
        fields: { "Decimal" => 3.5 }
      }
    ]

    render_inline(ProjectFieldsComponent.new(project_items: project_items))

    assert_text "3.5"
  end

  test "handles empty string values" do
    project_items = [
      {
        project_title: "Test",
        project_url: "https://example.com",
        fields: { "Empty" => "" }
      }
    ]

    render_inline(ProjectFieldsComponent.new(project_items: project_items))

    assert_text "None"
  end

  test "handles other value types" do
    project_items = [
      {
        project_title: "Test",
        project_url: "https://example.com",
        fields: { "Symbol" => :some_symbol }
      }
    ]

    render_inline(ProjectFieldsComponent.new(project_items: project_items))

    assert_text "some_symbol"
  end
end

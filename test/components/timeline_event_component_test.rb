require "test_helper"

class TimelineEventComponentTest < ViewComponent::TestCase
  test "renders comment event" do
    item = {
      type: "comment",
      id: "comment_123",
      created_at: Time.current,
      actor: "testuser",
      body: "Test comment body",
      avatar_url: "https://example.com/avatar.png"
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "testuser"
    assert_text "commented"
  end

  test "renders labeled event" do
    item = {
      type: "labeled",
      id: "labeled_123",
      created_at: Time.current,
      actor: "testuser",
      label: { name: "bug", color: "ff0000" }
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "testuser"
    assert_text "added"
    assert_text "bug"
  end

  test "renders status changed event" do
    item = {
      type: "status_changed",
      id: "status_123",
      created_at: Time.current,
      actor: "testuser",
      previous_status: "To Do",
      status: "In Progress",
      was_automated: false,
      project_title: "Sprint Board"
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "testuser"
    assert_text "Sprint Board"
    assert_text "To Do"
    assert_text "In Progress"
  end

  test "renders automated status change" do
    item = {
      type: "status_changed",
      id: "status_123",
      created_at: Time.current,
      actor: "bot",
      previous_status: "",
      status: "Done",
      was_automated: true,
      project_title: "Test Project"
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "automated"
  end

  test "renders milestoned event" do
    item = {
      type: "milestoned",
      id: "milestone_123",
      created_at: Time.current,
      actor: "testuser",
      milestone_title: "v1.0"
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "testuser"
    assert_text "v1.0"
  end

  test "renders added to project event" do
    item = {
      type: "added_to_project",
      id: "project_123",
      created_at: Time.current,
      actor: "testuser",
      project_title: "Sprint Board"
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "testuser"
    assert_text "Sprint Board"
  end

  test "renders unlabeled event" do
    item = {
      type: "unlabeled",
      id: "unlabeled_123",
      created_at: Time.current,
      actor: "testuser",
      label: { name: "bug", color: "ff0000" }
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "testuser"
    assert_text "removed"
  end

  test "renders demilestoned event" do
    item = {
      type: "demilestoned",
      id: "demilestone_123",
      created_at: Time.current,
      actor: "testuser",
      milestone_title: "v1.0"
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "testuser"
    assert_text "removed this from the"
    assert_text "v1.0"
  end

  test "renders removed from project event" do
    item = {
      type: "removed_from_project",
      id: "removed_123",
      created_at: Time.current,
      actor: "testuser",
      project_title: "Old Project"
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "testuser"
    assert_text "removed this from"
    assert_text "Old Project"
  end

  test "handles unknown event type" do
    item = {
      type: "unknown_event",
      id: "unknown_123",
      created_at: Time.current,
      actor: "testuser"
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "testuser"
  end

  test "renders consolidated labeled event with multiple labels" do
    item = {
      type: "labeled",
      id: "labeled_123_456",
      created_at: Time.current,
      actor: "testuser",
      labels: [
        { name: "bug", color: "ff0000" },
        { name: "enhancement", color: "00ff00" },
        { name: "documentation", color: "0000ff" }
      ]
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "testuser"
    assert_text "added"
    assert_text "bug"
    assert_text "enhancement"
    assert_text "documentation"
  end

  test "renders consolidated unlabeled event with multiple labels" do
    item = {
      type: "unlabeled",
      id: "unlabeled_123_456",
      created_at: Time.current,
      actor: "testuser",
      labels: [
        { name: "bug", color: "ff0000" },
        { name: "wontfix", color: "cccccc" }
      ]
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "testuser"
    assert_text "removed"
    assert_text "bug"
    assert_text "wontfix"
  end

  test "renders merged event" do
    item = {
      type: "merged",
      id: "merged_1",
      created_at: Time.current,
      actor: "maintainer",
      merge_ref_name: "main"
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "maintainer"
    assert_text "merged this pull request into"
    assert_text "main"
  end

  test "renders ready for review event" do
    item = {
      type: "ready_for_review",
      id: "rfr_1",
      created_at: Time.current,
      actor: "contributor"
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "marked this pull request ready for review"
  end

  test "renders review requested event" do
    item = {
      type: "review_requested",
      id: "rr_1",
      created_at: Time.current,
      actor: "contributor",
      reviewer: "maintainer"
    }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "requested a review from"
    assert_text "maintainer"
  end

  test "renders review events for each review state" do
    {
      "APPROVED" => "approved these changes",
      "CHANGES_REQUESTED" => "requested changes",
      "DISMISSED" => "had their review dismissed",
      "COMMENTED" => "reviewed these changes"
    }.each do |review_state, expected_text|
      render_inline(TimelineEventComponent.new(item: {
        type: "review",
        id: "review_#{review_state}",
        created_at: Time.current,
        actor: "reviewer",
        review_state: review_state
      }))

      assert_text expected_text
    end
  end

  test "renders nothing for unknown event types" do
    item = { type: "mystery", id: "x", created_at: Time.current, actor: "someone" }

    render_inline(TimelineEventComponent.new(item: item))

    assert_text "someone"
  end
end

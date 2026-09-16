# frozen_string_literal: true

module Projects
  # Who a list of projects belongs to: an organization or a user, on a host.
  #
  # The repository pages have a Repository record to carry the host and the
  # owner around; an organization's project list has no record behind it at
  # all, so this stands in for one.
  Owner = Data.define(:github_domain, :owner_type, :login) do
    def organization?
      ProjectUrls.organization?(owner_type)
    end
  end
end

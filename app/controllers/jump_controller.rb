# frozen_string_literal: true

# The "go to" box in the navbar: paste a GitHub URL, land on the same page
# here. See GithubLink for what counts as pasteable.
class JumpController < ApplicationController
  def show
    path = GithubLink.path_for(params[:to])
    return redirect_to path, allow_other_host: false if path

    redirect_back fallback_location: root_path, alert: t(".unrecognized")
  end
end

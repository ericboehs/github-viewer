# frozen_string_literal: true

# Controller for managing GitHub personal access tokens
class GithubTokensController < ApplicationController
  def create
    token = Current.user.github_tokens.build(github_token_params)

    if token.save
      redirect_to user_path, notice: t("github_tokens.create.success")
    else
      redirect_to user_path, alert: t("github_tokens.create.error", errors: token.errors.full_messages.join(", "))
    end
  end

  def destroy
    token = Current.user.github_tokens.find(params[:id])
    token.destroy

    redirect_to user_path, notice: t("github_tokens.destroy.success")
  end

  private

  def github_token_params
    params.require(:github_token).permit(:domain, :token)
  end
end

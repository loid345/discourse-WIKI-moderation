# frozen_string_literal: true

WikiModeration::Engine.routes.draw do
  get "/" => "wiki_moderation#index"
  post "/:id/approve" => "wiki_moderation#approve"
  post "/:id/reject" => "wiki_moderation#reject"
end

Discourse::Application.routes.append do
  mount ::WikiModeration::Engine, at: "wiki-moderation"
  get "/admin/plugins/wiki-moderation" => "admin/plugins#index", constraints: StaffConstraint.new
end

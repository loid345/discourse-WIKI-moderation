# frozen_string_literal: true

WikiModeration::Engine.routes.draw do
end

Discourse::Application.routes.draw { mount ::WikiModeration::Engine, at: "wiki-moderation" }

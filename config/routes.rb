# frozen_string_literal: true

DiscourseKuuBuddy::Engine.routes.draw do
  post "/activities" => "activities#create"
  put "/activities/:topic_id" => "activities#update"
  put "/activities/:topic_id/status" => "activities#update_status"
end

Discourse::Application.routes.draw { mount ::DiscourseKuuBuddy::Engine, at: "kuu-buddy" }

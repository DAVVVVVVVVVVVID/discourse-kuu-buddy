# frozen_string_literal: true

DiscourseKuuBuddy::Engine.routes.draw do
  post "/activities" => "activities#create"
  put "/activities/:topic_id" => "activities#update"
  put "/activities/:topic_id/status" => "activities#update_status"
  post "/activities/:topic_id/applications" => "applications#create"
  delete "/activities/:topic_id/applications/mine" => "applications#withdraw"
  put "/activities/:topic_id/applications/:application_id/accept" => "applications#accept"
  put "/activities/:topic_id/applications/:application_id/decline" => "applications#decline"
  delete "/activities/:topic_id/membership" => "members#leave"
  delete "/activities/:topic_id/members/:user_id" => "members#remove"
end

Discourse::Application.routes.draw { mount ::DiscourseKuuBuddy::Engine, at: "kuu-buddy" }

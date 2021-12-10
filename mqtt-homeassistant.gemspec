# frozen_string_literal: true

require_relative "lib/mqtt/home_assistant/version"

Gem::Specification.new do |s|
  s.name = "mqtt-homeassistant"
  s.version = MQTT::HomeAssistant::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Cody Cutrer"]
  s.email = "cody@cutrer.com'"
  s.homepage = "https://github.com/ccutrer/ruby-mqtt-homeassistant"
  s.summary = "Library for publishing device auto-discovery configuration for Home Assistant via MQTT."
  s.license = "MIT"
  s.metadata = {
    "rubygems_mfa_required" => "true"
  }

  s.files = Dir["{lib}/**/*"]

  s.required_ruby_version = ">= 2.5"

  s.add_dependency "homie-mqtt", "~> 1.6"
  s.add_dependency "json", "~> 2.0"

  s.add_development_dependency "byebug", "~> 11.0"
  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rubocop", "~> 1.23"
  s.add_development_dependency "rubocop-performance", "~> 1.12"
  s.add_development_dependency "rubocop-rake", "~> 0.6"
end

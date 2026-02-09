# frozen_string_literal: true

require_relative "lib/mqtt/homie/home_assistant/version"

Gem::Specification.new do |s|
  s.name = "mqtt-homie-homeassistant"
  s.version = MQTT::Homie::HomeAssistant::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Cody Cutrer"]
  s.email = "cody@cutrer.com'"
  s.homepage = "https://github.com/ccutrer/ruby-mqtt-homie-homeassistant"
  s.summary = "Library for publishing device auto-discovery configuration for Homie devices to Home Assistant as well."
  s.license = "MIT"
  s.metadata = {
    "rubygems_mfa_required" => "true"
  }

  s.files = Dir["{lib}/**/*"]

  s.required_ruby_version = ">= 2.5"

  s.add_dependency "homie-mqtt", "~> 1.7"
  s.add_dependency "mqtt-homeassistant", "~> 1.2"

  s.add_development_dependency "rake", "~> 13.0"
end

# frozen_string_literal: true

module MQTT
  module Homie
    module HomeAssistant
      module Device
        def self.included(klass)
          super
          klass.attr_accessor :home_assistant_device, :home_assistant_discovery_prefix
        end

        # @!visibility private
        def base_hass_config(config)
          config[:availability] = [{
            topic: "#{topic}/$state",
            payload_available: "ready",
            payload_not_available: "lost"
          }]
          config[:device] ||= {}
          config[:device][:name] ||= name
          config[:device][:identifiers] ||= id
          config[:device][:sw_version] ||= MQTT::Homie::Device::VERSION
          config[:node_id] = id
          config[:qos] = 1
        end
      end
    end
    Device.include(HomeAssistant::Device)
  end
end

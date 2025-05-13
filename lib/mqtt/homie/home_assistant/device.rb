# frozen_string_literal: true

module MQTT
  module Homie
    module HomeAssistant
      module Device
        def self.prepended(klass)
          super
          klass.attr_accessor :home_assistant_device, :home_assistant_discovery_prefix
        end

        def initialize(*args, home_assistant_discovery: true, **kwargs)
          super(*args, **kwargs)
          @home_assistant_discovery = home_assistant_discovery
        end

        def home_assistant_discovery?
          @home_assistant_discovery
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
    Device.prepend(HomeAssistant::Device)
  end
end

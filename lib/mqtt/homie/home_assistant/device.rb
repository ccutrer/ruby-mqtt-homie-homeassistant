# frozen_string_literal: true

module MQTT
  module Homie
    module HomeAssistant
      module Device
        def self.prepended(klass)
          super
          klass.attr_accessor :home_assistant_device, :home_assistant_origin, :home_assistant_discovery_prefix
        end

        def initialize(*args, home_assistant_discovery: true, **kwargs)
          super(*args, **kwargs)
          @home_assistant_discovery = home_assistant_discovery
        end

        def home_assistant_discovery?
          @home_assistant_discovery
        end

        def home_assistant_device_discovery?
          %i[device migrate].include?(@home_assistant_discovery)
        end

        def publish
          return super unless home_assistant_device_discovery?

          config = {}
          config[:device] = home_assistant_device if home_assistant_device
          config[:origin] = home_assistant_origin if home_assistant_origin
          base_hass_config(config)
          mqtt.publish_hass_device(id, migrate_discovery: @home_assistant_discovery == :migrate, **config) do
            super
          end
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
          config[:origin] ||= {}
          config[:origin][:sw_version] ||= MQTT::Homie::Device::VERSION
          config[:origin][:name] ||= name
          config[:node_id] ||= id unless home_assistant_device_discovery?
          config[:qos] = 1
        end
      end
    end
    Device.prepend(HomeAssistant::Device)
  end
end

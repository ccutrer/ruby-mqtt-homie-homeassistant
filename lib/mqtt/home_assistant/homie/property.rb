# frozen_string_literal: true

module MQTT
  module HomeAssistant
    module Homie
      module Property
        def initialize(*args, hass: nil, **kwargs)
          super(*args, **kwargs)

          return unless hass

          case hass
          when Symbol
            public_send("hass_#{hass}")
          when Hash
            raise ArgumentError, "hass must only contain one item" unless hass.length == 1

            public_send("hass_#{hass.first.first}", **hass.first.last)
          else
            raise ArgumentError, "hass must be a Symbol or a Hash of HASS device type to additional HASS options"
          end
        end

        %i[binary_sensor fan humidifier light number scene select sensor switch].each do |integration|
          class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def hass_#{integration}(device: nil, discovery_prefix: nil, **kwargs)
              discovery_prefix ||= self.device.home_assistant_discovery_prefix
              device = self.device.home_assistant_device.merge(device || {}) if self.device.home_assistant_device

              kwargs[:device] = device
              kwargs[:discovery_prefix] = discovery_prefix
              if published?
                HomeAssistant.publish_#{integration}(self, **kwargs)
              else
                kwargs[:method] = :publish_#{integration}
                pending_hass_registrations << kwargs
              end
            end
          RUBY
        end

        def publish
          super.tap do
            @pending_hass_registrations&.each do |entity|
              method = entity.delete(:method)
              HomeAssistant.public_send(method, self, **entity)
            end
            @pending_hass_registrations = nil
          end
        end

        private

        def pending_hass_registrations
          @pending_hass_registrations ||= []
        end
      end
    end
  end
end

MQTT::Homie::Property.prepend(MQTT::HomeAssistant::Homie::Property)

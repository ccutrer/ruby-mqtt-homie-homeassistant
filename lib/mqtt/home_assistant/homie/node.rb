# frozen_string_literal: true

module MQTT
  module HomeAssistant
    module Homie
      module Node
        {
          climate: %i[action
                      aux
                      away_mode
                      current_temperature
                      fan_mode
                      mode
                      hold
                      power
                      swing_mode
                      temperature
                      temperature_high
                      temperature_low],
          fan: [nil, :oscillation],
          humidifier: [nil, :target, :mode],
          light: [nil, :brightness, :color_mode, :color_temp, :effect, :hs, :rgb, :white, :xy]
        }.each do |(integration, properties)|
          has_nil = properties.include?(nil)
          method_arguments = []
          method_arguments << "property" if has_nil
          method_arguments.concat(properties.compact.map { |p| "#{p}_property: nil" })
          transforms = []
          transforms << "property = self[property] if property.is_a?(String)"
          transforms.concat(
            properties.compact.map do |p|
              "kwargs[:#{p}_property] = #{p}_property.is_a?(String) ? self[#{p}_property] : #{p}_property"
            end
          )
          args_code = has_nil ? "args = [property]" : "args = []"

          class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def hass_#{integration}(#{method_arguments.join(", ")}, device: nil, discovery_prefix: nil, **kwargs)
              #{transforms.join("\n")}
              discovery_prefix ||= self.device.home_assistant_discovery_prefix
              device = self.device.home_assistant_device.merge(device || {}) if self.device.home_assistant_device

              kwargs[:device] = device
              kwargs[:discovery_prefix] = discovery_prefix
              #{args_code}
              if published?
                HomeAssistant.publish_#{integration}(*args, **kwargs)
              else
                pending_hass_registrations << [:publish_#{integration}, args, kwargs]
              end
            end
          RUBY
        end

        def publish
          super.tap do
            @pending_hass_registrations&.each do |(method, args, kwargs)|
              HomeAssistant.public_send(method, *args, **kwargs)
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

MQTT::Homie::Node.prepend(MQTT::HomeAssistant::Homie::Node)

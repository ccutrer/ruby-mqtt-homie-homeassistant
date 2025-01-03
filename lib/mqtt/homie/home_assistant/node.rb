# frozen_string_literal: true

module MQTT
  module Homie
    module HomeAssistant
      module Node
        def hass_climate(action_property: nil,
                         current_humidity_property: nil,
                         current_temperature_property: nil,
                         fan_mode_property: nil,
                         mode_property: nil,
                         power_property: nil,
                         preset_mode_property: nil,
                         swing_mode_property: nil,
                         target_humidity_property: nil,
                         temperature_property: nil,
                         temperature_high_property: nil,
                         temperature_low_property: nil,
                         **kwargs)
          if power_property && power_property.datatype != :boolean
            raise ArgumentError, "Power property must be a boolean"
          end

          temperature_property = resolve_property(temperature_property)
          temperature_high_property = resolve_property(temperature_high_property)
          temperature_low_property = resolve_property(temperature_low_property)
          temp_properties = [
            temperature_property,
            temperature_high_property,
            temperature_low_property
          ].compact
          unless (temp_ranges = temp_properties.map(&:range).compact).empty?
            min = temp_ranges.map(&:begin).min
            max = temp_ranges.map(&:end).max
            kwargs[:temp_range] = min..max
          end
          kwargs[:temperature_unit] = temp_properties.map(&:unit).compact.first
          if power_property
            kwargs[:payload_off] = "false"
            kwargs[:payload_on] = "true"
          end

          hass_property(kwargs, action_property, :action, read_only: true)
          hass_property(kwargs, current_humidity_property, :current_humidity, read_only: true)
          hass_property(kwargs, current_temperature_property, :current_temperature, read_only: true)
          hass_enum(kwargs, fan_mode_property, :fan_mode)
          hass_enum(kwargs, mode_property, :mode, MQTT::HomeAssistant::DEFAULTS[:climate][:modes])
          hass_property(kwargs, power_property, :power)
          hass_enum(kwargs, preset_mode_property, :preset_mode)
          hass_enum(kwargs, swing_mode_property, :swing_mode)
          hass_property(kwargs, target_humidity_property, :target_humidity)
          hass_property(kwargs, temperature_property, :temperature)
          hass_property(kwargs, temperature_high_property, :temperature_high)
          hass_property(kwargs, temperature_low_property, :temperature_low)
          publish_hass_component(platform: :climate, **kwargs)
        end

        def hass_fan(property,
                     oscillation_property: nil,
                     preset_mode_property: nil,
                     **kwargs)
          hass_property(kwargs, property)
          hass_property(kwargs, oscillation_property, :oscillation)
          hass_enum(kwargs, preset_mode_property, :preset_mode)
          publish_hass_component(platform: :fan, **kwargs)
        end

        def hass_humidifier(property,
                            target_humidity_property: nil,
                            mode_property: nil,
                            **kwargs)
          hass_property(kwargs, property)
          hass_property(kwargs, target_humidity_property, :target_humidity)
          hass_property(kwargs, mode_property, :mode)
          publish_hass_component(platform: :humidifier,
                                 payload_off: "false",
                                 payload_on: "true",
                                 **kwargs)
        end

        def hass_light(property = nil,
                       brightness_property: nil,
                       color_mode_property: nil,
                       color_temp_property: nil,
                       effect_property: nil,
                       hs_property: nil,
                       rgb_property: nil,
                       white_property: nil,
                       xy_property: nil,
                       **kwargs)
          # automatically infer a brightness-only light and adjust config
          if brightness_property && property.nil?
            property = brightness_property
            kwargs[:on_command_type] = :brightness
          end
          case property.datatype
          when :boolean
            kwargs[:payload_off] = "false"
            kwargs[:payload_on] = "true"
          when :integer
            kwargs[:payload_off] = "0"
          when :float
            kwargs[:payload_off] = "0.0"
          end
          kwargs[:brightness_scale] = brightness_property.range.end if brightness_property&.range
          kwargs[:effect_list] = effect_property.range if effect_property&.datatype == :enum
          kwargs[:mireds_range] = color_temp_property.range if color_temp_property.unit == "mired"
          kwargs[:white_scale] = white_property.range.end if white_property&.range

          hass_property(kwargs, property)
          hass_property(kwargs, brightness_property, :brightness)
          hass_property(kwargs, color_mode_property, :color_mode)
          hass_property(kwargs, color_temp_property, :color_temp)
          hass_property(kwargs, effect_property, :effect)
          hass_property(kwargs, hs_property, :hs)
          hass_property(kwargs, rgb_property, :rgb)
          hass_property(kwargs, white_property, :white)
          hass_property(kwargs, xy_property, :xy)
          publish_hass_component(platform: :light, **kwargs)
        end

        def hass_water_heater(
          current_temperature_property: nil,
          mode_property: nil,
          power_property: nil,
          temperature_property: nil,
          **kwargs
        )
          temperature_property = resolve_property(temperature_property)
          current_temperature_property = resolve_property(current_temperature_property)
          temp_properties = [
            temperature_property,
            current_temperature_property
          ].compact
          kwargs[:range] = temperature_property&.range
          kwargs[:temperature_unit] = temp_properties.map(&:unit).compact.first
          if power_property
            kwargs[:payload_off] = "false"
            kwargs[:payload_on] = "true"
          end
          hass_property(kwargs, current_temperature_property, :current_temperature, read_only: true)
          hass_enum(kwargs, mode_property, :mode, MQTT::HomeAssistant::DEFAULTS[:water_heater][:modes])
          hass_property(kwargs, power_property, :power)
          hass_property(kwargs, temperature_property, :temperature)
          publish_hass_component(platform: :water_heater, **kwargs)
        end

        def publish
          super.tap do
            @pending_hass_registrations&.each do |(object_id, kwargs)|
              device.mqtt.publish_hass_component(object_id, **kwargs)
            end
            @pending_hass_registrations = nil
          end
        end

        private

        def resolve_property(property)
          return if property.nil?

          orig_property = property
          property = self[property] if property.is_a?(String)
          raise ArgumentError, "Unknown property #{orig_property}" if property.nil?

          property
        end

        def hass_property(config, property, prefix = nil, read_only: false, templates: {})
          resolve_property(property)&.hass_property(config, prefix, read_only: read_only, templates: templates)
        end

        def hass_enum(config, property, prefix = nil, valid_set = nil)
          return if property.nil?

          property = resolve_property(property)
          hass_property(config, property, prefix)

          return unless property.datatype == :enum

          values = property.range
          values &= valid_set if valid_set
          config[:"#{prefix}s"] = values
        end

        def publish_hass_component(device: nil, discovery_prefix: nil, object_id: nil, **kwargs)
          discovery_prefix ||= self.device.home_assistant_discovery_prefix
          device = self.device.home_assistant_device.merge(device || {}) if self.device.home_assistant_device

          object_id ||= id
          kwargs[:name] ||= name
          kwargs[:device] = device
          kwargs[:discovery_prefix] ||= discovery_prefix
          kwargs[:unique_id] ||= "#{self.device.id}_#{object_id}"
          self.device.base_hass_config(kwargs)
          if published?
            self.device.mqtt.publish_hass_component(object_id, **kwargs)
          else
            pending_hass_registrations << [object_id, kwargs]
          end
        end

        def pending_hass_registrations
          @pending_hass_registrations ||= []
        end
      end
    end
    Node.prepend(HomeAssistant::Node)
  end
end

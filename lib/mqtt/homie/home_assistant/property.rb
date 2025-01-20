# frozen_string_literal: true

module MQTT
  module Homie
    module HomeAssistant
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

        def hass_binary_sensor(**kwargs)
          raise ArgumentError, "Property must be a boolean" unless datatype == :boolean
          raise ArgumentError, "Property must not be settable" if settable?

          hass_property(kwargs)
          publish_hass_component(platform: :binary_sensor,
                                 payload_off: "false",
                                 payload_on: "true",
                                 **kwargs)
        end

        def hass_button(**kwargs)
          hass_property(kwargs)
          publish_hass_component(platform: :button, **kwargs)
        end

        def hass_fan(**kwargs)
          raise ArgumentError, "Property must be a boolean" unless datatype == :boolean
          raise ArgumentError, "Property must be settable" unless settable?

          hass_property(kwargs)
          publish_hass_component(platform: :fan,
                                 payload_off: "false",
                                 payload_on: "true",
                                 **kwargs)
        end

        def hass_light(**kwargs)
          case datatype
          when :boolean
            kwargs[:payload_off] = "false"
            kwargs[:payload_on] = "true"
          when :integer
            kwargs[:payload_off] = "0"
          when :float
            kwargs[:payload_off] = "0.0"
          end

          hass_property(kwargs)
          publish_hass_component(platform: :light, **kwargs)
        end

        def hass_number(**kwargs)
          raise ArgumentError, "Property must be an integer or a float" unless %i[integer float].include?(datatype)

          hass_property(kwargs)
          kwargs[:range] = range if range
          kwargs[:unit_of_measurement] = unit if unit

          publish_hass_component(platform: :number, **kwargs)
        end

        def hass_scene(**kwargs)
          unless datatype == :enum && range.length == 1
            raise ArgumentError, "Property must be an enum with a single value"
          end
          raise ArgumentError, "Property must be settable" unless settable?

          publish_hass_component(platform: :scene,
                                 command_topic: "#{topic}/set",
                                 payload_on: range.first,
                                 **kwargs)
        end

        def hass_select(**kwargs)
          raise ArgumentError, "Property must be an enum" unless datatype == :enum
          raise ArgumentError, "Property must be settable" unless settable?

          hass_property(kwargs)
          publish_hass_component(platform: :select, options: range, **kwargs)
        end

        def hass_sensor(**kwargs)
          if datatype == :enum
            kwargs[:device_class] = :enum
            kwargs[:options] = range
          end
          kwargs[:unit_of_measurement] = unit if unit

          publish_hass_component(platform: :sensor,
                                 state_topic: topic,
                                 **kwargs)
        end

        def hass_switch(**kwargs)
          raise ArgumentError, "Property must be a boolean" unless datatype == :boolean

          hass_property(kwargs)
          publish_hass_component(platform: :switch,
                                 payload_off: "false",
                                 payload_on: "true",
                                 **kwargs)
        end

        def publish
          super.tap do
            @pending_hass_registrations&.each do |(object_id, kwargs)|
              device.mqtt.publish_hass_component(object_id, **kwargs)
            end
            @pending_hass_registrations = nil
          end
        end

        # @!visibility private
        def hass_property(config, prefix = nil, read_only: false, templates: {})
          prefix = "#{prefix}_" if prefix
          state_prefix = "state_" unless read_only
          config[:"#{prefix}#{state_prefix}topic"] = topic if retained?
          if !read_only && settable?
            config[:"#{prefix}command_topic"] = "#{topic}/set"
            config[:"#{prefix}command_template"] = "{{ value | round(0) }}" if datatype == :integer
          end
          config.merge!(templates.slice(:"#{prefix}template", :"#{prefix}command_template"))
        end

        # @!visibility private
        def hass_enum(config, prefix = nil, valid_set = nil)
          prefix = "#{prefix}_" if prefix

          return unless datatype == :enum

          modes = range
          modes &= valid_set if valid_set
          config[:"#{prefix}modes"] = modes
        end

        private

        def publish_hass_component(device: nil, discovery_prefix: nil, object_id: nil, **kwargs)
          discovery_prefix ||= self.device.home_assistant_discovery_prefix
          device = self.device.home_assistant_device.merge(device || {}) if self.device.home_assistant_device

          object_id ||= "#{node.id}_#{id}"
          kwargs[:name] ||= "#{node.name} #{name}"
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
    Property.prepend(HomeAssistant::Property)
  end
end

# frozen_string_literal: true

require "json"

require "mqtt/homie"
require "mqtt/home_assistant/homie/device"
require "mqtt/home_assistant/homie/node"
require "mqtt/home_assistant/homie/property"

module MQTT
  module HomeAssistant
    class << self
      ENTITY_CATEGORIES = %i[config diagnostic system].freeze
      DEVICE_CLASSES = {
        binary_sensor: %i[
          battery
          battery_charging
          cold
          connectivity
          door
          garage_door
          gas
          heat
          light
          lock
          moisture
          motion
          moving
          occupancy
          opening
          plug
          power
          presence
          problem
          running
          safety
          smoke
          sound
          tamper
          update
          vibration
          window
        ].freeze,
        humidifier: %i[
          humidifier
          dehumidifier
        ].freeze,
        sensor: %i[
          aqi
          battery
          carbon_dioxide
          carbon_monoxide
          current
          date
          energy
          gas
          humidity
          illuminance
          monetary
          nitrogen_dioxide
          nitrogen_monoxide
          nitrous_oxide
          ozone
          pm1
          pm10
          pm25
          power_factor
          power
          pressure
          signal_strength
          sulphur_dioxide
          temperature
          timestamp
          volatile_organic_compounds
          voltage
        ].freeze
      }.freeze
      STATE_CLASSES = %i[measurement total total_increasing].freeze
      ON_COMMAND_TYPES = %i[last first brightness].freeze

      # @param property [MQTT::Homie::Property] A Homie property object of datatype :boolean
      def publish_binary_sensor(
        property,
        device_class: nil,
        expire_after: nil,
        force_update: false,
        off_delay: nil,

        device: nil,
        discovery_prefix: nil,
        entity_category: nil,
        icon: nil
      )
        raise ArgumentError, "Homie property must be a boolean" unless property.datatype == :boolean
        if device_class && !DEVICE_CLASSES[:binary_sensor].include?(device_class)
          raise ArgumentError, "Unrecognized device_class #{device_class.inspect}"
        end

        config = base_config(property.device,
                             property.full_name,
                             device_class: device_class,
                             device: device,
                             entity_category: entity_category,
                             icon: icon)
                 .merge({
                          payload_off: "false",
                          payload_on: "true",
                          object_id: "#{property.node.id}_#{property.id}",
                          state_topic: property.topic
                        })
        config[:expire_after] = expire_after if expire_after
        config[:force_update] = true if force_update
        config[:off_delay] = off_delay if off_delay

        publish(property.mqtt, "binary_sensor", config, discovery_prefix: discovery_prefix)
      end

      def publish_climate(
        action_property: nil,
        aux_property: nil,
        away_mode_property: nil,
        current_temperature_property: nil,
        fan_mode_property: nil,
        mode_property: nil,
        hold_property: nil,
        power_property: nil,
        swing_mode_property: nil,
        temperature_property: nil,
        temperature_high_property: nil,
        temperature_low_property: nil,
        name: nil,
        id: nil,
        precision: nil,
        temp_step: nil,

        device: nil,
        discovery_prefix: nil,
        entity_category: nil,
        icon: nil,
        templates: {}
      )
        properties = {
          action: action_property,
          aux: aux_property,
          away_mode: away_mode_property,
          current_temperature: current_temperature_property,
          fan_mode: fan_mode_property,
          mode: mode_property,
          hold: hold_property,
          power: power_property,
          swing_mode: swing_mode_property,
          temperature: temperature_property,
          temperature_high: temperature_high_property,
          temperature_low: temperature_low_property
        }.compact
        raise ArgumentError, "At least one property must be specified" if properties.empty?
        raise ArgumentError, "Power property must be a boolean" if power_property && power_property.datatype != :boolean

        node = properties.first.last.node

        config = base_config(node.device,
                             name || node.full_name,
                             device: device,
                             entity_category: entity_category,
                             icon: icon)

        config[:object_id] = id || node.id
        read_only_props = %i[action current_temperature]
        properties.each do |prefix, property|
          add_property(config, property, prefix, templates: templates, read_only: read_only_props.include?(prefix))
        end
        temp_properties = [
          temperature_property,
          temperature_high_property,
          temperature_low_property
        ].compact
        unless (temp_ranges = temp_properties.map(&:range).compact).empty?
          config[:min_temp] = temp_ranges.map(&:begin).min
          config[:max_temp] = temp_ranges.map(&:end).max
        end
        temperature_unit = temp_properties.map(&:unit).compact.first
        config[:temperature_unit] = temperature_unit[-1] if temperature_unit
        {
          nil => mode_property,
          :fan => fan_mode_property,
          :hold => hold_property,
          :swing => swing_mode_property
        }.compact.each do |prefix, property|
          valid_set = %w[auto off cool heat dry fan_only] if prefix.nil?
          add_enum(config, property, prefix, valid_set)
        end
        config[:precision] = precision if precision
        config[:temp_step] = temp_step if temp_step
        if power_property
          config[:payload_on] = "true"
          config[:payload_off] = "false"
        end

        publish(node.mqtt, "climate", config, discovery_prefix: discovery_prefix)
      end

      def publish_fan(
        property,
        oscillation_property: nil,
        percentage_property: nil,
        preset_mode_property: nil,

        device: nil,
        discovery_prefix: nil,
        entity_category: nil,
        icon: nil
      )
        config = base_config(property.device,
                             name || property.node.full_name,
                             device: device,
                             device_class: device_class,
                             entity_category: entity_category,
                             icon: icon,
                             templates: {})
        add_property(config, oscillation_property, :oscillation_property, templates: templates)
        add_property(config, percentage_property, :percentage, templates: templates)
        if percentage_property&.range
          config[:speed_range_min] = percentage_property.range.begin
          config[:speed_range_max] = percentage_property.range.end
        end
        add_property(config, preset_mode_property, :preset, templates: templates)
        add_enum(config, preset_mode_property, :preset)

        publish(node.mqtt, "fan", config, discovery_prefix: discovery_prefix)
      end

      def publish_humidifier(
        property,
        device_class:,
        target_property:,
        mode_property: nil,
        name: nil,
        id: nil,

        device: nil,
        discovery_prefix: nil,
        entity_category: nil,
        icon: nil
      )
        raise ArgumentError, "Homie property must be a boolean" unless property.datatype == :boolean

        unless DEVICE_CLASSES[:humidifier].include?(device_class)
          raise ArgumentError, "Unrecognized device_class #{device_class.inspect}"
        end

        config = base_config(property.device,
                             name || property.node.full_name,
                             device: device,
                             device_class: device_class,
                             entity_category: entity_category,
                             icon: icon)
                 .merge({
                          command_topic: "#{property.topic}/set",
                          target_humidity_command_topic: "#{target_property.topic}/set",
                          payload_off: "false",
                          payload_on: "true",
                          object_id: id || property.node.id
                        })
        add_property(config, property)
        add_property(config, target_property, :target_humidity)
        if (range = target_property.range)
          config[:min_humidity] = range.begin
          config[:max_humidity] = range.end
        end
        add_property(config, mode_property, :mode)
        add_enum(config, mode_property)

        publish(property.mqtt, "humidifier", config, discovery_prefix: discovery_prefix)
      end

      # `default` schema only for now
      def publish_light(
        property = nil,
        brightness_property: nil,
        color_mode_property: nil,
        color_temp_property: nil,
        effect_property: nil,
        hs_property: nil,
        rgb_property: nil,
        white_property: nil,
        xy_property: nil,
        on_command_type: nil,

        device: nil,
        discovery_prefix: nil,
        entity_category: nil,
        icon: nil,
        templates: {}
      )
        if on_command_type && !ON_COMMAND_TYPES.include?(on_command_type)
          raise ArgumentError, "Invalid on_command_type #{on_command_type.inspect}"
        end

        # automatically infer a brightness-only light and adjust config
        if brightness_property && property.nil?
          property = brightness_property
          on_command_type = :brightness
        end

        config = base_config(property.device,
                             property.full_name,
                             device: device,
                             entity_category: entity_category,
                             icon: icon)
        config[:object_id] = "#{property.node.id}_#{property.id}"
        add_property(config, property)
        case property.datatype
        when :boolean
          config[:payload_off] = "false"
          config[:payload_on] = "true"
        when :integer
          config[:payload_off] = "0"
        when :float
          config[:payload_off] = "0.0"
        end
        add_property(config, brightness_property, :brightness, templates: templates)
        config[:brightness_scale] = brightness_property.range.end if brightness_property&.range
        add_property(config, color_mode_property, :color_mode, templates: templates)
        add_property(config, color_temp_property, :color_temp, templates: templates)
        if color_temp_property&.range && color_temp_property.unit == "mired"
          config[:min_mireds] = color_temp_property.range.begin
          config[:max_mireds] = color_temp_property.range.end
        end
        add_property(config, effect_property, :effect, templates: templates)
        config[:effect_list] = effect_property.range if effect_property&.datatype == :enum
        add_property(config, hs_property, :hs, templates: templates)
        add_property(config, rgb_property, :rgb, templates: templates)
        add_property(config, white_property, :white, templates: templates)
        config[:white_scale] = white_property.range.end if white_property&.range
        add_property(config, xy_property, :xy, templates: templates)
        config[:on_command_type] = on_command_type if on_command_type

        publish(property.mqtt, "light", config, discovery_prefix: discovery_prefix)
      end

      def publish_number(
        property,
        step: nil,

        device: nil,
        discovery_prefix: nil,
        entity_category: nil,
        icon: nil
      )
        raise ArgumentError, "Homie property must be an integer or a float" unless %i[integer
                                                                                      float].include?(property.datatype)

        config = base_config(property.device,
                             property.full_name,
                             device: device,
                             entity_category: entity_category,
                             icon: icon)
        config[:object_id] = "#{property.node.id}_#{property.id}"
        add_property(config, property)
        config[:unit_of_measurement] = property.unit if property.unit
        if property.range
          config[:min] = property.range.begin
          config[:max] = property.range.end
        end
        config[:step] = step if step

        publish(property.mqtt, "number", config, discovery_prefix: discovery_prefix)
      end

      def publish_scene(
        property,

        device: nil,
        discovery_prefix: nil,
        entity_category: nil,
        icon: nil
      )
        unless property.datatype == :enum && property.range.length == 1
          raise ArgumentError, "Homie property must be an enum with a single value"
        end

        config = base_config(property.device,
                             property.full_name,
                             device: device,
                             entity_category: entity_category,
                             icon: icon)
        config[:object_id] = "#{property.node.id}_#{property.id}"
        add_property(config, property)
        config[:payload_on] = property.range.first

        publish(property.mqtt, "scene", config, discovery_prefix: discovery_prefix)
      end

      def publish_select(
        property,

        device: nil,
        discovery_prefix: nil,
        entity_category: nil,
        icon: nil
      )
        raise ArgumentError, "Homie property must be an enum" unless property.datatype == :enum
        raise ArgumentError, "Homie property must be settable" unless property.settable?

        config = base_config(property.device,
                             property.full_name,
                             device: device,
                             entity_category: entity_category,
                             icon: icon)
        config[:object_id] = "#{property.node.id}_#{property.id}"
        add_property(config, property)
        config[:options] = property.range

        publish(property.mqtt, "select", config, discovery_prefix: discovery_prefix)
      end

      # @param property [MQTT::Homie::Property] A Homie property object
      def publish_sensor(
        property,
        device_class: nil,
        expire_after: nil,
        force_update: false,
        state_class: nil,

        device: nil,
        discovery_prefix: nil,
        entity_category: nil,
        icon: nil
      )
        if device_class && !DEVICE_CLASSES[:sensor].include?(device_class)
          raise ArgumentError, "Unrecognized device_class #{device_class.inspect}"
        end
        if state_class && !STATE_CLASSES.include?(state_class)
          raise ArgumentError, "Unrecognized state_class #{state_class.inspect}"
        end

        config = base_config(property.device,
                             property.full_name,
                             device: device,
                             device_class: device_class,
                             entity_category: entity_category,
                             icon: icon)
                 .merge({
                          object_id: "#{property.node.id}_#{property.id}",
                          state_topic: property.topic
                        })
        config[:state_class] = state_class if state_class
        config[:expire_after] = expire_after if expire_after
        config[:force_update] = true if force_update
        config[:unit_of_measurement] = property.unit if property.unit

        publish(property.mqtt, "sensor", config, discovery_prefix: discovery_prefix)
      end

      # @param property [MQTT::Homie::Property] A Homie property object of datatype :boolean
      def publish_switch(property,
                         device_class: nil,

                         device: nil,
                         discovery_prefix: nil,
                         entity_category: nil,
                         icon: nil)
        raise ArgumentError, "Homie property must be a boolean" unless property.datatype == :boolean

        config = base_config(property.device,
                             property.full_name,
                             device: device,
                             device_class: device_class,
                             entity_category: entity_category,
                             icon: icon)
                 .merge({
                          object_id: "#{property.node.id}_#{property.id}",
                          payload_off: "false",
                          payload_on: "true"
                        })
        add_property(config, property)

        publish(property.mqtt, "switch", config, discovery_prefix: discovery_prefix)
      end

      private

      def add_property(config, property, prefix = nil, templates: {}, read_only: false)
        return unless property

        prefix = "#{prefix}_" if prefix
        state_prefix = "state_" unless read_only
        config[:"#{prefix}#{state_prefix}topic"] = property.topic if property.retained?
        if !read_only && property.settable?
          config[:"#{prefix}command_topic"] = "#{property.topic}/set"
          config[:"#{prefix}command_template"] = "{{ value | round(0) }}" if property.datatype == :integer
        end
        config.merge!(templates.slice(:"#{prefix}template", :"#{prefix}command_template"))
      end

      def add_enum(config, property, prefix = nil, valid_set = nil)
        prefix = "#{prefix}_" if prefix

        return unless property&.datatype == :enum

        modes = property.range
        modes &= valid_set if valid_set
        config[:"#{prefix}modes"] = modes
      end

      def base_config(homie_device,
                      name,
                      device:,
                      entity_category:,
                      icon:,
                      device_class: nil)
        if entity_category && !ENTITY_CATEGORIES.include?(entity_category)
          raise ArgumentError, "Unrecognized entity_category #{entity_category.inspect}"
        end

        config = {
          name: name,
          node_id: homie_device.id,
          availability_topic: "#{homie_device.topic}/$state",
          payload_available: "ready",
          payload_not_available: "lost",
          qos: 1
        }
        config[:device_class] = device_class if device_class
        config[:entity_category] = entity_category if entity_category
        config[:icon] = icon if icon

        device = device&.dup || {}
        device[:name] ||= homie_device.name
        device[:sw_version] ||= MQTT::Homie::Device::VERSION
        device[:identifiers] ||= homie_device.id unless device[:connections]
        config[:device] = device

        config
      end

      def publish(mqtt, component, config, discovery_prefix:)
        node_id, object_id = config.values_at(:node_id, :object_id)
        config = config.dup
        config[:unique_id] = "#{node_id}_#{object_id}"
        config.delete(:node_id)
        config.delete(:object_id)
        mqtt.publish("#{discovery_prefix || "homeassistant"}/#{component}/#{node_id}/#{object_id}/config",
                     config.to_json,
                     retain: true,
                     qos: 1)
      end
    end
  end
end

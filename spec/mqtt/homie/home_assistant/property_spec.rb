# frozen_string_literal: true

RSpec.describe MQTT::Homie::HomeAssistant::Property do
  let(:mqtt) do
    MQTT::Client.new.tap do |mqtt|
      allow(mqtt).to receive_messages(connect: nil,
                                      subscribe: nil,
                                      unsubscribe: nil)
    end
  end
  let(:device) { MQTT::Homie::Device.new("device", "device", mqtt:) }
  let(:node) { device.node("node", "node", "node") }
  let(:base_discovery_config) do
    {
      "name" => "node property",
      "dev" => {
        "name" => "device",
        "ids" => "device"
      },
      "avty" => [{
        "payload_available" => "ready",
        "payload_not_available" => "lost",
        "topic" => "homie/device/$state"
      }],
      "o" => {
        "name" => "device",
        "sw" => MQTT::Homie::HomeAssistant::VERSION
      },
      "qos" => 1,
      "uniq_id" => "device_node_property"
    }
  end
  subject(:property) do
    node.property("property", "property", datatype, format:, retained:, &block).tap do |p|
      allow(p).to receive(:published?).and_return(true)
    end
  end

  def expect_publish(discovery_config)
    allow(mqtt).to receive(:publish) do |topic, payload, qos:, retain:|
      expect(topic).to eql "homeassistant/#{platform}/device/node_property/config"
      expect(JSON.parse(payload)).to eql base_discovery_config.merge(discovery_config)
      expect(qos).to be 1
      expect(retain).to be true
    end
  end

  describe "#hass_button" do
    let(:platform) { "button" }

    context "with an enum property" do
      let(:block) { ->(_) {} }
      let(:datatype) { :enum }
      let(:format) { "ON" }
      let(:retained) { false }

      it "publishes to MQTT" do
        expect_publish({
                         "cmd_t" => "homie/device/node/property/set",
                         "pl_prs" => "ON"
                       })

        property.hass_button
      end

      context "when the property is not an enum" do
        let(:datatype) { :string }
        let(:format) { nil }

        it "raises ArgumentError" do
          expect(mqtt).not_to receive(:publish)
          expect { property.hass_button }.to raise_error(ArgumentError, "Property must be an enum")
        end
      end

      context "with multiple possible values" do
        let(:format) { "ON,OFF" }

        it "raises ArgumentError" do
          expect(mqtt).not_to receive(:publish)
          expect { property.hass_button }.to raise_error(ArgumentError, "Property must have one valid enum value")
        end

        context "with payload_press" do
          it "publishes to MQTT" do
            expect_publish({
                             "cmd_t" => "homie/device/node/property/set",
                             "pl_prs" => "OFF"
                           })

            property.hass_button(payload_press: "OFF")
          end

          it "enforces that payload_press is a valid value" do
            expect(mqtt).not_to receive(:publish)
            expect { property.hass_button(payload_press: "INVALID") }.to raise_error(
              ArgumentError,
              "payload_press must be a valid enum value"
            )
          end
        end
      end
    end
  end
end

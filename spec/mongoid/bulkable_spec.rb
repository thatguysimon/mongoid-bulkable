require 'spec_helper'
require 'mongoid'
require "mongoid/bulkable/creation_result"

class Banana
  include Mongoid::Document
  include Mongoid::Bulkable

  field :color, type: String

  validates :color, presence: true
end

RSpec.describe Mongoid::Bulkable do
  describe ".bulk_create" do
    context "when bulk-creating objects" do
      let(:bananas) do
        [
          Banana.new(color: "Yellow"),
          Banana.new(color: "Greenish-Yellow"),
          Banana.new(color: "Green"),
          Banana.new
        ]
      end

      subject(:creation_result) { Banana.bulk_create(bananas) }

      it { is_expected.to be_instance_of(Mongoid::Bulkable::CreationResult) }

      it "saves only valid objects to the DB" do
        expect { creation_result }.to change(Banana, :count).by(3)
      end

      it "collects the created objects" do
        expect(creation_result.created_objects.length).to eq(3)
        expect(creation_result.created_objects).to all(be_instance_of(Banana))
      end

      it "collects the invalid objects" do
        expect(creation_result.invalid_objects.length).to eq(1)
        expect(creation_result.invalid_objects).to all(be_instance_of(Banana))
      end
    end
  end
end

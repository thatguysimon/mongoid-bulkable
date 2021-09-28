# frozen_string_literal: true

require "spec_helper"
require "mongoid"
require "mongoid/bulkable/create_result"

class Market
  include Mongoid::Document
  include Mongoid::Bulkable

  field :city, type: String

  has_many :stands
end

class Stand
  include Mongoid::Document
  include Mongoid::Bulkable

  field :name, type: String

  belongs_to :market, required: false
  has_many :fruits

  validates :name, presence: true
end

class Fruit
  include Mongoid::Document
  include Mongoid::Bulkable

  field :name, type: String

  belongs_to :stand
end

RSpec.describe Mongoid::Bulkable do
  describe ".bulk_create" do
    context "when bulk-creating objects" do
      subject(:create_result) { Stand.bulk_create(stands) }

      let(:stands) do
        [
          Stand.new(name: "Stand 1"),
          Stand.new(name: "Stand 2"),
          Stand.new(name: "Stand 3"),
          Stand.new
        ]
      end

      it { is_expected.to be_instance_of(Mongoid::Bulkable::CreateResult) }

      it "saves only valid objects to the DB" do
        expect { create_result }.to change(Stand, :count).by(3)
      end

      it "collects the inserted ids" do
        expect(create_result.inserted_ids.length).to eq(3)
      end

      it "collects the invalid objects" do
        expect(create_result.invalid_objects.length).to eq(1)
        expect(create_result.invalid_objects).to all(be_instance_of(Stand))
      end
    end

    context "when bulk-creating objects with associations" do
      subject(:create_result) { Stand.bulk_create(stands) }

      let(:stands) do
        [
          Stand.new(
            name: "Stand 1",
            fruits: [
              Fruit.new(name: "Banana"),
              Fruit.new(name: "Apple")
            ]
          ),
          Stand.new(
            name: "Stand 2",
            fruits: [
              Fruit.new(name: "Melon")
            ]
          ),
          Stand.new
        ]
      end

      it { is_expected.to be_instance_of(Mongoid::Bulkable::CreateResult) }

      it "saves valid objects to the DB" do
        expect { create_result }.to change(Stand, :count).by(2).and change(Fruit, :count).by(3)
      end

      it "collects the inserted ids" do
        expect(create_result.inserted_ids.length).to eq(5)
      end

      it "collects the invalid objects" do
        expect(create_result.invalid_objects.length).to eq(1)
        expect(create_result.invalid_objects.first).to be_instance_of(Stand)
      end
    end

    context "when bulk-creating objects and their belongs-to associations" do
      subject(:create_result) { Fruit.bulk_create(fruits, create_belongs_to_relations: [:stand]) }

      let(:fruits) do
        [
          Fruit.new(
            name: "Apple",
            stand: Stand.new(name: "Stand 1")
          ),
          Fruit.new(
            name: "Banana",
            stand: Stand.new(name: "Stand 2")
          )
        ]
      end

      it { is_expected.to be_instance_of(Mongoid::Bulkable::CreateResult) }

      it "saves only valid objects to the DB" do
        expect { create_result }.to change(Fruit, :count).by(2).and change(Stand, :count).by(2)
      end

      it "collects the inserted ids" do
        expect(create_result.inserted_ids.length).to eq(2)
      end

      it "collects the invalid objects" do
        expect(create_result.invalid_objects.length).to eq(0)
        expect(create_result.invalid_objects).to all(be_instance_of(Fruit))
      end
    end
  end
end

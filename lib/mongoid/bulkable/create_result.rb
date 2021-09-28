# frozen_string_literal: true

module Mongoid
  module Bulkable
    class CreateResult
      attr_accessor :invalid_objects, :inserted_ids

      def initialize
        @invalid_objects = []
        @inserted_ids = []
      end
    end
  end
end

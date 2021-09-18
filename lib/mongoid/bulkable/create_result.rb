# frozen_string_literal: true

module Mongoid
  module Bulkable
    class CreateResult
      attr_accessor :invalid_objects, :created_objects

      def initialize
        @invalid_objects = []
        @created_objects = []
      end
    end
  end
end

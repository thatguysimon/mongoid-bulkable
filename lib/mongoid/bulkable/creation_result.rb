module Mongoid
  module Bulkable
    class CreationResult
      attr_accessor :invalid_objects, :created_objects

      def initialize
        @invalid_objects = []
        @created_objects = []
      end

      def add_invalid_object(invalid_object)
        invalid_objects << invalid_object
      end
    end
  end
end

# frozen_string_literal: true

require "mongoid/bulkable/version"

module Mongoid
  module Bulkable
    class Error < StandardError; end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def bulk_create(objects, batch_size: nil)
        batch_size ||= objects.size
        bulk_creation_result = CreationResult.new
        all_inserted_ids = []

        objects.each_slice(batch_size) do |batch|
          documents_batch = batch.map do |object|
            if object.valid?
              object.attributes
            else
              bulk_creation_result.add_invalid_object(object)
              next
            end
          end.compact

          next if documents_batch.empty?

          insert_result = collection.insert_many(documents_batch)
          all_inserted_ids += insert_result.inserted_ids if insert_result.inserted_ids
        end

        bulk_creation_result.created_objects = where(:_id.in => all_inserted_ids)
        bulk_creation_result
      end
    end
  end
end

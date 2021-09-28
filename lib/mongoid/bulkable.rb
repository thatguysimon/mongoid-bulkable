# frozen_string_literal: true

require "mongoid/bulkable/version"

module Mongoid
  module Bulkable
    class Error < StandardError; end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def bulk_create(objects, batch_size: nil, validate: true, create_belongs_to_associations: [])
        batch_size ||= objects.size
        bulk_create_result = CreateResult.new
        invalid_objects = []
        inserted_ids = []

        objects.each_slice(batch_size) do |objects_batch|
          invalid_objects, inserted_ids =
            recursively_bulk_create_objects(
              self,
              objects_batch,
              validate: validate,
              create_has_associations: true,
              create_belongs_to_associations: create_belongs_to_associations
            )
        end

        bulk_create_result.invalid_objects = invalid_objects
        bulk_create_result.inserted_ids = inserted_ids
        bulk_create_result
      end

      private

      def recursively_bulk_create_objects(
        klass,
        objects,
        validate:,
        create_has_associations: true,
        create_belongs_to_associations: []
      )
        object_classes = objects.map(&:class).uniq
        if object_classes.length > 1 || object_classes.first != klass
          raise ArgumentError, "One or more objects are not instances of the provided class"
        end

        belongs_to_association = klass.relations.filter do |_, association|
          association.macro == :belongs_to && association.name.in?(create_belongs_to_associations)
        end.values

        has_one_or_many_associations = klass.relations.filter do |_, association|
          association.macro == :has_many || association.macro == :has_one
        end.values

        association_classes_to_objects = {}
        belongs_to_association_classes_to_objects = {}
        documents_to_insert = []
        invalid_objects = []

        objects.each do |object|
          if !validate || object.valid?
            documents_to_insert << object.as_document

            belongs_to_association.each do |association|
              associated_object = object.public_send(association.name)
              unless associated_object.nil?
                belongs_to_association_classes_to_objects[association.class_name.constantize] ||= []
                belongs_to_association_classes_to_objects[association.class_name.constantize] << associated_object
              end
            end

            has_one_or_many_associations.each do |association|
              association_objects = object.public_send(association.name)
              if !association_objects.nil? && !association_objects.empty?
                association_classes_to_objects[association.class_name.constantize] ||= []
                association_classes_to_objects[association.class_name.constantize] += association_objects
              end
            end
          else
            invalid_objects << object
          end
        end

        return [invalid_objects, []] if documents_to_insert.empty?

        insert_result = klass.collection.insert_many(documents_to_insert)

        associations_invalid_objects = []
        associations_inserted_ids = []

        belongs_to_association_classes_to_objects.each do |kls, objs|
          belongs_to_invalid_objects, belongs_to_inserted_ids =
            recursively_bulk_create_objects(kls, objs, create_has_associations: false, validate: validate)

          associations_invalid_objects += belongs_to_invalid_objects
          associations_inserted_ids += belongs_to_inserted_ids
        end

        if create_has_associations
          association_classes_to_objects.each do |kls, objs|
            has_associations_invalid_objects, has_associations_inserted_ids =
              recursively_bulk_create_objects(kls, objs, validate: validate)

            associations_invalid_objects += has_associations_invalid_objects
            associations_inserted_ids += has_associations_inserted_ids
          end
        end

        [
          invalid_objects + associations_invalid_objects,
          insert_result.inserted_ids + associations_inserted_ids
        ]
      end
    end
  end
end

# frozen_string_literal: true

require "mongoid/bulkable/version"

module Mongoid
  module Bulkable
    class Error < StandardError; end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def bulk_create(objects, batch_size: nil, validate: true, create_belongs_to_relations: [])
        batch_size ||= objects.size
        bulk_create_result = CreateResult.new
        invalid_objects = nil
        created_objects = nil

        objects.each_slice(batch_size) do |objects_batch|
          invalid_objects, created_objects =
            recursively_bulk_create_objects(
              self,
              objects_batch,
              validate: validate,
              create_has_relations: true,
              create_belongs_to_relations: create_belongs_to_relations
            )
        end

        bulk_create_result.invalid_objects = invalid_objects
        bulk_create_result.created_objects = created_objects
        bulk_create_result
      end

      private

      def recursively_bulk_create_objects(
        klass,
        objects,
        validate:,
        create_has_relations: true,
        create_belongs_to_relations: []
      )
        object_classes = objects.map(&:class).uniq
        if object_classes.length > 1 || object_classes.first != klass
          raise ArgumentError, "One or more objects are not instances of the provided class"
        end

        has_one_or_many_relations = klass.relations.filter do |_, relation|
          relation.macro == :has_many || relation.macro == :has_one
        end.values

        belongs_to_relations = klass.relations.filter do |_, relation|
          relation.macro == :belongs_to && relation.name.in?(create_belongs_to_relations)
        end.values

        relation_classes_to_objects = {}
        belongs_to_relation_classes_to_objects = {}
        documents_to_insert = []
        invalid_objects = []

        objects.each do |object|
          belongs_to_relations.each do |relation|
            relation_object = object.public_send(relation.name)
            unless relation_object.nil?
              belongs_to_relation_classes_to_objects[relation.class_name.constantize] ||= []
              belongs_to_relation_classes_to_objects[relation.class_name.constantize] << relation_object
            end
          end

          if object.valid?
            documents_to_insert << object.as_document

            has_one_or_many_relations.each do |relation|
              relation_objects = object.public_send(relation.name)
              if !relation_objects.nil? && !relation_objects.empty?
                relation_classes_to_objects[relation.class_name.constantize] ||= []
                relation_classes_to_objects[relation.class_name.constantize] += relation_objects
              end
            end
          else
            invalid_objects << object
          end
        end

        inner_invalid_objects = []
        created_objects = []
        belongs_to_relation_classes_to_objects.each do |kls, objs|
          _inner_invalid_objects, created_belongs_to_objects =
            recursively_bulk_create_objects(kls, objs, create_has_relations: false, validate: validate)
        end

        return [[], []] if documents_to_insert.empty?

        insert_result = klass.collection.insert_many(documents_to_insert)
        inserted_ids = insert_result.inserted_ids

        inner_invalid_objects = []
        inner_created_objects = []

        if create_has_relations
          relation_classes_to_objects.each do |kls, objs|
            inner_invalid_objects, inner_created_objects =
              recursively_bulk_create_objects(kls, objs, validate: validate)
          end
        end

        [
          invalid_objects + inner_invalid_objects,
          klass.where(:_id.in => inserted_ids).to_a + inner_created_objects
        ]
      end
    end
  end
end

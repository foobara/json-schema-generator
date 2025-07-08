module Foobara
  module JsonSchemaGenerator
    class << self
      def to_json_schema(type, association_depth: Foobara::AssociationDepth::ATOM)
        poro = to_json_schema_structure(type, association_depth:)

        JSON.fast_generate(poro)
      end

      def to_json_schema_structure(type, association_depth: Foobara::AssociationDepth::ATOM)
        foobara_type_to_json_schema_type_poro(type, association_depth:)
      end

      private

      def foobara_type_to_json_schema_type_poro(type, association_depth:, within_entity: false, description: nil)
        declaration_data = type.declaration_data

        type_hash = if type.extends?(BuiltinTypes[:entity])
                      target_class = type.target_class

                      if association_depth == AssociationDepth::PRIMARY_KEY_ONLY ||
                         (association_depth == AssociationDepth::ATOM && within_entity)
                        description = unless type.extends_directly?(:entity)
                                        [
                                          "#{target_class.model_name} #{target_class.primary_key_attribute}",
                                          type.description
                                        ].join(" : ")
                                      end

                        foobara_type_to_json_schema_type_poro(
                          target_class.primary_key_type,
                          description:,
                          association_depth:,
                          within_entity: true
                        )
                      else
                        foobara_type_to_json_schema_type_poro(target_class.attributes_type,
                                                              association_depth:, within_entity: true)
                      end

                    elsif type.extends?(BuiltinTypes[:model])
                      foobara_type_to_json_schema_type_poro(type.target_class.attributes_type, association_depth:,
                                                                                               within_entity:)
                    elsif type.extends?(BuiltinTypes[:tuple])
                      # TODO: implement this logic for tuple
                      # :nocov:
                      raise ArgumentError, "Tuple not yet supported"
                      # :nocov:
                    elsif type.extends?(BuiltinTypes[:array])
                      items = if type.element_type
                                foobara_type_to_json_schema_type_poro(type.element_type, association_depth:,
                                                                                         within_entity:)
                              else
                                {}
                              end

                      { type: "array", items: }
                    elsif type.extends?(BuiltinTypes[:attributes])
                      properties = {}
                      required = DataPath.value_at(:required, declaration_data)
                      h = { type: "object" }

                      type.element_types&.each_pair do |attribute_name, element_type|
                        properties[attribute_name] = foobara_type_to_json_schema_type_poro(
                          element_type,
                          association_depth:,
                          within_entity:
                        )
                      end

                      if required&.any?
                        h[:required] = required
                      end

                      unless properties.empty?
                        h[:properties] = properties
                      end

                      h
                    elsif type.extends?(BuiltinTypes[:datetime])
                      { type: "string", format: "date-time" }
                    elsif type.extends?(BuiltinTypes[:date])
                      { type: "string", format: "date" }
                    elsif type.extends?(BuiltinTypes[:email])
                      { type: "string", format: "email" }
                    elsif type.extends?(BuiltinTypes[:string]) || type.extends?(BuiltinTypes[:symbol])
                      { type: "string" }
                    elsif type.extends?(BuiltinTypes[:boolean])
                      { type: "boolean" }
                    elsif type.extends?(BuiltinTypes[:number])
                      { type: "number" }
                    elsif type.extends?(BuiltinTypes[:associative_array])
                      # TODO: implement this
                      # :nocov:
                      raise ArgumentError, "Associative array not yet supported"
                      # :nocov:
                    elsif type.extends?(BuiltinTypes[:duck])
                      {}
                    else
                      # :nocov:
                      # This should be unreachable because every type extends duck...
                      raise ArgumentError, "Unable to convert #{declaration_data} to a JSON schema type"
                      # :nocov:
                    end

        one_of = DataPath.value_at(:one_of, declaration_data)

        if one_of&.any?
          type_hash[:enum] = one_of
        end

        allow_nil = DataPath.value_at(:allow_nil, declaration_data)

        if allow_nil && type_hash.key?(:type)
          type_hash[:type] = [type_hash[:type], "null"]
        end

        if description
          type_hash[:description] = description
        elsif !type.builtin? && type.description
          type_hash[:description] = type.description
        end

        type_hash
      end
    end
  end
end

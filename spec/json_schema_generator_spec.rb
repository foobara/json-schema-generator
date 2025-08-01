# TODO: move serializers to their own project so we don't have to include command_connectors to use them
require "foobara/command_connectors"

require "json-schema"

RSpec.describe Foobara::JsonSchemaGenerator do
  after do
    Foobara.reset_alls
  end

  before do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
  end

  describe ".to_json_schema" do
    let(:json_schema) { described_class.to_json_schema(type, association_depth:) }
    let(:parsed_json_schema) { JSON.parse(json_schema) }
    let(:association_depth) { Foobara::AssociationDepth::ATOM }
    let(:type) { Foobara::GlobalDomain.foobara_type_from_declaration(type_declaration) }

    context "with a complex data type" do
      before do
        stub_class "SomeModel", Foobara::Model do
          attributes do
            first_name :string, :allow_nil
            some_array []
            some_date :date
            some_datetime :datetime
            email :email
            some_flag :boolean, default: false
            anything :duck
          end
        end

        stub_class "SomeOtherEntity", Foobara::Entity do
          attributes do
            id :string
            bar :symbol
          end

          primary_key :id
        end

        stub_class "SomeEntity", Foobara::Entity do
          description "this is some entity!"

          attributes do
            id :integer
            foo :integer, :required, "must be one, two, or three", one_of: [1, 2, 3]
            some_other_entity SomeOtherEntity, "some other random entity"
            some_model SomeModel
          end

          primary_key :id
        end
      end

      let(:type) do
        Foobara::GlobalDomain.foobara_type_from_declaration do
          entity1 SomeEntity, :required
          some_array [SomeOtherEntity]
        end
      end

      it "results in a valid json schema" do
        expect(parsed_json_schema["type"]).to eq("object")
        expect(parsed_json_schema["required"]).to eq(["entity1"])

        properties = parsed_json_schema["properties"]

        expect(properties.keys).to contain_exactly("entity1", "some_array")
        expect(properties.keys).to_not include("required")

        some_array = properties["some_array"]
        expect(some_array["type"]).to eq("array")
        expect(some_array["items"]).to eq(
          "type" => "object", "properties" => {
            "id" => { "type" => "string" },
            "bar" => { "type" => "string" }
          }
        )
        expect(properties["entity1"]["properties"]["foo"]["enum"]).to eq([1, 2, 3])
        expect(
          properties["entity1"]["properties"]["some_model"]["properties"]["first_name"]["type"]
        ).to eq(["string", "null"])

        some_entity = SomeEntity.transaction do
          SomeEntity.create(
            foo: 2,
            some_other_entity: SomeOtherEntity.create(id: "foo", bar: :bar),
            some_model: SomeModel.new(first_name: "Barbara", some_flag: true)
          )
        end

        some_other_entity = SomeOtherEntity.transaction do
          SomeOtherEntity.create(id: "bar", bar: :baz)
        end

        serializer = Foobara::CommandConnectors::Serializers::AtomicSerializer.new
        some_entity_json = serializer.serialize(some_entity)
        some_other_entity_json = serializer.serialize(some_other_entity)

        data = {
          entity1: some_entity_json,
          some_array: [some_other_entity_json, some_other_entity_json]
        }

        json = JSON.fast_generate(data)

        expect(json).to be_a(String)

        expect { JSON::Validator.validate!(JSON.parse(json_schema), JSON.parse(json)) }.to_not raise_error

        data[:entity1][:foo] = 4
        json = JSON.fast_generate(data)

        expect {
          JSON::Validator.validate!(JSON.parse(json_schema), JSON.parse(json))
        }.to raise_error(JSON::Schema::ValidationError)

        data[:entity1][:foo] = 3
        json = JSON.fast_generate(data)

        expect { JSON::Validator.validate!(JSON.parse(json_schema), JSON.parse(json)) }.to_not raise_error
      end

      context "when using an aggregate depth" do
        let(:association_depth) { Foobara::AssociationDepth::AGGREGATE }

        it "includes types in the json schema all the way down" do
          expect(parsed_json_schema).to be_a(Hash)

          expect(parsed_json_schema["properties"]["entity1"]["description"]).to eq("this is some entity!")
          expect(
            parsed_json_schema["properties"]["entity1"]["properties"]["foo"]["description"]
          ).to eq("must be one, two, or three")
        end
      end
    end

    context "with an entity" do
      let(:entity_class) do
        stub_class "SomeEntity", Foobara::Entity do
          description "this is some entity!"

          attributes do
            id :integer
            foo :string, :required
          end

          primary_key :id
        end
      end

      let(:type) do
        Foobara::GlobalDomain.foobara_type_from_declaration(entity_class)
      end

      context "when primary key only" do
        let(:association_depth) { Foobara::AssociationDepth::PRIMARY_KEY_ONLY }

        it "results in a valid json schema with the primary key instead of the entity" do
          expect(parsed_json_schema).to eq(
            "type" => "number",
            "description" => "SomeEntity id : this is some entity!"
          )
        end

        context "when allow_nil" do
          let(:type) do
            Foobara::GlobalDomain.foobara_type_from_declaration entity_class, :allow_nil
          end

          it "includes nil as a type" do
            expect(parsed_json_schema).to eq(
              "type" => ["number", "null"],
              "description" => "SomeEntity id"
            )
          end
        end

        context "with a custom description" do
          let(:type) do
            Foobara::GlobalDomain.foobara_type_from_declaration entity_class, description: "a custom description"
          end

          it "includes the custom description" do
            expect(parsed_json_schema).to eq(
              "type" => "number",
              "description" => "SomeEntity id : a custom description"
            )
          end

          context "when allow_nil" do
            let(:type) do
              Foobara::GlobalDomain.foobara_type_from_declaration entity_class, :allow_nil,
                                                                  description: "a custom description"
            end

            it "includes nil as a type" do
              expect(parsed_json_schema).to eq(
                "type" => ["number", "null"],
                "description" => "SomeEntity id : a custom description"
              )
            end
          end
        end
      end
    end

    context "with a tuple" do
      let(:type_declaration) { [:integer, :string, :integer] }

      it "results in a valid json schema with the expected types and sizes" do
        expect(parsed_json_schema).to eq(
          "type" => "array",
          "items" => [
            { "type" => "number" },
            { "type" => "string" },
            { "type" => "number" }
          ],
          "minItems" => 3,
          "maxItems" => 3,
          "additionalItems" => false
        )
      end

      context "when all the items have the same type" do
        let(:type_declaration) { [:integer, :integer, :integer] }

        it "just gives one items type for simplicity" do
          expect(parsed_json_schema).to eq(
            "type" => "array",
            "items" => { "type" => "number" },
            "minItems" => 3,
            "maxItems" => 3,
            "additionalItems" => false
          )
        end
      end
    end
  end
end

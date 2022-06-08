require_relative 'inferno_template/patient_group'

module InfernoTemplate
  class Suite < Inferno::TestSuite
    id :test_suite_template
    title 'Inferno Test Suite Template'
    description 'A basic test suite template for Inferno'

    # This input will be available to all tests in this suite
    input :url
    input :access_token

    # All FHIR requests in this suite will use this FHIR client
    fhir_client do
      url :url
      bearer_token :access_token
    end

    # Tests and TestGroups can be defined inline
    group do
      id :capability_statement
      title 'Capability Statement'
      description 'Verify that the server has a CapabilityStatement'

      test do
        id :capability_statement_read
        title 'Read CapabilityStatement'
        description 'Read CapabilityStatement from /metadata endpoint'

        run do
          fhir_get_capability_statement

          assert_response_status(200)
          assert_resource_type(:capability_statement)
        end
      end
    end

    # Tests and TestGroups can be written in separate files and then included
    # using their id
    group from: :patient_group

    group do
      id :search_tests
      title 'Search Tests'

      input :patient_id

      test do
        title 'Condition Search by Patient'

        run do
          fhir_search('Condition', params: { patient: patient_id })

          assert_response_status(200)
          assert_resource_type('Bundle')
          assert_valid_bundle_entries(
            resource_types: {
              'Condition': 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-condition'
            }
          )
        end
      end
    end
  end
end
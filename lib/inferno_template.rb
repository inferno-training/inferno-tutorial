
require_relative 'inferno_template/patient_group'
require 'smart_app_launch_test_kit'

module InfernoTemplate
  class Suite < Inferno::TestSuite
    id :inferno_template_test_suite
    title 'Inferno Template Test Suite'
    description 'Inferno template test suite.'

    # These inputs will be available to all tests in this suite
    input :url,
          title: 'FHIR Server Base Url'

    input :credentials,
          title: 'OAuth Credentials',
          type: :oauth_credentials,
          optional: true

    # All FHIR validation requsets will use this FHIR validator
    fhir_resource_validator do
      igs 'hl7.fhir.us.core#3.1.1' # Use this method for published IGs/versions
      # igs 'igs/filename.tgz'   # Use this otherwise

      exclude_message do |message|
        message.message.match?(/\A\S+: \S+: URL value '.*' does not resolve/)
      end
    end

    group do
      id :auth
      title 'Auth'
      optional
      run_as_group

      output :access_token, :patient_id

      group from: :smart_discovery
      group from: :smart_standalone_launch
    end

    group do
      id :api
      title 'API'
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

        ['AllergyIntolerance',
        'CarePlan',
        'CareTeam',
        'Condition',
        'Device',
        'DiagnosticReport',
        'DocumentReference',
        'Encounter',
        'Goal',
        'Immunization',
        'MedicationRequest',
        'Observation',
        'Procedure'].each do |tested_resource|

          test do
            title "#{tested_resource} Search by Patient"

            run do
              fhir_search(tested_resource, params: { patient: patient_id })

              assert_response_status(200)
              assert_resource_type('Bundle')

              # skip_if is a shortcut to wrapping `skip` statement in an `if` block
              # it is a good idea to use the safe navigation operator `&.` to avoid runtime errors on nil
              skip_if resource.entry&.empty?, 'No entries in bundle response.'

              info "Bundle contains #{resource.entry&.count} resources."

              # There are not profiles for Observation, DocumentReference, or Device
              # in US Core v3.1.1
              pass_if ['Observation', 'DiagnosticReport', 'Device'].include?(tested_resource),
                "Note: no US Core Profile for #{tested_resource} resource type"

              assert_valid_bundle_entries(
                resource_types: {
                  "#{tested_resource}": "http://hl7.org/fhir/us/core/StructureDefinition/us-core-#{tested_resource.downcase}"
                }
              )
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'
require 'json'

module Bosh
  module Template
    module Test
      describe 'cloud_controller_ng job template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cloud_controller_worker') }

        let(:manifest_properties) do
          {
            'system_domain' => 'brook-sentry.capi.land',

            'cc' => {

              'db_logging_level' => 100,
              'staging_upload_user' => 'staging_user',
              'staging_upload_password' => 'hunter2',
              'database_encryption' => {
                'experimental_pbkdf2_hmac_iterations' => 123,
                'skip_validation' => false,
                'current_key_label' => 'encryption_key_0',
                :keys => { 'encryption_key_0' => '((cc_db_encryption_key))' }
              }
            },
            'ccdb' => {
              'db_scheme' => 'mysql',
              'max_connections' => 'foo2',
              'databases' => [{ 'tag' => 'cc' }],
              'roles' => [{
                'tag' => 'admin',
                'name' => 'alex',
                'password' => 'pass'
              }],
              'address' => 'foo5',
              'port' => 'foo7',
              'pool_timeout' => 'foo11',
              'ssl_verify_hostname' => 'foo12',
              'read_timeout' => 'foo13',
              'connection_validation_timeout' => 'foo14',
              'ca_cert' => 'foo15'
            }
          }
        end

        let(:properties) do
          {
            'router' => { 'route_services_secret' => '((router_route_services_secret))' },
            'cc' => {
              'system_hostnames' => '',
              'logging_max_retries' => 'bar1',
              'default_app_ssh_access' => 'something',
              'logging_level' => 'other thing',
              'log_db_queries' => 'balsdkj',
              'logging' => { 'format' => { 'timestamp' => 'rfc3339' } },
              'db_logging_level' => 'bar2',
              'db_encryption_key' => 'bar3',
              'volume_services_enabled' => true,
              'uaa' => {
                'client_timeout' => 10
              },
              'database_encryption' => {
                'experimental_pbkdf2_hmac_iterations' => 123,
                'skip_validation' => false,
                'current_key_label' => 'encryption_key_0',
                :keys => { 'encryption_key_0' => '((cc_db_encryption_key))' }
              },
              'max_labels_per_resource' => true,
              'max_annotations_per_resource' => 'yus',
              'disable_private_domain_cross_space_context_path_route_sharing' => false,
              'cpu_weight_min_memory' => 128,
              'cpu_weight_max_memory' => 8192,
              'custom_metric_tag_prefix_list' => ['heck.yes.example.com'],
              'jobs' => {
                'enable_dynamic_job_priorities' => false
              },
              'app_log_revision' => true
            }
          }
        end
        let(:cloud_controller_internal_link) do
          Link.new(name: 'cloud_controller_internal', properties:, instances: [LinkInstance.new(address: 'default_app_ssh_access')])
        end

        let(:cloud_controller_db_link) do
          properties = {
            'ccdb' => {
              'db_scheme' => 'mysql',
              'max_connections' => 'foo2',
              'databases' => [{ 'tag' => 'cc' }],
              'roles' => [{
                'tag' => 'admin',
                'name' => 'alex',
                'password' => 'pass'
              }],
              'address' => 'foo5',
              'port' => 'foo7',
              'pool_timeout' => 'foo11',
              'ssl_verify_hostname' => 'foo12',
              'read_timeout' => 'foo13',
              'connection_validation_timeout' => 'foo14',
              'ca_cert' => 'foo15'
            }
          }
          Link.new(name: 'database', properties:, instances: [LinkInstance.new(address: 'cloud_controller_db')])
        end

        let(:links) { [cloud_controller_internal_link, cloud_controller_db_link] }

        let(:template) { job.template('config/cloud_controller_ng.yml') }

        it 'creates the cloud_controller_ng.yml config file' do
          expect do
            YAML.safe_load(template.render(manifest_properties, consumes: links))
          end.not_to raise_error
        end

        describe 'router.route_services_secret' do
          context 'when router.route_services_secret is set to null' do
            before do
              properties['router']['route_services_secret'] = nil
            end

            it 'succeeds' do
              expect do
                YAML.safe_load(template.render(manifest_properties, consumes: links))
              end.not_to raise_error
            end
          end
        end

        describe 'database_encryption block' do
          context 'when the database_encryption block is not present' do
            before do
              manifest_properties['cc'].delete('database_encryption')
            end

            it 'does not raise an error' do
              expect do
                YAML.safe_load(template.render(manifest_properties, consumes: links))
              end.not_to raise_error
            end
          end

          context 'when the database_encryption.keys block is an array with secrets' do
            before do
              manifest_properties['cc']['database_encryption']['keys'] = [
                {
                  'encryption_key' => 'blah',
                  'label' => 'encryption_key_0',
                  'active' => false
                },
                {
                  'encryption_key' => 'other_key',
                  'label' => 'encryption_key_1',
                  'active' => true
                }
              ]
            end

            it 'converts the array into the expected format (hash)' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['database_encryption']['keys']).to eq({
                                                                           'encryption_key_0' => 'blah',
                                                                           'encryption_key_1' => 'other_key'
                                                                         })
              expect(template_hash['database_encryption']['current_key_label']).to eq('encryption_key_1')
            end
          end

          context 'when the database_encryption.keys block is a hash' do
            before do
              manifest_properties['cc']['database_encryption']['keys'] = {
                'encryption_key_0' => 'blah',
                'encryption_key_1' => 'other_key'
              }
            end

            it 'converts the array into the expected format (hash)' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['database_encryption']['keys']).to eq({
                                                                           'encryption_key_0' => 'blah',
                                                                           'encryption_key_1' => 'other_key'
                                                                         })
            end
          end

          context 'when db connection expiration configuration is present' do
            before do
              manifest_properties['ccdb']['connection_expiration_timeout'] = 3600
              manifest_properties['ccdb']['connection_expiration_random_delay'] = 60
            end

            it 'sets the db expiration properties' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['db']['connection_expiration_timeout']).to eq(3600)
              expect(template_hash['db']['connection_expiration_random_delay']).to eq(60)
            end
          end
        end

        describe 'broker_client_response_parser config' do
          context 'when nothing is configured' do
            it 'renders default values' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['broker_client_response_parser']['log_errors']).to be(false)
              expect(template_hash['broker_client_response_parser']['log_validators']).to be(false)
              expect(template_hash['broker_client_response_parser']['log_response_fields']).to eq({})
            end
          end

          context 'when config values are provided' do
            it 'renders the corresponding Cloud Controller Worker config' do
              manifest_properties['cc']['broker_client_response_parser'] = {
                'log_errors' => true,
                'log_validators' => true,
                'log_response_fields' => { 'a' => ['b'] }
              }
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['broker_client_response_parser']['log_errors']).to be(true)
              expect(template_hash['broker_client_response_parser']['log_validators']).to be(true)
              expect(template_hash['broker_client_response_parser']['log_response_fields']).to eq({ 'a' => ['b'] })
            end
          end
        end

        describe 'enable_dynamic_job_priorities' do
          context "when 'enable_dynamic_job_priorities' is set to false" do
            it 'renders false into ccng config' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['jobs']['enable_dynamic_job_priorities']).to be(false)
            end
          end

          context "when 'enable_dynamic_job_priorities' is set to true" do
            before do
              properties['cc']['jobs']['enable_dynamic_job_priorities'] = true
            end

            it 'renders true into ccng config' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['jobs']['enable_dynamic_job_priorities']).to be(true)
            end
          end
        end

        describe 'cc_jobs_number_of_worker_threads' do
          context "when 'cc.jobs.number_of_worker_threads' is set" do
            before { manifest_properties['cc']['jobs'] = { 'number_of_worker_threads' => 7 } }

            it 'renders the correct value into the ccng config' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['jobs']['number_of_worker_threads']).to eq(7)
            end
          end
        end

        describe 'cc_jobs_queues' do
          context 'when cc.jobs.queues is not set' do
            it 'does not render ccng config' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['jobs']['queues']).to eq({})
            end
          end
        end
      end
    end
  end
end

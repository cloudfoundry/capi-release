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
              },
              'directories' => {}
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
              'app_log_revision' => true,
              'temporary_enable_v2' => false,
              'packages' => {
                'max_valid_packages_stored' => 5
              },
              'default_app_lifecycle' => 'cnb'
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

        describe 'broker_client_max_async_poll_interval_seconds config' do
          it 'defaults to 86400 seconds' do
            template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
            expect(template_hash['broker_client_max_async_poll_interval_seconds']).to eq(86_400)
          end

          context 'when set in the manifest' do
            before do
              manifest_properties['cc']['broker_client_max_async_poll_interval_seconds'] = 3600
            end

            it 'renders the value from the manifest' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['broker_client_max_async_poll_interval_seconds']).to eq(3600)
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

        describe 'cc_jobs_queues' do
          context 'when cc.jobs.queues is not set' do
            it 'does not render ccng config' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['jobs']['queues']).to eq({})
            end
          end
        end

        describe 'cc.jobs.read_ahead' do
          context 'when cc.jobs.read_ahead is set to 5' do
            it 'renders read_ahead into ccng config' do
              manifest_properties['cc']['jobs'] = { 'read_ahead' => 5 }
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['jobs']['read_ahead']).to be(5)
            end
          end
        end

        describe 'enable v2 API' do
          it 'is by default true' do
            template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
            expect(template_hash['temporary_enable_v2']).to be(false)
          end
        end

        describe 'max valid packages stored' do
          it 'is set from cloud_controller_internal_link' do
            template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
            expect(template_hash['packages']['max_valid_packages_stored']).to be(5)
          end
        end

        describe 'metrics' do
          context 'when cc.publish_metrics not set' do
            it 'is set to false' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['publish_metrics']).to be(false)
            end
          end

          context 'when cc.publish_metrics set to true' do
            before do
              manifest_properties['cc']['publish_metrics'] = true
            end

            it 'is set to true' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['publish_metrics']).to be(true)
            end
          end

          context 'when cc.prometheus_port not set' do
            it 'uses default' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['prometheus_port']).to eq(9394)
            end
          end

          context 'when cc.prometheus_port is set' do
            before do
              manifest_properties['cc']['prometheus_port'] = 9397
            end

            it 'uses the default' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['prometheus_port']).to eq(9397)
            end
          end
        end

        describe 'cc.directories.tmpdir' do
          it 'uses the default' do
            template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
            expect(template_hash['directories']['tmpdir']).to eq('/var/vcap/data/cloud_controller_worker/tmp')
          end

          context 'when set' do
            before do
              manifest_properties['cc']['directories']['tmpdir'] = '/some/tmp'
            end

            it 'renders accordingly' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['directories']['tmpdir']).to eq('/some/tmp')
            end
          end
        end

        describe 'default_app_lifecycle' do
          it 'is set from cloud_controller_internal_link' do
            template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
            expect(template_hash['default_app_lifecycle']).to eq('cnb')
          end
        end
      end
    end
  end
end

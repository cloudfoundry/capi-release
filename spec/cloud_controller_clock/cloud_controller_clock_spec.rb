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
        let(:job) { release.job('cloud_controller_clock') }

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
              'statsd_host' => '127.0.0.1',
              'statsd_port' => 8125,
              'max_labels_per_resource' => true,
              'max_annotations_per_resource' => 'yus',
              'disable_private_domain_cross_space_context_path_route_sharing' => false,
              'cpu_weight_min_memory' => 128,
              'cpu_weight_max_memory' => 8192,
              'custom_metric_tag_prefix_list' => ['heck.yes.example.com'],
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

        describe 'max_number_of_failed_delayed_jobs' do
          context "when 'cc.failed_jobs.max_number_of_failed_delayed_jobs' is set" do
            it 'renders max_number_of_failed_delayed_jobs into the ccng config' do
              manifest_properties['cc'].store('failed_jobs', { 'max_number_of_failed_delayed_jobs' => 1000 })
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['failed_jobs']['max_number_of_failed_delayed_jobs']).to eq(1000)
            end
          end

          context "when 'cc.failed_jobs.max_number_of_failed_delayed_jobs' is not set (default)" do
            it 'does not render max_number_of_failed_delayed_jobs into the ccng config' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['failed_jobs']).not_to have_key(:max_number_of_failed_delayed_jobs)
            end
          end
        end

        describe 'statsd' do
          it 'renders statsd_host and statsd_port from cloud_controller_internal link' do
            template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
            expect(template_hash['statsd_host']).to eq(properties['cc']['statsd_host'])
            expect(template_hash['statsd_port']).to eq(properties['cc']['statsd_port'])
          end
        end
      end
    end
  end
end

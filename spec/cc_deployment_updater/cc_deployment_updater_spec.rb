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
        let(:job) { release.job('cc_deployment_updater') }

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

        let(:webdav_config) do
          { 'blobstore_timeout' => 5,
            'ca_cert' => '((service_cf_internal_ca.certificate))',
            'password' => '((blobstore_admin_users_password))',
            'private_endpoint' => 'https://blobstore.service.cf.internal:4443',
            'public_endpoint' => 'https://blobstore.brook-sentry.capi.land',
            'username' => 'blobstore-user' }
        end

        let(:properties) do
          {
            'router' => { 'route_services_secret' => '((router_route_services_secret))' },
            'system_domain' => 'system',
            'ssl' => {
              'skip_cert_verify' => false
            },
            'routing_api' => { 'enabled' => false },
            'cc' => {
              'external_port' => 9022,
              'tls_port' => 9023,
              'internal_service_hostname' => 'cloud-controller-ng.service.cf.internal',
              'external_protocol' => 'https',
              'external_host' => 'api',
              'staging_timeout_in_seconds' => 900,
              'staging_upload_user' => 'staging_user',
              'staging_upload_password' => 'staging_user_password',
              'default_health_check_timeout' => 60,
              'maximum_health_check_timeout' => 180,
              'resource_pool' => {
                'minimum_size' => 65_536,
                'maximum_size' => 536_870_912,
                'resource_directory_key' => 'cc-resources',
                'blobstore_type' => 'webdav',
                'webdav_config' => webdav_config
              },
              'packages' => {
                'min_package_size' => 65_536,
                'max_package_size' => 536_870_912,
                'app_package_directory_key' => 'cc-packages',
                'blobstore_type' => 'webdav',
                'webdav_config' => webdav_config
              },
              'droplets' => {
                'droplet_directory_key' => 'cc-droplets',
                'blobstore_type' => 'webdav',
                'webdav_config' => webdav_config
              },
              'buildpacks' => {
                'buildpack_directory_key' => 'cc-buildpacks',
                'blobstore_type' => 'webdav',
                'webdav_config' => webdav_config

              },
              'credential_references' => {
                'interpolate_service_bindings' => true
              },
              'system_hostnames' => '',
              'logging_max_retries' => 'bar1',
              'default_app_ssh_access' => 'something',
              'logging_level' => 'other thing',
              'logging' => { 'format' => { 'timestamp' => 'rfc3339' } },
              'db_logging_level' => 'bar2',
              'db_encryption_key' => 'bar3',
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
              'cpu_weight_min_memory' => 128,
              'cpu_weight_max_memory' => 8192,
              'custom_metric_tag_prefix_list' => ['heck.yes.example.com'],
              'app_log_revision' => true,
              'storage_cli_optional_flags' => ''
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

        describe 'statsd' do
          it 'renders statsd_host and statsd_port from cloud_controller_internal link' do
            template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
            expect(template_hash['statsd_host']).to eq(properties['cc']['statsd_host'])
            expect(template_hash['statsd_port']).to eq(properties['cc']['statsd_port'])
          end
        end

        describe 'metrics' do
          context 'when cc.publish_metrics not set' do
            it 'is set to false (default)' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['publish_metrics']).to be(false)
            end
          end

          context 'when cc.publish_metrics set to true' do
            before { manifest_properties['cc']['publish_metrics'] = true }

            it 'is set to true' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['publish_metrics']).to be(true)
            end
          end

          context 'when cc.prometheus_port not set' do
            it 'uses default' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['prometheus_port']).to eq(9395)
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
      end
    end
  end
end

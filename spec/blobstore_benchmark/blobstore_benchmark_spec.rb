# rubocop:disable Metrics/BlockLength
# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'

module Bosh
  module Template
    module Test
      describe 'blobstore_benchmark job template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('blobstore_benchmark') }

        let(:cloud_controller_internal_properties) do
          {
            'cc' => {
              'logging_level' => 'info',
              'logging_max_retries' => 0,
              'logging' => { 'format' => { 'timestamp' => 'rfc3339' } },

              'resource_pool' => {
                'blobstore_provider' => 'AzureRM',
                'blobstore_type' => 'storage-cli',
                'connection_config' => {
                  'azure_storage_account_name' => 'acct',
                  'azure_storage_access_key' => 'key',
                  'container_name' => 'resource-pool',
                  'environment' => 'AzureCloud'
                }
              },
              'buildpacks' => {
                'blobstore_provider' => 'AzureRM',
                'blobstore_type' => 'storage-cli',
                'connection_config' => {
                  'azure_storage_account_name' => 'acct',
                  'azure_storage_access_key' => 'key',
                  'container_name' => 'buildpacks',
                  'environment' => 'AzureCloud'
                }
              },
              'packages' => {
                'blobstore_provider' => 'AzureRM',
                'blobstore_type' => 'storage-cli',
                'connection_config' => {
                  'azure_storage_account_name' => 'acct',
                  'azure_storage_access_key' => 'key',
                  'container_name' => 'packages',
                  'environment' => 'AzureCloud'
                }
              },
              'droplets' => {
                'blobstore_provider' => 'AzureRM',
                'blobstore_type' => 'storage-cli',
                'connection_config' => {
                  'azure_storage_account_name' => 'acct',
                  'azure_storage_access_key' => 'key',
                  'container_name' => 'droplets',
                  'environment' => 'AzureCloud'
                }
              },

              'db_logging_level' => 'error',
              'log_db_queries' => false
            }
          }
        end

        let(:cloud_controller_internal_link) do
          Link.new(
            name: 'cloud_controller_internal',
            properties: cloud_controller_internal_properties,
            instances: [LinkInstance.new(address: 'cc-internal')]
          )
        end

        let(:cloud_controller_db_properties) do
          {
            'ccdb' => {
              'db_scheme' => 'postgres',
              'max_connections' => 100,
              'databases' => [{ 'tag' => 'cc', 'name' => 'ccdb' }],
              'roles' => [{
                'tag' => 'admin',
                'name' => 'ccadmin',
                'password' => 'p@ss:word'
              }],
              'address' => '10.0.0.5',
              'port' => 5432,
              'pool_timeout' => 5,
              'ssl_verify_hostname' => true,
              'read_timeout' => 60,
              'connection_validation_timeout' => 3600,
              'ca_cert' => '---CERT---'
            }
          }
        end

        let(:cloud_controller_db_link) do
          Link.new(
            name: 'cloud_controller_db',
            properties: cloud_controller_db_properties,
            instances: [LinkInstance.new(address: 'ccdb')]
          )
        end

        let(:database_link) do
          Link.new(
            name: 'database',
            properties: {},
            instances: [LinkInstance.new(address: '10.0.0.6')]
          )
        end

        let(:links) { [cloud_controller_internal_link, cloud_controller_db_link, database_link] }

        describe 'config/cloud_controller_ng.yml' do
          let(:template) { job.template('config/cloud_controller_ng.yml') }

          let(:manifest_properties) do
            {
              'cc' => {
                # currently NOT used by template unless you wire it up
                'stdout_logging_enabled' => false,
                'logging_level' => 'error',
                'log_db_queries' => false,
                'db_logging_level' => 'error'
              },
              'ccdb' => {
                'max_connections' => 50
              }
            }
          end

          it 'renders valid YAML without unsafe classes' do
            expect do
              YAML.safe_load(template.render(manifest_properties, consumes: links))
            end.not_to raise_error
          end

          it 'sets logging.stdout_sink_enabled to false (template-owned key is not overwritten by cc link)' do
            rendered = YAML.safe_load(template.render(manifest_properties, consumes: links))
            expect(rendered.dig('logging', 'stdout_sink_enabled')).to be(false)
          end

          it 'keeps cc link logging.format.timestamp while preserving template logging keys' do
            rendered = YAML.safe_load(template.render(manifest_properties, consumes: links))
            expect(rendered.dig('logging', 'format', 'timestamp')).to eq('rfc3339')
            expect(rendered.dig('logging', 'stdout_sink_enabled')).to be(false)
          end

          it 'renders a db block from the cloud_controller_db link' do
            rendered = YAML.safe_load(template.render(manifest_properties, consumes: links))

            expect(rendered).to have_key('db')
            expect(rendered.dig('db', 'database', 'host')).to eq('10.0.0.5')
            expect(rendered.dig('db', 'database', 'port')).to eq(5432)
            expect(rendered.dig('db', 'database', 'user')).to eq('ccadmin')
            expect(rendered.dig('db', 'database', 'password')).not_to be_nil
          end

          it 'writes storage-cli config file paths so the client does not read nil' do
            rendered = YAML.safe_load(template.render(manifest_properties, consumes: links))

            expect(rendered['storage_cli_config_file_resource_pool']).to eq('/var/vcap/jobs/blobstore_benchmark/config/storage_cli_config_resource_pool.json')
            expect(rendered['storage_cli_config_file_buildpacks']).to eq('/var/vcap/jobs/blobstore_benchmark/config/storage_cli_config_buildpacks.json')
            expect(rendered['storage_cli_config_file_packages']).to eq('/var/vcap/jobs/blobstore_benchmark/config/storage_cli_config_packages.json')
            expect(rendered['storage_cli_config_file_droplets']).to eq('/var/vcap/jobs/blobstore_benchmark/config/storage_cli_config_droplets.json')
          end

          it 'includes blobstore sections at root (resource_pool/buildpacks/packages/droplets) from cc link' do
            rendered = YAML.safe_load(template.render(manifest_properties, consumes: links))

            %w[resource_pool buildpacks packages droplets].each do |k|
              expect(rendered).to have_key(k)
              expect(rendered[k]).to be_a(Hash)
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
# rubocop:enable Metrics/ModuleLength

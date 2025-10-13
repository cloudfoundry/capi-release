# frozen_string_literal: true

require 'rspec'
require 'yaml'
require 'bosh/template/test'

TEMPLATES = {
  droplets: ['config/storage_cli_config_droplets.json', %w[cc droplets connection_config]],
  buildpacks: ['config/storage_cli_config_buildpacks.json', %w[cc buildpacks connection_config]],
  packages: ['config/storage_cli_config_packages.json', %w[cc packages connection_config]],
  resource_pool: ['config/storage_cli_config_resource_pool.json', %w[cc resource_pool connection_config]]
}.freeze

module Bosh
  module Template
    module Test
      RSpec.describe 'storage-cli JSON templates' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cloud_controller_ng') }
        let(:links) { {} }
        let(:props) do
          {
            'cc' => {
              'droplets' => { 'connection_config' => {}, 'blobstore_provider' => 'AzureRM' },
              'buildpacks' => { 'connection_config' => {}, 'blobstore_provider' => 'AzureRM' },
              'packages' => { 'connection_config' => {}, 'blobstore_provider' => 'AzureRM' },
              'resource_pool' => { 'connection_config' => {}, 'blobstore_provider' => 'AzureRM' }
            }
          }
        end

        TEMPLATES.each_value do |(template_path, keypath)|
          describe template_path do
            let(:template) { job.template(template_path) }

            def set(hash, path, value)
              cursor = hash
              path[0..-2].each { |key| cursor = (cursor[key] ||= {}) }
              cursor[path.last] = value
            end

            it 'renders and normalizes put_timeout_in_seconds to "41" when blank' do
              set(props, keypath, {
                    'provider' => 'AzureRM',
                    'azure_storage_account_name' => 'acc',
                    'azure_storage_access_key' => 'key',
                    'container_name' => 'cont',
                    'put_timeout_in_seconds' => ''
                  })

              json = YAML.safe_load(template.render(props, consumes: links))
              expect(json).to include(
                'provider' => 'AzureRM',
                'account_name' => 'acc',
                'account_key' => 'key',
                'container_name' => 'cont',
                'put_timeout_in_seconds' => '41'
              )
            end

            it 'keeps existing put_timeout_in_seconds when provided' do
              set(props, keypath, {
                    'provider' => 'AzureRM',
                    'azure_storage_account_name' => 'acc',
                    'azure_storage_access_key' => 'key',
                    'container_name' => 'cont',
                    'put_timeout_in_seconds' => '7'
                  })

              json = YAML.safe_load(template.render(props, consumes: links))
              expect(json['put_timeout_in_seconds']).to eq('7')
            end

            it 'renders {} for non-Azure providers' do
              keypath[0..-2].reduce(props) { |acc, elem| acc[elem] ||= {} }['blobstore_provider'] = 'S3'

              json = YAML.safe_load(template.render(props, consumes: links))
              expect(json).to eq({})
            end
          end
        end
      end
    end
  end
end

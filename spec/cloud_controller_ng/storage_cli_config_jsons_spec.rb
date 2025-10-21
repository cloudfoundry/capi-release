# frozen_string_literal: true

require 'rspec'
require 'yaml'
require 'bosh/template/test'

TEMPLATES = {
  droplets: ['config/blobstore_configs.json', %w[cc droplets connection_config]],
  buildpacks: ['config/blobstore_configs.json', %w[cc buildpacks connection_config]],
  packages: ['config/blobstore_configs.json', %w[cc packages connection_config]],
  resource_pool: ['config/blobstore_configs.json', %w[cc resource_pool connection_config]]
}.freeze

module Bosh
  module Template
    module Test
      RSpec.describe 'storage-cli JSON templates' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release)      { ReleaseDir.new(release_path) }
        let(:job)          { release.job('cloud_controller_ng') }
        let(:links)        { {} }

        # Default all scopes to non-Azure so only the scope under test must be populated
        let(:props) do
          {
            'cc' => {
              'droplets' => { 'connection_config' => {}, 'blobstore_provider' => 'S3' },
              'buildpacks' => { 'connection_config' => {}, 'blobstore_provider' => 'S3' },
              'packages' => { 'connection_config' => {}, 'blobstore_provider' => 'S3' },
              'resource_pool' => { 'connection_config' => {}, 'blobstore_provider' => 'S3' }
            }
          }
        end

        TEMPLATES.each do |scope, (template_path, keypath)|
          describe template_path do
            let(:template) { job.template(template_path) }

            def set(hash, path, value)
              cursor = hash
              path[0..-2].each { |key| cursor = (cursor[key] ||= {}) }
              cursor[path.last] = value
            end

            context "when provider is AzureRM for #{scope}" do
              before do
                props['cc'][scope.to_s]['blobstore_provider'] = 'AzureRM'
              end

              it 'renders and normalizes put_timeout_in_seconds to "41" when blank' do
                set(props, keypath, {
                      'provider' => 'AzureRM',
                      'azure_storage_account_name' => 'acc',
                      'azure_storage_access_key' => 'key',
                      'container_name' => 'cont',
                      'put_timeout_in_seconds' => ''
                    })

                full = YAML.safe_load(template.render(props, consumes: links))
                json = full.fetch(scope.to_s)
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

                full = YAML.safe_load(template.render(props, consumes: links))
                json = full.fetch(scope.to_s)
                expect(json['put_timeout_in_seconds']).to eq('7')
              end
            end

            context "when provider is non-Azure for #{scope}" do
              it 'renders {}' do
                # leave default 'S3' for this scope
                full = YAML.safe_load(template.render(props, consumes: links))
                json = full.fetch(scope.to_s)
                expect(json).to eq({})
              end
            end
          end
        end
      end
    end
  end
end

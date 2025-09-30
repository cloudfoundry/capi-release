# spec/templates/storage_cli_config_jsons_spec.rb
require 'rspec'
require 'json'
require 'bosh/template/test'

module Bosh::Template::Test
  RSpec.describe 'storage-cli JSON templates' do
    let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
    let(:release) { ReleaseDir.new(release_path) }
    let(:job) { release.job('cloud_controller_ng') }
    let(:links) { {} }
    let(:props) do
      {
        'cc' => {
          'droplets'     => { 'connection_config' => {} },
          'buildpacks'   => { 'connection_config' => {} },
          'packages'     => { 'connection_config' => {} },
          'resource_pool'=> { 'connection_config' => {} },
        }
      }
    end

    TEMPLATES = {
      droplets:      ['config/storage_cli_config_droplets.json',      %w[cc droplets connection_config]],
      buildpacks:    ['config/storage_cli_config_buildpacks.json',    %w[cc buildpacks connection_config]],
      packages:      ['config/storage_cli_config_packages.json',      %w[cc packages connection_config]],
      resource_pool: ['config/storage_cli_config_resource_pool.json', %w[cc resource_pool connection_config]],
    }.freeze

    TEMPLATES.each do |scope, (template_path, keypath)|
      describe template_path do
        let(:template) { job.template(template_path) }

        def set(props, keypath, value)
          h = props
          keypath[0..-2].each { |k| h = (h[k] ||= {}) }
          h[keypath.last] = value
        end

        it 'renders and normalizes put_timeout_in_seconds to "41" when blank' do
          set(props, keypath, {
            'provider' => 'AzureRM',
            'azure_storage_account_name' => 'acc',
            'azure_storage_access_key'   => 'key',
            'container_name'             => 'cont',
            'put_timeout_in_seconds'     => ''
          })

          json = JSON.parse(template.render(props, consumes: links))
          expect(json).to include(
                            'provider'               => 'AzureRM',
                            'account_name'           => 'acc',
                            'account_key'            => 'key',
                            'container_name'         => 'cont',
                            'put_timeout_in_seconds' => '41'
                          )
        end

        it 'keeps existing put_timeout_in_seconds when provided' do
          set(props, keypath, {
            'provider' => 'AzureRM',
            'azure_storage_account_name' => 'acc',
            'azure_storage_access_key'   => 'key',
            'container_name'             => 'cont',
            'put_timeout_in_seconds'     => '7'
          })

          json = JSON.parse(template.render(props, consumes: links))
          expect(json['put_timeout_in_seconds']).to eq('7')
        end

        it 'renders {} for non-Azure providers' do
          set(props, keypath, { 'provider' => 'S3' })
          json = JSON.parse(template.render(props, consumes: links))
          expect(json).to eq({})
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'rspec'
require 'yaml' # frozen_string_literal: true

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

        def set(hash, path, value)
          cursor = hash
          path[0..-2].each { |key| cursor = (cursor[key] ||= {}) }
          cursor[path.last] = value
        end

        def props_for_provider(provider)
          {
            'cc' => {
              'droplets' => { 'connection_config' => {}, 'blobstore_provider' => provider },
              'buildpacks' => { 'connection_config' => {}, 'blobstore_provider' => provider },
              'packages' => { 'connection_config' => {}, 'blobstore_provider' => provider },
              'resource_pool' => { 'connection_config' => {}, 'blobstore_provider' => provider }
            }
          }
        end

        describe 'Unsupported provider' do
          let(:props) { props_for_provider('Unsupported') }

          TEMPLATES.each_value do |(template_path, _keypath)|
            describe template_path do
              let(:template) { job.template(template_path) }

              it 'renders empty JSON for unsupported provider' do
                json = YAML.safe_load(template.render(props, consumes: links))
                expect(json).to eq({})
              end
            end
          end
        end

        describe 'When Provider AzureRM' do
          let(:props) { props_for_provider('AzureRM') }

          TEMPLATES.each_value do |(template_path, keypath)|
            describe template_path do
              let(:template) { job.template(template_path) }

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
            end
          end
        end

        describe 'When Provider AWS' do
          let(:props) { props_for_provider('AWS') }

          TEMPLATES.each_value do |(template_path, keypath)|
            describe template_path do
              let(:template) { job.template(template_path) }

              it 'renders with valid config' do
                set(props, keypath, {
                      'provider' => 'AWS',
                      'bucket_name' => 'bucket',
                      'aws_access_key_id' => 'key',
                      'aws_secret_access_key' => 'secret',
                      'region' => 'us-east1'
                    })
                json = YAML.safe_load(template.render(props, consumes: links))
                expect(json).to include(
                  'provider' => 'AWS',
                  'bucket_name' => 'bucket',
                  'access_key_id' => 'key',
                  'credentials_source' => 'static',
                  'secret_access_key' => 'secret',
                  'region' => 'us-east1'
                )
              end

              it 'renders with optionals' do
                set(props, keypath, {
                      'provider' => 'AWS',
                      'bucket_name' => 'bucket',
                      'aws_access_key_id' => 'key',
                      'aws_secret_access_key' => 'secret',
                      'region' => 'us-east1',
                      'host' => 'localhost',
                      'ssl_verify_peer' => 'verfiy',
                      'use_ssl' => 'true',
                      'singnature_version' => 'v4',
                      'encryption' => 'some-encryption',
                      'x-amz-server-side-encryption-aws-kms-key-id' => 'id',
                      'multipart_upload' => 'true'
                    })

                json = YAML.safe_load(template.render(props, consumes: links))
                expect(json).to include(
                  'provider' => 'AWS',
                  'bucket_name' => 'bucket',
                  'access_key_id' => 'key',
                  'secret_access_key' => 'secret',
                  'region' => 'us-east1',
                  'host' => 'localhost',
                  'ssl_verify_peer' => 'verfiy',
                  'use_ssl' => 'true',
                  'singnature_version' => 'v4',
                  'server_side_encryption' => 'some-encryption',
                  'sse_kms_key_id' => 'id',
                  'multipart_upload' => 'true'
                )
              end
            end
          end
        end

        describe 'When Provider Google' do
          let(:props) { props_for_provider('Google') }

          TEMPLATES.each_value do |(template_path, keypath)|
            describe template_path do
              let(:template) { job.template(template_path) }

              it 'renders with valid config' do
                set(props, keypath, {
                      'provider' => 'Google',
                      'bucket_name' => 'bucket',
                      'google_json_key_string' => '{}'
                    })
                json = YAML.safe_load(template.render(props, consumes: links))
                expect(json).to include(
                  'provider' => 'Google',
                  'bucket_name' => 'bucket',
                  'json_key' => '{}',
                  'credentials_source' => 'static'
                )
              end

              it 'renders with optionals' do
                set(props, keypath, {
                      'provider' => 'Google',
                      'bucket_name' => 'bucket',
                      'google_json_key_string' => '{}',
                      'storage_class' => 'STANDARD',
                      'encryption_key' => 'key'

                    })

                json = YAML.safe_load(template.render(props, consumes: links))
                expect(json).to include(
                  'provider' => 'Google',
                  'bucket_name' => 'bucket',
                  'json_key' => '{}',
                  'credentials_source' => 'static',
                  'storage_class' => 'STANDARD',
                  'encryption_key' => 'key'
                )
              end
            end
          end
        end

        describe 'When Provider aliyun' do
          let(:props) { props_for_provider('aliyun') }

          TEMPLATES.each_value do |(template_path, keypath)|
            describe template_path do
              let(:template) { job.template(template_path) }

              it 'renders with valid config' do
                set(props, keypath, {
                      'provider' => 'aliyun',
                      'aliyun_accesskey_id' => 'key',
                      'aliyun_accesskey_secret' => 'secret',
                      'aliyun_oss_endpoint' => 'aliyun.com',
                      'aliyun_oss_bucket' => 'bucket'
                    })
                json = YAML.safe_load(template.render(props, consumes: links))
                expect(json).to include(
                  'provider' => 'aliyun',
                  'access_key_id' => 'key',
                  'access_key_secret' => 'secret',
                  'endpoint' => 'aliyun.com',
                  'bucket_name' => 'bucket'
                )
              end
            end
          end
        end

        describe 'When Provider webdav' do
          let(:props) { props_for_provider('webdav') }

          TEMPLATES.each_value do |(template_path, keypath)|
            describe template_path do
              let(:template) { job.template(template_path) }

              it 'renders with valid config' do
                set(props, keypath, {
                      'provider' => 'webdav',
                      'username' => 'user',
                      'password' => 'secret',
                      'public_endpoint' => 'webdav.com',
                      'ca_cert' => 'some_cert'
                    })
                json = YAML.safe_load(template.render(props, consumes: links))
                expect(json).to include(
                  'provider' => 'webdav',
                  'user' => 'user',
                  'password' => 'secret',
                  'endpoint' => 'webdav.com',
                  'tls' => { 'cert' => 'some_cert' }
                )
              end

              it 'renders with optionals' do
                set(props, keypath, {
                      'provider' => 'webdav',
                      'username' => 'user',
                      'password' => 'secret',
                      'public_endpoint' => 'webdav.com',
                      'ca_cert' => 'some_cert',
                      'secret' => 'secret',
                      'retry_attempts' => '4'
                    })
                json = YAML.safe_load(template.render(props, consumes: links))
                expect(json).to include(
                  'provider' => 'webdav',
                  'user' => 'user',
                  'password' => 'secret',
                  'endpoint' => 'webdav.com',
                  'tls' => { 'cert' => 'some_cert' },
                  'secret' => 'secret',
                  'retry_attempts' => '4'
                )
              end
            end
          end
        end
      end
    end
  end
end

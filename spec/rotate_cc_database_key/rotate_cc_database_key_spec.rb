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
        let(:job) { release.job('rotate_cc_database_key') }

        let(:manifest_properties) do
          {
            'cc' => {
              'db_logging_level' => 100
            },
            'ccdb' => {
              'max_connections' => 100
            }
          }
        end

        let(:properties) do
          {
            'cc' => {
              'logging_max_retries' => 'bar1',
              'default_app_ssh_access' => 'something',
              'logging_level' => 'other thing',
              'log_db_queries' => 'balsdkj',
              'logging' => { 'format' => { 'timestamp' => 'rfc3339' } },
              'db_logging_level' => 'bar2',
              'db_encryption_key' => 'bar3',
              'database_encryption' => {
                'experimental_pbkdf2_hmac_iterations' => 123,
                'skip_validation' => false,
                'current_key_label' => 'encryption_key_0',
                'keys' => { 'encryption_key_0' => '((cc_db_encryption_key))' }
              }
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
          Link.new(name: 'cloud_controller_db', properties:, instances: [LinkInstance.new(address: 'cloud_controller_db')])
        end

        let(:links) { [cloud_controller_internal_link, cloud_controller_db_link] }

        describe 'config/cloud_controller_ng.yml' do
          let(:template) { job.template('config/cloud_controller_ng.yml') }

          it 'creates the cloud_controller_ng.yml config file' do
            expect do
              YAML.safe_load(template.render(manifest_properties, consumes: links))
            end.not_to raise_error
          end

          describe 'logging configuration' do
            it 'sets `stdout_sink_enabled` to default `true`' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['logging']['stdout_sink_enabled']).to be_truthy
            end

            context 'when `stdout_logging_enabled` is set to `false`' do
              before do
                manifest_properties['cc']['stdout_logging_enabled'] = false
              end

              it 'sets `stdout_sink_enabled` to `false`' do
                template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
                expect(template_hash['logging']['stdout_sink_enabled']).to be_falsey
              end
            end
          end

          describe 'database_encryption block' do
            context 'when the database_encryption block is not present' do
              before do
                properties['cc'].delete('database_encryption')
              end

              it 'does not raise an error' do
                expect do
                  YAML.safe_load(template.render(manifest_properties, consumes: links))
                end.not_to raise_error
              end
            end

            context 'when the "current_encryption_key_label" is not found in the "keys" map' do
              before do
                properties['cc']['database_encryption']['current_key_label'] = 'encryption_key_label_not_here_anymore'
              end

              context 'when the skip validation property is false' do
                it 'raises an error' do
                  expect do
                    YAML.safe_load(template.render(manifest_properties, consumes: links))
                  end.to raise_error(
                    StandardError,
                    "Error for database_encryption: 'current_key_label' set to 'encryption_key_label_not_here_anymore', but not present in 'keys' map."
                  )
                end
              end

              context 'when the skip validation property is true' do
                before do
                  properties['cc']['database_encryption']['skip_validation'] = true
                end

                it 'does not raise an error' do
                  expect do
                    YAML.safe_load(template.render(manifest_properties, consumes: links))
                  end.not_to raise_error
                end
              end
            end

            context 'when the database_encryption.keys block is an array with secrets' do
              before do
                properties['cc']['database_encryption']['keys'] = [
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
                properties['cc']['database_encryption']['keys'] = {
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
          end

          describe 'max_connections from cloud_controller_db' do
            it 'overrides max_connections when value is set' do
              template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
              expect(template_hash['db']['max_connections']).to eq(100)
            end

            context 'when max_connections is not overriden' do
              before do
                manifest_properties['ccdb'].delete('max_connections')
              end

              it 'sets the default value' do
                template_hash = YAML.safe_load(template.render(manifest_properties, consumes: links))
                expect(template_hash['db']['max_connections']).to eq('foo2')
              end
            end
          end
        end

        describe 'bin/run' do
          let(:template) { job.template('bin/run') }

          def disables_peer_verification?(db_scheme:, ca_cert:)
            ccdb = {
              'db_scheme' => db_scheme,
              'databases' => [{ 'tag' => 'cc', 'name' => 'ccdb' }],
              'roles' => [{ 'tag' => 'admin', 'name' => 'u', 'password' => 'p' }],
              'port' => 3306
            }
            ccdb['ca_cert'] = ca_cert unless ca_cert.nil?
            db_link = Link.new(name: 'cloud_controller_db', properties: { 'ccdb' => ccdb },
                               instances: [LinkInstance.new(address: 'cloud_controller_db')])
            rendered = template.render({}, consumes: [cloud_controller_internal_link, db_link])
            rendered.include?('export MARIADB_TLS_DISABLE_PEER_VERIFICATION="1"')
          end

          context 'when the database is mysql and no ca_cert is configured' do
            it 'disables peer verification' do
              expect(disables_peer_verification?(db_scheme: 'mysql', ca_cert: nil)).to be(true)
            end
          end

          context 'when the database is mysql and a ca_cert is configured' do
            it 'does not disable peer verification' do
              expect(disables_peer_verification?(db_scheme: 'mysql', ca_cert: 'a-ca-cert')).to be(false)
            end
          end

          context 'when the database is postgres' do
            it 'does not disable peer verification' do
              expect(disables_peer_verification?(db_scheme: 'postgres', ca_cert: nil)).to be(false)
            end
          end
        end
      end
    end
  end
end

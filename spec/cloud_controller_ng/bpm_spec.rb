# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'
require 'json'

module Bosh
  module Template
    module Test
      describe 'bpm job template rendering' do
        def expect_default_debug_env_vars(env_vars)
          expect(env_vars).to have_key('DEBUG')
          expect(env_vars['DEBUG']).to be(true)
        end

        def valkey_volume_mounted?(process)
          return false unless process.key?('additional_volumes')

          results = process['additional_volumes'].select { |v| v['path'] == '/var/vcap/data/valkey' }
          return false unless results.length == 1

          valkey_volume = results[0]
          return false unless valkey_volume.key?('mount_only')

          mount_only = valkey_volume['mount_only']
          return false unless mount_only.is_a?(TrueClass) && mount_only == true

          true
        end

        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cloud_controller_ng') }

        describe 'config/bpm.yml' do
          let(:template) { job.template('config/bpm.yml') }

          describe 'valkey config' do
            it 'mounts the valkey volume into the ccng job container' do
              template_hash = YAML.safe_load(template.render({}, consumes: {}))

              results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
              expect(results.length).to eq(1)
              expect(valkey_volume_mounted?(results[0])).to be_truthy
            end
          end

          describe 'MySQL TLS peer verification' do
            def db_process_envs(properties)
              template_hash = YAML.safe_load(template.render(properties, consumes: {}))
              db_process_names = %w[cloud_controller_ng local_worker_1]
              template_hash['processes'].
                select { |p| db_process_names.include?(p['name']) }.
                to_h { |p| [p['name'], p['env']] }
            end

            context 'when the database is mysql and no ca_cert is configured' do
              let(:properties) { { 'ccdb' => { 'db_scheme' => 'mysql' } } }

              it 'disables peer verification on every db process' do
                envs = db_process_envs(properties)
                expect(envs.keys).to contain_exactly('cloud_controller_ng', 'local_worker_1')
                envs.each_value do |env|
                  expect(env['MARIADB_TLS_DISABLE_PEER_VERIFICATION']).to eq('1')
                end
              end
            end

            context 'when the database is mysql and a ca_cert is configured' do
              let(:properties) { { 'ccdb' => { 'db_scheme' => 'mysql', 'ca_cert' => 'a-ca-cert' } } }

              it 'does not disable peer verification on any db process' do
                envs = db_process_envs(properties)
                expect(envs.keys).to contain_exactly('cloud_controller_ng', 'local_worker_1')
                envs.each_value do |env|
                  expect(env).not_to have_key('MARIADB_TLS_DISABLE_PEER_VERIFICATION')
                end
              end
            end

            context 'when the database is postgres' do
              let(:properties) { { 'ccdb' => { 'db_scheme' => 'postgres' } } }

              it 'does not disable peer verification on any db process' do
                envs = db_process_envs(properties)
                expect(envs.keys).to contain_exactly('cloud_controller_ng', 'local_worker_1')
                envs.each_value do |env|
                  expect(env).not_to have_key('MARIADB_TLS_DISABLE_PEER_VERIFICATION')
                end
              end
            end
          end
        end
      end
    end
  end
end

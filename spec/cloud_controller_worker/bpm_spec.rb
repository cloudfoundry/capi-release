# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'

module Bosh
  module Template
    module Test
      describe 'cloud_controller_worker bpm job template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cloud_controller_worker') }

        describe 'config/bpm.yml' do
          let(:template) { job.template('config/bpm.yml') }

          describe 'MySQL TLS peer verification' do
            def worker_env(properties)
              template_hash = YAML.safe_load(template.render(properties, consumes: {}))
              worker = template_hash['processes'].find { |p| p['name'] == 'worker_1' }
              expect(worker).not_to be_nil
              worker['env']
            end

            context 'when the database is mysql and no ca_cert is configured' do
              let(:properties) { { 'ccdb' => { 'db_scheme' => 'mysql' } } }

              it 'disables peer verification' do
                expect(worker_env(properties)['MARIADB_TLS_DISABLE_PEER_VERIFICATION']).to eq('1')
              end
            end

            context 'when the database is mysql and a ca_cert is configured' do
              let(:properties) { { 'ccdb' => { 'db_scheme' => 'mysql', 'ca_cert' => 'a-ca-cert' } } }

              it 'does not disable peer verification' do
                expect(worker_env(properties)).not_to have_key('MARIADB_TLS_DISABLE_PEER_VERIFICATION')
              end
            end

            context 'when the database is postgres' do
              let(:properties) { { 'ccdb' => { 'db_scheme' => 'postgres' } } }

              it 'does not disable peer verification' do
                expect(worker_env(properties)).not_to have_key('MARIADB_TLS_DISABLE_PEER_VERIFICATION')
              end
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'

module Bosh
  module Template
    module Test
      describe 'cloud_controller_ng post-start template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cloud_controller_ng') }

        describe 'bin/post-start' do
          let(:template) { job.template('bin/post-start') }

          def disables_peer_verification?(properties)
            rendered = template.render(properties, consumes: {})
            rendered.include?('export MARIADB_TLS_DISABLE_PEER_VERIFICATION="1"')
          end

          context 'when the database is mysql and no ca_cert is configured' do
            let(:properties) { { 'ccdb' => { 'db_scheme' => 'mysql' }, 'cc' => {} } }

            it 'exports the peer-verification override for the buildpacks rake task' do
              expect(disables_peer_verification?(properties)).to be(true)
            end
          end

          context 'when the database is mysql and a ca_cert is configured' do
            let(:properties) { { 'ccdb' => { 'db_scheme' => 'mysql', 'ca_cert' => 'a-ca-cert' }, 'cc' => {} } }

            it 'does not export the peer-verification override' do
              expect(disables_peer_verification?(properties)).to be(false)
            end
          end

          context 'when the database is postgres' do
            let(:properties) { { 'ccdb' => { 'db_scheme' => 'postgres' }, 'cc' => {} } }

            it 'does not export the peer-verification override' do
              expect(disables_peer_verification?(properties)).to be(false)
            end
          end
        end
      end
    end
  end
end

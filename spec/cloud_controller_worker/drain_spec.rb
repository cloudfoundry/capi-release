# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'

module Bosh
  module Template
    module Test
      describe 'drain template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cloud_controller_worker') }

        describe 'bin/shutdown_drain' do
          let(:template) { job.template('bin/shutdown_drain') }

          it 'renders the default value' do
            rendered_file = template.render({}, consumes: {})
            expect(rendered_file).to include('@grace_period = 15')
          end

          context "when 'worker_grace_period_seconds' is provided" do
            it 'renders the provided value' do
              rendered_file = template.render({ 'cc' => { 'jobs' => { 'generic' => { 'worker_grace_period_seconds' => 60 } } } }, consumes: {})
              expect(rendered_file).to include('@grace_period = 60')
            end
          end

          it 'renders the default number of workers' do
            rendered_file = template.render({}, consumes: {})
            expect(rendered_file).to include('(1..1).each do |i|')
          end

          context "when 'number_of_workers' is provided" do
            it 'renders the provided number of workers' do
              rendered_file = template.render({ 'cc' => { 'jobs' => { 'generic' => { 'number_of_workers' => 5 } } } }, consumes: {})
              expect(rendered_file).to include('(1..5).each do |i|')
            end
          end
        end

        describe 'bin/drain' do
          let(:template) { job.template('bin/drain') }

          it 'renders the default number of workers' do
            rendered_file = template.render({}, consumes: {})
            expect(rendered_file).to include('for i in {1..1}; do')
          end

          context "when 'number_of_workers' is provided" do
            it 'renders the provided number of workers' do
              rendered_file = template.render({ 'cc' => { 'jobs' => { 'generic' => { 'number_of_workers' => 5 } } } }, consumes: {})
              expect(rendered_file).to include('for i in {1..5}; do')
            end
          end

          it 'renders the job name and index' do
            rendered_file = template.render({ 'job_name' => 'cc-worker' }, consumes: {})
            # Default job name is 'me' in tests (bosh-template)
            expect(rendered_file).to include('bundle exec rake jobs:clear_pending_locks[cc_global_worker.me.0."${i}"]')
          end

          describe 'MySQL TLS peer verification' do
            def disables_peer_verification?(properties)
              rendered = template.render(properties, consumes: {})
              rendered.include?('export MARIADB_TLS_DISABLE_PEER_VERIFICATION="1"')
            end

            context 'when the database is mysql and no ca_cert is configured' do
              it 'disables peer verification' do
                expect(disables_peer_verification?({ 'ccdb' => { 'db_scheme' => 'mysql' } })).to be(true)
              end
            end

            context 'when the database is mysql and a ca_cert is configured' do
              it 'does not disable peer verification' do
                expect(disables_peer_verification?({ 'ccdb' => { 'db_scheme' => 'mysql', 'ca_cert' => 'a-ca-cert' } })).to be(false)
              end
            end

            context 'when the database is postgres' do
              it 'does not disable peer verification' do
                expect(disables_peer_verification?({ 'ccdb' => { 'db_scheme' => 'postgres' } })).to be(false)
              end
            end
          end
        end
      end
    end
  end
end

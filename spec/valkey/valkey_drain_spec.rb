# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'
require 'json'

module Bosh
  module Template
    module Test
      describe 'valkey drain script rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('valkey') }
        let(:template) { job.template('bin/drain') }

        context 'when valkey.drain_timeout is provided' do
          let(:properties) do
            { 'valkey' => { 'drain_timeout' => 120 } }
          end

          it 'renders the drain script with the configured timeout' do
            rendered = template.render(properties)
            expect(rendered).to include('TIMEOUT=120')
          end
        end

        context 'when valkey.drain_timeout is not provided' do
          it 'defaults to 60 seconds' do
            rendered = template.render({})
            expect(rendered).to include('TIMEOUT=60')
          end
        end

        it 'waits on the cloud_controller_ng pidfile' do
          rendered = template.render({})
          expect(rendered).to include('CCNG_PIDFILE="/var/vcap/sys/run/bpm/cloud_controller_ng/cloud_controller_ng.pid"')
          expect(rendered).to include('kill -0')
        end

        it 'signals bosh that draining is complete' do
          rendered = template.render({})
          expect(rendered).to include('echo 0')
        end

        it 'logs drain progress to the valkey drain log' do
          rendered = template.render({})
          expect(rendered).to include('LOG_FILE="/var/vcap/sys/log/valkey/drain.log"')
          expect(rendered).to include('drain timeout reached')
        end
      end
    end
  end
end

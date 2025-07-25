# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'
require 'json'

module Bosh
  module Template
    module Test
      describe 'cc_uploader drain script rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cc_uploader') }
        let(:template) { job.template('bin/drain') }

        context 'when capi.cc_uploader.cc_uploader_drain_timeout_in_minutes is provided' do
          let(:properties) do
            {
              'capi' => {
                'cc_uploader' => {
                  'cc_uploader_drain_timeout_in_minutes' => '10m'
                }
              }
            }
          end

          it 'renders the drain script with correct timeout' do
            rendered = template.render(properties)
            expect(rendered).to include('TIMEOUT_MINUTES="10m"')
            expect(rendered).to include('DRAIN_TIMEOUT=$(( TIMEOUT_MINUTES * 60 ))')
          end
        end

        context 'when capi.cc_uploader.cc_uploader_drain_timeout_in_minutes is not provided' do
          it 'defaults to 15 minutes' do
            rendered = template.render({})
            expect(rendered).to include('TIMEOUT_MINUTES="15m"')
          end
        end

        it 'writes logs to the expected log file' do
          rendered = template.render({})
          expect(rendered).to include('LOG_FILE="/var/vcap/sys/log/cc_uploader/drain.log"')
        end

        it 'uses the correct PID file location' do
          rendered = template.render({})
          expect(rendered).to include('PID_FILE="/var/vcap/sys/run/bpm/cc_uploader/cc_uploader.pid"')
        end

        it 'safely attempts to terminate the cc_uploader process' do
          rendered = template.render({})
          expect(rendered).to include('kill -TERM "$(cat "$PID_FILE")"')
          expect(rendered).to include('kill -0 "$(cat "$PID_FILE")"')
        end
      end
    end
  end
end

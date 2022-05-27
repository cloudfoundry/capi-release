# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'

module Bosh::Template::Test
  describe 'health check template rendering' do
    let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
    let(:release) { ReleaseDir.new(release_path) }
    let(:job) { release.job('cloud_controller_ng') }

    describe 'bin/ccng_monit_http_healthcheck' do
      let(:template) { job.template('bin/ccng_monit_http_healthcheck') }

      it 'renders the default value' do
        rendered_file = template.render({}, consumes: {})
        expect(rendered_file).to include('--max-time 2')
        expect(rendered_file).to include('--retry 5')
      end

      context 'when custom values are provided' do
        it 'renders the provided values' do
          rendered_file = template.render({ 'cc' => { 'ccng_monit_http_healthcheck_timeout_per_retry' => 30,
                                                      'ccng_monit_http_healthcheck_retries' => 2 } }, consumes: {})
          expect(rendered_file).to include('--max-time 30')
          expect(rendered_file).to include('--retry 2')
        end
      end
    end
  end
end

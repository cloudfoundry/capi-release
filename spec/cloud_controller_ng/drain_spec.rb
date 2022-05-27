# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'

module Bosh::Template::Test
  describe 'drain template rendering' do

    let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
    let(:release) { ReleaseDir.new(release_path) }
    let(:job) { release.job('cloud_controller_ng') }

    describe 'bin/shutdown_drain' do
      let(:template) { job.template('bin/shutdown_drain') }

      it 'renders the default value' do
        rendered_file = template.render({}, consumes: { } )
        expect(rendered_file).to include("@drain.shutdown_nginx('/var/vcap/sys/run/bpm/cloud_controller_ng/nginx.pid', 30)")
      end

      context 'when nginx timeout is provided' do
        it 'renders the provided value' do
          rendered_file = template.render({'cc' => {'nginx_drain_timeout' => 60 }}, consumes: { } )
          expect(rendered_file).to include("@drain.shutdown_nginx('/var/vcap/sys/run/bpm/cloud_controller_ng/nginx.pid', 60)")
        end
      end
    end

  end
end

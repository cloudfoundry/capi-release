# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'

module Bosh
  module Template
    module Test
      describe 'cc_uploader drain template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cc_uploader') }

        describe 'bin/shutdown_drain' do
          let(:template) { job.template('bin/shutdown_drain') }

          it 'renders the default grace period' do
            rendered_file = template.render({}, consumes: {})
            expect(rendered_file).to include('@grace_period = 30')
          end

          context "when 'grace_period_seconds' is provided" do
            it 'renders the provided grace period' do
              rendered_file = template.render({ 'cc' => { 'jobs' => { 'cc_uploader' => { 'grace_period_seconds' => 60 } } } }, consumes: {})
              expect(rendered_file).to include('@grace_period = 60')
            end
          end
        end
      end
    end
  end
end

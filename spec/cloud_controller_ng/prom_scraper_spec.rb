# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'

module Bosh
  module Template
    module Test
      describe 'prom_scraper config template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cloud_controller_ng') }

        describe 'prom_scraper_config.yml' do
          let(:template) { job.template('config/prom_scraper_config.yml') }
          let(:manifest_properties) { {} }

          before { @rendered_file = template.render(manifest_properties, consumes: {}) }

          it 'renders default values' do
            expect(@rendered_file).to include('port: 9025')
            expect(@rendered_file).to include('source_id: "cloud_controller_ng"')
            expect(@rendered_file).to include('path: /internal/v4/metrics')
            expect(@rendered_file).to include('server_name: cloud-controller-ng.service.cf.internal')
            expect(@rendered_file).to include('origin: cc')
          end

          context 'when prom_scraper is disabled' do
            let(:manifest_properties) { { 'cc' => { 'prom_scraper' => { 'disabled' => true } } } }

            it('renders an empty file') { expect(@rendered_file).to eq('') }
          end
        end
      end
    end
  end
end

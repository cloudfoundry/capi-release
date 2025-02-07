# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'

module Bosh
  module Template
    module Test
      describe 'prom_scraper config template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cloud_controller_worker') }
        let(:rendered_file) { template.render(manifest_properties, consumes: {}) }

        describe 'prom_scraper_config.yml' do
          let(:template) { job.template('config/prom_scraper_config.yml') }
          let(:manifest_properties) { {} }

          it 'renders an empty file' do
            expect(rendered_file).not_to include('port: 9025')
          end

          context 'when cc.publish_metrics is enabled' do
            before do
              manifest_properties['cc'] = {}
              manifest_properties['cc']['publish_metrics'] = true
            end

            it 'renders default values' do
              expect(rendered_file).to include('port: 9394')
            end

            context 'when different port is given' do
              before do
                manifest_properties['cc']['prometheus_port'] = 9397
              end

              it 'renders custom port' do
                expect(rendered_file).to include('port: 9397')
              end
            end

            context 'when prom_scraper is disabled' do
              it 'renders an empty file' do
                expect(rendered_file).not_to include('port: 9025')
              end
            end
          end
        end
      end
    end
  end
end

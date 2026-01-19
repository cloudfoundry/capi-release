# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'

module Bosh
  module Template
    module Test
      describe 'prom_scraper config template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cc_deployment_updater') }
        let(:rendered_file) { template.render(manifest_properties, consumes: {}) }

        describe 'prom_scraper_config.yml' do
          let(:template) { job.template('config/prom_scraper_config.yml') }
          let(:manifest_properties) { {} }

          it('renders an empty file') { expect(rendered_file).to eq('') }

          context 'when cc.publish_metrics is enabled' do
            before do
              manifest_properties['cc'] = {}
              manifest_properties['cc']['publish_metrics'] = true
            end

            it('renders default values') do
              expect(rendered_file).to include('port: 9395')
              expect(rendered_file).to include('source_id: "cc_deployment_updater"')
              expect(rendered_file).to include('path: /metrics')
              expect(rendered_file).to include('server_name: "cc_deployment_updater_metrics"')
              expect(rendered_file).to include('origin: cc_deployment_updater')
            end

            context 'when different port is given' do
              before { manifest_properties['cc']['prometheus_port'] = 9397 }

              it('renders custom port') { expect(rendered_file).to include('port: 9397') }
            end
          end
        end
      end
    end
  end
end

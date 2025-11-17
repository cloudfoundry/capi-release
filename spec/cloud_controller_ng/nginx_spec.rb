# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'

module Bosh
  module Template
    module Test
      describe 'nginx config template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cloud_controller_ng') }

        describe 'nginx.conf' do
          let(:template) { job.template('config/nginx.conf') }
          let(:manifest_properties) { {} }

          before do
            @rendered_file = template.render(manifest_properties, consumes: {})
          end

          it 'renders default values' do
            expect(@rendered_file).to include('log_format main escape=default')
          end

          context 'when json escaping for access log is configured' do
            let(:manifest_properties) { { 'cc' => { 'nginx_access_log_escaping' => 'json' } } }

            it 'renders escape=json' do
              expect(@rendered_file).to include('log_format main escape=json')
            end
          end

          context 'when nginx_rate_limit_general is configured' do
            let(:manifest_properties) { { 'cc' => { 'nginx_rate_limit_general' => { 'limit' => '200000' } } } }

            it 'renders limit_req_zone' do
              expect(@rendered_file).to include('limit_req_zone $http_authorization zone=all:10m rate=200000;')
            end
          end

          context 'when nginx_rate_limit_zones are configured' do
            let(:manifest_properties) { { 'cc' => { 'nginx_rate_limit_zones' => [{ 'name' => 'zone_a', 'limit' => '10000' }, { 'name' => 'zone_b', 'limit' => '5000' }] } } }

            it 'renders both zones' do
              expect(@rendered_file).to include('limit_req_zone $http_authorization zone=zone_a:10m rate=10000;')
              expect(@rendered_file).to include('limit_req_zone $http_authorization zone=zone_b:10m rate=5000;')
            end
          end

          context 'when nginx.ip is configured' do
            let(:manifest_properties) { { 'cc' => { 'nginx' => { 'ip' => '192.168.200.1' } } } }

            it 'renders nginx.ip' do
              expect(@rendered_file).to include('listen    192.168.200.1:9022;')
            end
          end

          context 'when all properties of prom_scraper are set' do
            let(:manifest_properties) { { 'cc' => { 'prom_scraper_tls' => { 'public_cert' => 'a public cert', 'private_key' => 'a private key', 'ca_cert' => 'an authority' } } } }

            it 'renders prom scraper server' do
              expect(@rendered_file).to include('include prom_scraper_mtls.conf')
            end
          end

          context 'when public_cert of prom_scraper is not set' do
            let(:manifest_properties) { { 'cc' => { 'prom_scraper_tls' => { 'private_key' => 'a private key', 'ca_cert' => 'an authority' } } } }

            it 'does not render prom scraper server' do
              expect(@rendered_file).not_to include('include prom_scraper_mtls.conf')
            end
          end

          context 'when private_key of prom_scraper is not set' do
            let(:manifest_properties) { { 'cc' => { 'prom_scraper_tls' => { 'public_cert' => 'a public cert', 'ca_cert' => 'an authority' } } } }

            it 'does not render prom scraper server' do
              expect(@rendered_file).not_to include('include prom_scraper_mtls.conf')
            end
          end

          context 'when ca_cert of prom_scraper is not set' do
            let(:manifest_properties) { { 'cc' => { 'prom_scraper_tls' => { 'public_cert' => 'a public cert', 'private_key' => 'a private key' } } } }

            it 'does not render prom scraper server' do
              expect(@rendered_file).not_to include('include prom_scraper_mtls.conf')
            end
          end

          describe 'separate metrics webserver' do
            let(:manifest_properties) { { 'cc' => { 'prom_scraper_tls' => { 'public_cert' => 'a public cert', 'private_key' => 'a private key', 'ca_cert' => 'an authority' } } } }

            it 'renders the unix socket of the second webserver' do
              expect(@rendered_file).to include('unix:/var/vcap/data/cloud_controller_ng/cloud_controller_metrics.sock;')
            end

            it 'forwards requests for the metrics endpoint to second webserver' do
              expect(@rendered_file).to include('proxy_pass http://cloud_controller_metrics;')
            end

            context 'when the webserver is not puma' do
              let(:manifest_properties) do
                super().merge('cc' => super()['cc'].merge('temporary_enable_deprecated_thin_webserver' => true))
              end

              it 'does not render the second webserver' do
                expect(@rendered_file).not_to include('unix:/var/vcap/data/cloud_controller_ng/cloud_controller_metrics.sock;')
              end

              it 'forwards requests for metrics endpoint to main app' do
                expect(@rendered_file).not_to include('proxy_pass http://cloud_controller_metrics;')
              end
            end
          end

          describe 'status endpoint' do
            context 'when use_status_check is false' do
              let(:manifest_properties) { { 'cc' => { 'use_status_check' => false } } }

              it 'does not expose the /internal/v4/status endpoint' do
                expect(@rendered_file).not_to include('/internal/v4/status')
              end
            end

            context 'when the default for use_status_check is used' do
              it 'exposes the /internal/v4/status endpoint' do
                expect(@rendered_file).to include('location /internal/v4/status')
              end

              context 'when Thin is used' do
                let(:manifest_properties) { { 'cc' => { 'temporary_enable_deprecated_thin_webserver' => true } } }

                it 'does not expose the /internal/v4/status endpoint' do
                  expect(@rendered_file).not_to include('location /internal/v4/status')
                end
              end
            end
          end
        end
      end
    end
  end
end

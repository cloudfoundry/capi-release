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
            end
          end
        end

        describe 'nginx_external_endpoints.conf' do
          let(:template) { job.template('config/nginx_external_endpoints.conf') }
          let(:manifest_properties) { {} }

          before do
            @rendered_file = template.render(manifest_properties, consumes: {})
          end

          context 'when local blobstore is configured' do
            let(:manifest_properties) { { 'cc' => { 'packages' => { 'blobstore_type' => 'local' } } } }

            it 'allows staging endpoints through to cloud controller' do
              expect(@rendered_file).to match(%r(location /staging/\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
            end
          end

          context 'when no local blobstore is configured' do
            it 'does not allow staging endpoints through to cloud controller' do
              # No staging allow block is rendered; staging is denied by the catch-all 404.
              expect(@rendered_file).not_to match(%r(location /staging/\s*\{[^}]*proxy_pass))
            end
          end

          describe 'allowlist routing' do
            it 'proxies the v3 API' do
              expect(@rendered_file).to match(%r(location = /v3\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
              expect(@rendered_file).to match(%r(location /v3/\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
            end

            it 'proxies the root document via an exact match' do
              expect(@rendered_file).to match(%r(location = /\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
            end

            it 'proxies /v2/info via an exact match' do
              expect(@rendered_file).to match(%r(location = /v2/info\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
            end

            it 'proxies /healthz via an exact match' do
              expect(@rendered_file).to match(%r(location = /healthz\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
            end

            it 'proxies the public ssh_access internal endpoint (cf ssh)' do
              expect(@rendered_file).to match(%r(location ~ \^/internal/apps/\[\^/\]\+/ssh_access/\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
            end

            it 'denies everything else with a 404 catch-all returning a CC-style JSON error' do
              expect(@rendered_file).to match(%r(location /\s*\{[^}]*default_type application/json;[^}]*return 404 '\{"errors":\[\{"detail":"Unknown request","title":"CF-NotFound","code":10000\}\]\}';))
            end
          end

          describe 'preserved special cases' do
            it 'does not allow-list generic internal endpoints (denied by the catch-all)' do
              expect(@rendered_file).not_to match(%r(location /internal/v\s*\{[^}]*proxy_pass))
            end

            it 'keeps the v3 upload locations' do
              expect(@rendered_file).to include('location ~ /v3/packages/.*/upload')
              expect(@rendered_file).to include('location ~ /v3/droplets/.*/upload')
              expect(@rendered_file).to include('include public_upload.conf')
            end

            it 'keeps the @cc_uploads named location' do
              expect(@rendered_file).to include('location @cc_uploads')
            end

            it 'keeps the nginx_status location' do
              expect(@rendered_file).to match(%r(location /nginx_status\s*\{[^}]*stub_status on;))
            end
          end

          describe 'v2 handling' do
            context 'when temporary_enable_v2 is false (default)' do
              it 'disables v2 endpoints except /v2/info' do
                # No /v2 or /v2/ allow block is rendered; those paths hit the catch-all 404.
                # /v2/info stays allow-listed via its own exact-match block.
                expect(@rendered_file).not_to match(%r(location = /v2\s*\{))
                expect(@rendered_file).not_to match(%r(location /v2/\s*\{))
                expect(@rendered_file).to match(%r(location = /v2/info\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
              end

              it 'does not render a /v2 allow block' do
                expect(@rendered_file).not_to match(%r(location = /v2\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
                expect(@rendered_file).not_to match(%r(location /v2/\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
              end
            end

            context 'when temporary_enable_v2 is true' do
              let(:manifest_properties) { { 'cc' => { 'temporary_enable_v2' => true } } }

              it 'allows the v2 API through to cloud controller' do
                expect(@rendered_file).to match(%r(location = /v2\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
                expect(@rendered_file).to match(%r(location /v2/\s*\{[^}]*proxy_pass\s+http://cloud_controller;))
              end

              it 'keeps the v2 upload locations' do
                expect(@rendered_file).to include('location ~ /v2/apps/[^/]+/bits')
              end
            end
          end

          describe 'general rate limiting' do
            context 'when nginx_rate_limit_general is configured' do
              let(:manifest_properties) { { 'cc' => { 'nginx_rate_limit_general' => { 'limit' => '100r/s', 'burst' => '500' } } } }

              it 'applies the general limit inside the v3 allow block' do
                expect(@rendered_file).to match(%r(location = /v3\s*\{[^}]*limit_req zone=all burst=500 nodelay;))
              end
            end

            context 'when nginx_rate_limit_general is not configured' do
              it 'does not apply a general limit' do
                expect(@rendered_file).not_to include('limit_req zone=all')
              end
            end
          end

          describe 'custom rate-limit zones' do
            let(:manifest_properties) do
              { 'cc' => { 'nginx_rate_limit_zones' => [{ 'name' => 'apps', 'location' => '/v3/apps', 'burst' => '50' }] } }
            end

            it 'renders each zone as its own location' do
              expect(@rendered_file).to match(%r(location /v3/apps\s*\{[^}]*proxy_pass\s+http://cloud_controller;[^}]*limit_req zone=apps burst=50 nodelay;))
            end
          end
        end
      end
    end
  end
end

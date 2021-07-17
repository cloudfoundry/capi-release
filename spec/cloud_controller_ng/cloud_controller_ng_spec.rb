# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'
require 'json'

module Bosh::Template::Test
  describe 'cloud_controller_ng job template rendering' do
    let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
    let(:release) { ReleaseDir.new(release_path) }
    let(:job) { release.job('cloud_controller_ng') }

    let(:merged_manifest_properties) do
      {
        'app_domains' =>
          ['brook-sentry.capi.land',
           { 'internal' => true, 'name' => 'foo.brook-sentry.capi.land' }],
        'app_ssh' =>
          { 'host_key_fingerprint' =>
            '((diego_ssh_proxy_host_key.public_key_fingerprint))' },
        'cc' =>
          { 'buildpacks' =>
            { 'blobstore_type' => 'webdav',
              'webdav_config' =>
                { 'blobstore_timeout' => 5,
                  'ca_cert' => '((service_cf_internal_ca.certificate))',
                  'password' => '((blobstore_admin_users_password))',
                  'private_endpoint' => 'https://blobstore.service.cf.internal:4443',
                  'public_endpoint' => 'https://blobstore.brook-sentry.capi.land',
                  'username' => 'blobstore-user' } },
            'diego' =>
            {
              'file_server_url' => "http://somewhere",
            },
            'database_encryption' =>
              { 'skip_validation' => false,
                'current_key_label' => 'encryption_key_0',
                'keys' => { 'encryption_key_0' => '((cc_db_encryption_key))' } },
            'db_encryption_key' => '((cc_db_encryption_key))',
            'default_app_memory' => 256,
            'default_running_security_groups' =>
              %w[public_networks dns load_balancer],
            'default_staging_security_groups' => %w[public_networks dns],
            'droplets' =>
              { 'blobstore_type' => 'webdav',
                'webdav_config' =>
                  { 'blobstore_timeout' => 5,
                    'ca_cert' => '((service_cf_internal_ca.certificate))',
                    'password' => '((blobstore_admin_users_password))',
                    'private_endpoint' => 'https://blobstore.service.cf.internal:4443',
                    'public_endpoint' => 'https://blobstore.brook-sentry.capi.land',
                    'username' => 'blobstore-user' } },
            'install_buildpacks' =>
              [{ 'name' => 'staticfile_buildpack', 'package' => 'staticfile-buildpack' },
               { 'name' => 'java_buildpack', 'package' => 'java-buildpack' },
               { 'name' => 'ruby_buildpack', 'package' => 'ruby-buildpack' },
               { 'name' => 'dotnet_core_buildpack', 'package' => 'dotnet-core-buildpack' },
               { 'name' => 'nodejs_buildpack', 'package' => 'nodejs-buildpack' },
               { 'name' => 'go_buildpack', 'package' => 'go-buildpack' },
               { 'name' => 'python_buildpack', 'package' => 'python-buildpack' },
               { 'name' => 'php_buildpack', 'package' => 'php-buildpack' },
               { 'name' => 'binary_buildpack', 'package' => 'binary-buildpack' }],
            'internal_api_password' => '((cc_internal_api_password))',
            'mutual_tls' =>
              { 'ca_cert' => '((service_cf_internal_ca.certificate))',
                'private_key' => '((cc_tls.private_key))',
                'public_cert' => '((cc_tls.certificate))' },
            'packages' =>
              { 'blobstore_type' => 'webdav',
                'webdav_config' =>
                  { 'blobstore_timeout' => 5,
                    'ca_cert' => '((service_cf_internal_ca.certificate))',
                    'password' => '((blobstore_admin_users_password))',
                    'private_endpoint' => 'https://blobstore.service.cf.internal:4443',
                    'public_endpoint' => 'https://blobstore.brook-sentry.capi.land',
                    'username' => 'blobstore-user' } },
            'resource_pool' =>
              { 'blobstore_type' => 'webdav',
                'webdav_config' =>
                  { 'blobstore_timeout' => 5,
                    'ca_cert' => '((service_cf_internal_ca.certificate))',
                    'password' => '((blobstore_admin_users_password))',
                    'private_endpoint' => 'https://blobstore.service.cf.internal:4443',
                    'public_endpoint' => 'https://blobstore.brook-sentry.capi.land',
                    'username' => 'blobstore-user' } },
            'security_group_definitions' =>
              [{ 'name' => 'public_networks',
                 'rules' =>
                  [{ 'destination' => '0.0.0.0-9.255.255.255', 'protocol' => 'all' },
                   { 'destination' => '11.0.0.0-169.253.255.255', 'protocol' => 'all' },
                   { 'destination' => '169.255.0.0-172.15.255.255', 'protocol' => 'all' },
                   { 'destination' => '172.32.0.0-192.167.255.255', 'protocol' => 'all' },
                   { 'destination' => '192.169.0.0-255.255.255.255', 'protocol' => 'all' }] },
               { 'name' => 'dns',
                 'rules' =>
                   [{ 'destination' => '0.0.0.0/0', 'ports' => '53', 'protocol' => 'tcp' },
                    { 'destination' => '0.0.0.0/0', 'ports' => '53', 'protocol' => 'udp' }] },
               { 'name' => 'load_balancer',
                 'rules' => [{ 'destination' => '10.244.0.34', 'protocol' => 'all' }] }],
            'stacks' =>
              [{ 'description' => 'Cloud Foundry Linux-based filesystem',
                 'name' => 'cflinuxfs3' }],
            'staging_upload_password' => '((cc_staging_upload_password))',
            'staging_upload_user' => 'staging_user' },
        'ccdb' =>
          { 'databases' => [{ 'name' => 'cloud_controller', 'tag' => 'cc' }],
            'db_scheme' => 'mysql',
            'port' => 3306,
            'roles' =>
              [{ 'name' => 'cloud_controller',
                 'password' => '((cc_database_password))',
                 'tag' => 'admin' }] },
        'router' => { 'route_services_secret' => '((router_route_services_secret))' },
        'routing_api' => { 'enabled' => true },
        'ssl' => { 'skip_cert_verify' => true },
        'system_domain' => 'brook-sentry.capi.land',
        'uaa' =>
          { 'ca_cert' => '((uaa_ca.certificate))',
            'clients' =>
              { 'cc-service-dashboards' =>
                { 'secret' => '((uaa_clients_cc-service-dashboards_secret))' },
                'cc_routing' => { 'secret' => '((uaa_clients_cc-routing_secret))' },
                'cc_service_key_client' =>
                  { 'secret' => '((uaa_clients_cc_service_key_client_secret))' },
                'cloud_controller_username_lookup' =>
                  { 'secret' => '((uaa_clients_cloud_controller_username_lookup_secret))' } },
            'url' => 'https://uaa.brook-sentry.capi.land' }
      }
    end

    let(:db_link) do
      Link.new(name: 'database', instances: [LinkInstance.new(address: 'some-other-database-address')])
    end

    let(:copilot_link) do
      Link.new(
        name: 'cloud_controller_to_copilot_conn',
        properties: {
          'listen_port_for_cloud_controller' => 12345
        }
      )
    end

    let(:links) { [db_link, copilot_link] }

    describe 'config/cloud_controller_ng.yml' do
      let(:template) { job.template('config/cloud_controller_ng.yml') }

      it 'creates the cloud_controller_ng.yml config file' do
        expect do
          YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
        end.to_not raise_error
      end

      describe 'app_domains' do
        it 'accepts a list of domain hashes and domain strings' do
          template_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
          expect(template_hash['app_domains']).to eq([
            'brook-sentry.capi.land',
            { 'internal' => true, 'name' => 'foo.brook-sentry.capi.land' }
          ])
        end

        context 'when a domain is marked internal and a router group specified' do
          before do
            merged_manifest_properties['app_domains'] = [
              { 'internal' => true, 'name' => 'foo.brook-sentry.capi.land', 'router_group_name' => 'tcp-router' }
            ]
          end

          it 'raises an error' do
            expect do
              YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
            end.to raise_error(StandardError, 'Error for app_domains: Router groups cannot be specified for internal domains.')
          end
        end

        context 'when an entry is an array of domains' do
          before do
            merged_manifest_properties['app_domains'] = [
              'brook-sentry.capi.land',
              { 'internal' => true, 'name' => 'foo.brook-sentry.capi.land' },
              [
                { 'internal' => true, 'name' => 'bar.some.internal' },
                'baz.capi.land'
              ]
            ]
          end

          it 'flattens the array of domains' do
            template_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
            expect(template_hash['app_domains']).to eq([
              'brook-sentry.capi.land',
              { 'internal' => true, 'name' => 'foo.brook-sentry.capi.land' },
              { 'internal' => true, 'name' => 'bar.some.internal' },
              'baz.capi.land'
            ])
          end
        end
      end


      describe 'temporary_istio_domains' do
        context 'when an entry is an array of domains' do
          before do
            merged_manifest_properties['copilot'] ||= {}
            merged_manifest_properties['copilot']['temporary_istio_domains'] = [
                'brook-sentry.capi.land',
                [
                    'mesh.apps.internal',
                    'mesh.apps.other.internal'
                ]
            ]
          end

          it 'flattens the array of domains' do
            template_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
            expect(template_hash['copilot']['temporary_istio_domains']).to eq([
                'brook-sentry.capi.land',
                'mesh.apps.internal',
                'mesh.apps.other.internal'
            ])
          end
        end
      end

      describe 'internal route vip range' do
        it 'has a default range' do
          rendered_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
          expect(rendered_hash['internal_route_vip_range']).to eq('127.128.0.0/9')
        end

        describe 'when a range is specified in manifest properties' do
          it 'validates they are valid CIDRs' do
            merged_manifest_properties['cc']['internal_route_vip_range'] = '10.16.255.0/777'
            expect { YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
            }.to raise_error(StandardError, 'invalid cc.internal_route_vip_range: 10.16.255.0/777')
          end

          it 'does not allow ipv6 addresses' do
            merged_manifest_properties['cc']['internal_route_vip_range'] = '2001:0db8:85a3:0000:0000:8a2e:0370:7334/21'
            expect { YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
            }.to raise_error(StandardError, 'invalid cc.internal_route_vip_range: 2001:0db8:85a3:0000:0000:8a2e:0370:7334/21')
          end

          it 'renders valid CIDRs' do
            merged_manifest_properties['cc']['internal_route_vip_range'] = '10.16.255.0/24'
            rendered_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
            expect(rendered_hash['internal_route_vip_range']).to eq('10.16.255.0/24')
          end
        end
      end

      describe 'database_encryption block' do
        context 'when the database_encryption block is not present' do
          before do
            merged_manifest_properties['cc'].delete('database_encryption')
          end

          it 'does not raise an error' do
            expect(merged_manifest_properties['cc']['database_encryption']).to be_nil

            expect do
              YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
            end.to_not raise_error
          end
        end

        context 'when the "current_encryption_key_label" is not found in the "keys" map' do
          before do
            merged_manifest_properties['cc']['database_encryption']['current_key_label'] = 'encryption_key_label_not_here_anymore'
          end

          context 'when the skip validation property is false' do
            it 'raises an error' do
              expect do
                YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
              end.to raise_error(
                StandardError,
                "Error for database_encryption: 'current_key_label' set to 'encryption_key_label_not_here_anymore', but not present in 'keys' map."
              )
            end
          end

          context 'when the skip validation property is true' do
            before do
              merged_manifest_properties['cc']['database_encryption']['skip_validation'] = true
            end

            it 'does not raise an error' do
              expect do
                YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
              end.to_not raise_error
            end
          end
        end

        context 'when the database_encryption.keys block is an array with secrets' do
          before do
            merged_manifest_properties['cc']['database_encryption']['keys'] = [
              {
                'encryption_key' => 'blah',
                'label' => 'encryption_key_0',
                'active' => true,
              },
              {
                'encryption_key' => 'other_key',
                'label' => 'encryption_key_1',
                'active' => false,
              }
            ]
          end

          it 'converts the array into the expected format (hash)' do
            template_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
            expect(template_hash['database_encryption']['keys']).to eq({
              'encryption_key_0' => 'blah',
              'encryption_key_1' => 'other_key'
            })
            expect(template_hash['database_encryption']['current_key_label']).to eq('encryption_key_0')
          end

          context 'when multiple key are marked active' do
            before do
              merged_manifest_properties['cc']['database_encryption']['keys'] = [
                {
                  'encryption_key' => 'blah',
                  'label' => 'encryption_key_0',
                  'active' => true,
                },
                {
                  'encryption_key' => 'other_key',
                  'label' => 'encryption_key_1',
                  'active' => true,
                }
              ]
            end

            it 'raises an error' do
              expect {
                YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
              }.to raise_error(/one key may be active/)
            end
          end
        end

        context 'when the database_encryption.keys block is a hash' do
          before do
            merged_manifest_properties['cc']['database_encryption']['keys'] = {
              'encryption_key_0' => 'blah',
              'encryption_key_1' => 'other_key'
            }
          end

          it 'converts the array into the expected format (hash)' do
            template_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
            expect(template_hash['database_encryption']['keys']).to eq({
              'encryption_key_0' => 'blah',
              'encryption_key_1' => 'other_key'
            })
          end
        end

        context 'when the database_encryption.keys block is an empty array' do
          before do
            merged_manifest_properties['cc']['database_encryption']['keys'] = []
          end

          context 'when the database_encryption.current_key_label is set' do
            it 'converts the array to an empty hash' do
              template_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
              expect(template_hash['database_encryption']['keys']).to eq({})
              expect(template_hash['database_encryption']['current_key_label']).to be_empty
            end
          end

          context 'when the database_encryption.current_key_label is NOT set' do
            before do
              merged_manifest_properties['cc']['database_encryption'].delete('current_key_label')
            end

            it 'converts the array to an empty hash' do
              template_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
              expect(template_hash['database_encryption']['keys']).to eq({})
              expect(template_hash['database_encryption']['current_key_label']).to be_empty
            end
          end
        end

      end

      context 'when db connection expiration configuration is present' do
        before do
          merged_manifest_properties['ccdb']['connection_expiration_timeout'] = 3600
          merged_manifest_properties['ccdb']['connection_expiration_random_delay'] = 60
        end

        it 'sets the db expiration properties' do
          template_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
          expect(template_hash['db']['connection_expiration_timeout']).to eq(3600)
          expect(template_hash['db']['connection_expiration_random_delay']).to eq(60)
        end
      end

      context 'when the file_server link is present' do
        let(:links) { [db_link,file_server_link] }

        context 'and https_server_enabled is true' do
          let(:file_server_link) { Link.new(name: 'file_server', properties: { 'https_server_enabled' => true, 'https_url' => 'https://somewhere-else' }) }

          it 'uses the value of the link' do
            template_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
            expect(template_hash['diego']['file_server_url']).to eq('https://somewhere-else')
          end
        end

        context 'and https_server_enabled is false' do
          let(:file_server_link) { Link.new(name: 'file_server', properties: { 'https_server_enabled' => false, 'https_url' => 'https://somewhere-else' }) }

          it 'uses the value of the property' do
            template_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
            expect(template_hash['diego']['file_server_url']).to eq('http://somewhere')
          end
        end
      end

      context 'when the file_server link is not present' do
        it 'uses the value of the property' do
          template_hash = YAML.safe_load(template.render(merged_manifest_properties, consumes: links))
          expect(template_hash['diego']['file_server_url']).to eq('http://somewhere')
        end
      end
    end
  end
end

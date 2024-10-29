# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'
require 'json'

module Bosh
  module Template
    module Test
      describe 'bpm job template rendering' do
        def expect_default_debug_env_vars(env_vars)
          expect(env_vars).to have_key('DEBUG')
          expect(env_vars).to have_key('FOG_DEBUG')
          expect(env_vars).not_to have_key('ALIYUN_OSS_SDK_LOG_LEVEL')
          expect(env_vars['DEBUG']).to be(true)
          expect(env_vars['FOG_DEBUG']).to be(true)
        end

        def valkey_volume_mounted?(process)
          return false unless process.key?('additional_volumes')

          results = process['additional_volumes'].select { |v| v['path'] == '/var/vcap/data/valkey' }
          return false unless results.length == 1

          valkey_volume = results[0]
          return false unless valkey_volume.key?('mount_only')

          mount_only = valkey_volume['mount_only']
          return false unless mount_only.is_a?(TrueClass) && mount_only == true

          true
        end

        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cloud_controller_ng') }

        let(:properties_debug_gcp) do
          { 'cc' => { 'log_fog_requests' => true, 'packages' => { 'fog_connection' => { 'provider' => 'Google' } } } }
        end
        let(:properties_debug_azure) do
          { 'cc' => { 'log_fog_requests' => true, 'packages' => { 'fog_connection' => { 'provider' => 'AzureRm' } } } }
        end
        let(:properties_debug_ali) do
          { 'cc' => { 'log_fog_requests' => true, 'packages' => { 'fog_connection' => { 'provider' => 'aliyun' } } } }
        end
        let(:properties_debug_foo) do
          { 'cc' => { 'log_fog_requests' => true, 'packages' => { 'fog_connection' => { 'provider' => 'foo' } } } }
        end
        let(:properties_without_debug) do
          { 'cc' => { 'log_fog_requests' => false, 'packages' => { 'fog_connection' => { 'provider' => 'aliyun' } } } }
        end

        describe 'config/bpm.yml' do
          let(:template) { job.template('config/bpm.yml') }

          context 'when fog debug logging is enabled' do
            it 'sets the DEBUG env var for GCP' do
              template_hash = YAML.safe_load(template.render(properties_debug_gcp, consumes: {}))

              results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
              expect(results.length).to eq(1)
              expect_default_debug_env_vars(results[0]['env'])
            end

            it 'sets the FOG_DEBUG env var for Azure' do
              template_hash = YAML.safe_load(template.render(properties_debug_azure, consumes: {}))

              results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
              expect(results.length).to eq(1)
              env_vars = results[0]['env']
              expect(env_vars).not_to have_key('DEBUG')
              expect(env_vars).to have_key('FOG_DEBUG')
              expect(env_vars).not_to have_key('ALIYUN_OSS_SDK_LOG_LEVEL')
              expect(env_vars['FOG_DEBUG']).to be(true)
            end

            it 'sets the ALIYUN_OSS_SDK_LOG_LEVEL env var for Ali' do
              template_hash = YAML.safe_load(template.render(properties_debug_ali, consumes: {}))

              results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
              expect(results.length).to eq(1)
              env_vars = results[0]['env']
              expect(env_vars).to have_key('DEBUG')
              expect(env_vars).to have_key('FOG_DEBUG')
              expect(env_vars).to have_key('ALIYUN_OSS_SDK_LOG_LEVEL')
              expect(env_vars['DEBUG']).to be(true)
              expect(env_vars['FOG_DEBUG']).to be(true)
              expect(env_vars['ALIYUN_OSS_SDK_LOG_LEVEL']).to eq('debug')
            end

            it 'sets not any debug env var for Foo' do
              template_hash = YAML.safe_load(template.render(properties_debug_foo, consumes: {}))

              results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
              expect(results.length).to eq(1)
              expect_default_debug_env_vars(results[0]['env'])
            end
          end

          context 'when fog debug logging is disabled' do
            it 'sets not any debug env var' do
              template_hash = YAML.safe_load(template.render(properties_without_debug, consumes: {}))

              results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
              expect(results.length).to eq(1)
              env_vars = results[0]['env']
              expect(env_vars).not_to have_key('DEBUG')
              expect(env_vars).not_to have_key('FOG_DEBUG')
              expect(env_vars).not_to have_key('ALIYUN_OSS_SDK_LOG_LEVEL')
            end
          end

          describe 'valkey config' do
            context 'when the puma webserver is used by default' do
              it 'mounts the valkey volume into the ccng job container' do
                template_hash = YAML.safe_load(template.render({}, consumes: {}))

                results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
                expect(results.length).to eq(1)
                expect(valkey_volume_mounted?(results[0])).to be_truthy
              end
            end

            context 'when the puma webserver is enabled by deprecated config' do
              it 'mounts the valkey volume into the ccng job container' do
                template_hash = YAML.safe_load(template.render({ 'cc' => { 'experimental' => { 'use_puma_webserver' => true } } }, consumes: {}))

                results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
                expect(results.length).to eq(1)
                expect(valkey_volume_mounted?(results[0])).to be_truthy
              end

              context 'when `cc.temporary_enable_deprecated_thin_webserver` is also enabled' do
                it 'still uses Puma and mounts the valkey volume into the ccng job container' do
                  template_hash = YAML.safe_load(template.render(
                                                   { 'cc' => { 'experimental' => { 'use_puma_webserver' => true },
                                                               'temporary_enable_deprecated_thin_webserver' => true } }, consumes: {}
                                                 ))

                  results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
                  expect(results.length).to eq(1)
                  expect(valkey_volume_mounted?(results[0])).to be_truthy
                end
              end
            end

            context 'when thin webserver is explicitly enabled' do
              context "when 'cc.experimental.use_redis' is set to 'true'" do
                it 'mounts the valkey volume into the ccng job container' do
                  template_hash = YAML.safe_load(
                    template.render({ 'cc' => { 'temporary_enable_deprecated_thin_webserver' => true,
                                                'experimental' => { 'use_redis' => true } } }, consumes: {})
                  )

                  results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
                  expect(results.length).to eq(1)
                  expect(valkey_volume_mounted?(results[0])).to be_truthy
                end
              end

              context "when 'cc.experimental.use_redis' is not set'" do
                it 'mounts the valkey volume into the ccng job container' do
                  template_hash = YAML.safe_load(template.render({ 'cc' => { 'temporary_enable_deprecated_thin_webserver' => true } }, consumes: {}))

                  results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
                  expect(results.length).to eq(1)
                  expect(valkey_volume_mounted?(results[0])).to be_falsey
                end
              end
            end

            context 'when thin webserver is implicitly enabled through `cc.experimental.use_puma_webserver` => false' do
              context "when 'cc.experimental.use_redis' is set to 'true'" do
                it 'mounts the valkey volume into the ccng job container' do
                  template_hash = YAML.safe_load(
                    template.render({ 'cc' => { 'experimental' => { 'use_puma_webserver' => false, 'use_redis' => true } } }, consumes: {})
                  )

                  results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
                  expect(results.length).to eq(1)
                  expect(valkey_volume_mounted?(results[0])).to be_truthy
                end
              end

              context "when 'cc.experimental.use_redis' is not set'" do
                it 'mounts the valkey volume into the ccng job container' do
                  template_hash = YAML.safe_load(template.render({ 'cc' => { 'temporary_enable_deprecated_thin_webserver' => true } }, consumes: {}))

                  results = template_hash['processes'].select { |p| p['name'].include?('cloud_controller_ng') }
                  expect(results.length).to eq(1)
                  expect(valkey_volume_mounted?(results[0])).to be_falsey
                end
              end
            end
          end
        end
      end
    end
  end
end

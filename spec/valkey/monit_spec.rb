# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'

module Bosh
  module Template
    module Test
      describe 'valkey job template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('valkey') }
        let(:spec) { job.instance_variable_get(:@spec) }
        let(:job_path) { job.instance_variable_get(:@job_path) }
        let(:cc_internal_properties) { { 'cc' => { 'temporary_enable_deprecated_thin_webserver' => false, 'experimental' => { 'use_redis' => false } } } }
        let(:link) { Link.new(name: 'cloud_controller_internal', properties: cc_internal_properties) }

        describe 'monit' do
          let(:template) { Template.new(spec, File.join(job_path, 'monit')) }

          context 'when the puma webserver is used by default' do
            it 'renders the monit directives' do
              result = template.render({}, consumes: [link])
              expect(result).to include('check process valkey')
            end
          end

          context 'when the puma webserver is enabled by deprecated config' do
            before do
              cc_internal_properties['cc']['experimental']['use_puma_webserver'] = true
            end

            it 'renders the monit directives' do
              result = template.render({}, consumes: [link])
              expect(result).to include('check process valkey')
            end

            context 'when `cc.temporary_enable_deprecated_thin_webserver` is also enabled' do
              before do
                cc_internal_properties['cc']['temporary_enable_deprecated_thin_webserver'] = true
              end

              it 'renders the monit directives' do
                result = template.render({}, consumes: [link])
                expect(result).to include('check process valkey')
              end
            end
          end

          context 'when the puma webserver is disabled by deprecated config' do
            before do
              cc_internal_properties['cc']['experimental']['use_puma_webserver'] = false
            end

            it 'does not render the monit directives' do
              result = template.render({}, consumes: [link])
              expect(result.strip).to eq('')
            end

            context "when 'cc.experimental.use_redis' is set to 'true'" do
              before do
                cc_internal_properties['cc']['experimental']['use_redis'] = true
              end

              it 'renders the monit directives' do
                result = template.render({}, consumes: [link])
                expect(result).to include('check process valkey')
              end
            end
          end

          context 'when `cc.temporary_enable_deprecated_thin_webserver` is enabled' do
            before do
              cc_internal_properties['cc']['temporary_enable_deprecated_thin_webserver'] = true
            end

            it 'does not render the monit directives' do
              result = template.render({}, consumes: [link])
              expect(result.strip).to eq('')
            end

            context "when 'cc.experimental.use_redis' is set to 'true'" do
              before do
                cc_internal_properties['cc']['experimental']['use_redis'] = true
              end

              it 'renders the monit directives' do
                result = template.render({}, consumes: [link])
                expect(result).to include('check process valkey')
              end
            end
          end
        end
      end
    end
  end
end

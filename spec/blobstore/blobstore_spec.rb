# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'

module Bosh
  module Template
    module Test
      describe 'blobstore job template rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('blobstore') }
        let(:template) { job.template('config/sites/blobstore.conf') }

        let(:manifest_properties) do
          {
            'system_domain' => 'example.com',
            'blobstore' => {
              'secure_link' => {
                'secret' => 'super-secret'
              }
            }
          }
        end

        it 'uses the default internal singleton hostname' do
          rendered_template = template.render(manifest_properties)

          expect(rendered_template).to include('server_name blobstore.service.cf.internal;')
        end

        it 'uses the configured internal singleton hostname' do
          manifest_properties['blobstore']['internal_hostname'] = 'blobstore.service.custom.internal'

          rendered_template = template.render(manifest_properties)

          expect(rendered_template).to include('server_name blobstore.service.custom.internal;')
        end
      end
    end
  end
end

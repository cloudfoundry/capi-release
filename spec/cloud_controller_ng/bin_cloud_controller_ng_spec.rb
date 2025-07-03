# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'
require 'json'

module Bosh
  module Template
    module Test
      describe 'bin/cloud_controller_ng startup script rendering' do
        let(:release_path) { File.join(File.dirname(__FILE__), '../..') }
        let(:release) { ReleaseDir.new(release_path) }
        let(:job) { release.job('cloud_controller_ng') }
        let(:template) { job.template('bin/cloud_controller_ng') }

        let(:properties) {
          { 'cc' =>
              { 'run_prestart_migrations' => false,
                'database_encryption' =>
                { 'skip_validation' => false } } } }

        it 'correctly renders the script' do
          expect do
            puts template.render(properties, consumes: { })
          end.not_to raise_error
        end

      end
    end
  end
end

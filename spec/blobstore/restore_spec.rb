# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'
require 'json'

module Bosh
  module Template
    module Test
      describe 'blobstore BBR restore script' do
        def template
          release_path = File.join(File.dirname(__FILE__), '../..')
          release = ReleaseDir.new(release_path)
          job = release.job('blobstore')
          job.template('bin/bbr/restore')
        end

        let(:links) do
          [
            Link.new(name: 'directories_to_backup', properties: {
                       'cc' => {
                         'droplets' => {
                           'droplet_directory_key' => 'some_droplets_directory_key'
                         },
                         'buildpacks' => {
                           'buildpack_directory_key' => 'some_buildpacks_directory_key'
                         },
                         'packages' => {
                           'app_package_directory_key' => 'some_packages_directory_key'
                         }
                       }
                     })
          ]
        end

        it 'templates all the restore commands' do
          expect(template.render({}, consumes: links)).to(
            include(
              'rm --recursive --force /var/vcap/store/shared/some_droplets_directory_key',
              'rm --recursive --force /var/vcap/store/shared/some_buildpacks_directory_key',
              'rm --recursive --force /var/vcap/store/shared/some_packages_directory_key',
              'cp --recursive --link $BBR_ARTIFACT_DIRECTORY/shared/some_droplets_directory_key',
              'cp --recursive --link $BBR_ARTIFACT_DIRECTORY/shared/some_buildpacks_directory_key',
              'cp --recursive --link $BBR_ARTIFACT_DIRECTORY/shared/some_packages_directory_key',
              'chown --recursive vcap:vcap /var/vcap/store/shared'
            )
          )
        end

        context 'when release_level_backup is set to false' do
          it 'does not template the restore commands' do
            expect(template.render({ 'release_level_backup' => false }, consumes: links)).not_to(
              include(
                'some_droplets_directory_key',
                'some_packages_directory_key',
                'some_buildpacks_directory_key',
                'chown'
              )
            )
          end
        end

        context 'when select_directories_to_backup are set' do
          it 'templates the restore commands for the selected directories' do
            restore_script = template.render({ 'select_directories_to_backup' => ['buildpacks'] }, consumes: links)
            expect(restore_script).to(
              include(
                'rm --recursive --force /var/vcap/store/shared/some_buildpacks_directory_key',
                'cp --recursive --link $BBR_ARTIFACT_DIRECTORY/shared/some_buildpacks_directory_key',
                'chown --recursive vcap:vcap /var/vcap/store/shared'
              )
            )

            expect(restore_script).not_to(
              include(
                'some_droplets_directory_key',
                'some_packages_directory_key'
              )
            )
          end
        end

        context 'when select_directories_to_backup contains an unknown directory' do
          it 'fails to render' do
            expect do
              template.render({ 'select_directories_to_backup' => ['some-unknown-directory'] }, consumes: links)
            end.to raise_error("Unknown directory in select_directories_to_backup: 'some-unknown-directory'")
          end
        end
      end
    end
  end
end

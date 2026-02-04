# frozen_string_literal: true

require 'rspec'
require 'bosh/template/test'
require 'yaml'
require 'json'

module Bosh
  module Template
    module Test
      describe 'blobstore BBR backup script' do
        def template
          release_path = File.join(File.dirname(__FILE__), '../..')
          release = ReleaseDir.new(release_path)
          job = release.job('blobstore')
          job.template('bin/bbr/backup')
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

        it 'templates all the backup commands' do
          expect(template.render({}, consumes: links)).to(
            include(
              'mkdir -p $BBR_ARTIFACT_DIRECTORY/shared',
              'cp --recursive --link /var/vcap/store/shared/some_droplets_directory_key',
              'cp --recursive --link /var/vcap/store/shared/some_buildpacks_directory_key',
              'cp --recursive --link /var/vcap/store/shared/some_packages_directory_key',
              'rm --force --recursive $BBR_ARTIFACT_DIRECTORY/shared/some_droplets_directory_key/buildpack_cache'
            )
          )
        end

        context 'when release_level_backup is false' do
          it 'does not template any commands' do
            expect(template.render({ 'release_level_backup' => false }, consumes: links)).not_to(
              include(
                'mkdir -p',
                'cp --recursive',
                'rm --force'
              )
            )
          end
        end

        context 'when select_directories_to_backup are set' do
          it 'templates the backup command for the selected directories' do
            backup_script = template.render({ 'select_directories_to_backup' => ['buildpacks'] }, consumes: links)
            expect(backup_script).to(
              include(
                'mkdir -p $BBR_ARTIFACT_DIRECTORY/shared',
                'cp --recursive --link /var/vcap/store/shared/some_buildpacks_directory_key'
              )
            )

            expect(backup_script).not_to(
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

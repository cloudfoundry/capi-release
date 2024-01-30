## How to bump the Ruby packing in capi-release

From time to time, the Ruby version for the capi-release needs to be bumped. Ruby is provided as a [BOSH package that needs to be embedded into the release](https://bosh.io/docs/package-vendoring/) and uploaded to a remote blob store.


1. Clone https://github.com/cloudfoundry/bosh-package-ruby-release. `git clone https://github.com/cloudfoundry/bosh-package-ruby-release`
1. Clone 'capi-release' and change directory into `capi-release`
1. Add `config/private.yml` to the `capi-release` with credentials to blobstore. Currently this is located in the credentials store with the CAPI release with the name `private.yml`. 
1. run the command `bosh vendor-package ruby-MAJOR.MINOR ~/DIRECTORY_WHERE_CLONED/bosh-package-ruby-release/`  where MAJOR.MINOR would be the Ruby version you are bumping to, e.g. `ruby-3.2`.
1. When completed, the `git diff` will indicate the new hashes for ruby-3.2 package or whichever version you have specified.
1. Update .ruby-version file to new version of ruby within the `capi-release` directory.
1. Commit and create a pull request for `capi-release`

In addition, [cloud_controller_ng](https://github.com/cloudfoundry/cloud_controller_ng/) also needs to have it's Ruby version bumped.
1. Update .ruby-version file to new version of ruby within the `cloud_controller_ng` directory.
1. Commit and create a pull request for `cloud_controller_ng`

For both of these steps, please ensure that the correct version of Ruby is being run in a local testing environment to ensure the correct version. A simple way to do this would be to check the ruby version on a CAPI VM by running the following command as root : `/var/vcap/packaging/ruby/bin/ruby -v` and noting the correctly bumped Ruby version.

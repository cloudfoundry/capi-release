[![slack.cloudfoundry.org](https://slack.cloudfoundry.org/badge.svg)](https://cloudfoundry.slack.com/messages/capi/)

# Cloud Foundry CAPI Bosh Release

This is the [bosh release](http://bosh.io/docs/release.html) for Cloud Foundry's [Cloud Controller API](https://github.com/cloudfoundry/cloud_controller_ng). 

**CI**: [CAPI Concourse Pipelines](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/capi-team)

## Components

* [Cloud Controller](https://github.com/cloudfoundry/cloud_controller_ng): The primary API of Cloud Foundry.
* [Cloud Controller Clock](https://github.com/cloudfoundry/cloud_controller_ng): Triggers periodic jobs for the Cloud Controller.
* [Cloud Controller Workers](https://github.com/cloudfoundry/cloud_controller_ng): Execute background jobs for the Cloud Controller.
* [Webdav Blobstore](https://github.com/cloudfoundry/capi-release/tree/develop/jobs/blobstore): An optional stand-alone blobstore for the Cloud Controller. 
* [NFS Mounter](https://github.com/cloudfoundry/capi-release/tree/develop/jobs/nfs_mounter): Connects Cloud Controller with an NFS blobstore.
* [CC Uploader](https://github.com/cloudfoundry/cc-uploader): Uploads files from [Diego](https://github.com/cloudfoundry/diego-release) to the Cloud Controller.
* [TPS Watcher](https://github.com/cloudfoundry/tps): Reports crash events from Diego to the Cloud Controller.

For more details on the integration between Diego and Capi Release, see [Diego Design Notes](https://github.com/cloudfoundry/diego-design-notes).

## Configuring Release

* [Deploying Cloud Foundry](https://docs.cloudfoundry.org/deploying/index.html)
* [Blobstore Configuration](https://docs.cloudfoundry.org/deploying/common/cc-blobstore-config.html)
* [TLS Configuration](https://github.com/cloudfoundry/capi-release/blob/develop/docs/tls-configuration.md)

## Contributing

* Read [Contribution Guidelines](https://github.com/cloudfoundry/capi-release/blob/develop/CONTRIBUTING.md)
* Public [Pivotal Tracker](https://www.pivotaltracker.com/n/projects/966314) project showing current team priorities

## Testing

* Run [CATS](https://github.com/cloudfoundry/cf-acceptance-tests)

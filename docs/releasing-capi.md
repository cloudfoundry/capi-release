# How to cut a CAPI release
1. **Make sure we're ready to release**
    - Are there any outstanding bugs or issues that need to be pulled in before we can release?
    - Ensure that API versions have been bumped after releasing the previous version ([v3 API version](https://github.com/cloudfoundry/cloud_controller_ng/blob/main/config/version), [v2 API version](https://github.com/cloudfoundry/cloud_controller_ng/blob/main/config/version_v2), [v2 API version in docs](https://github.com/cloudfoundry/cloud_controller_ng/blob/main/docs/v2/info/get_info.html)).
1. **Ship it in CI**
    - Log in to [CAPI CI](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/capi-team/pipelines/capi)
    - Pause the `bump-capi-release` job (in the `capi-release` group)
    - Unpause & run the `ship-it` job (in the `ship-it` group)
    - Wait for the pipeline to complete.
    - Pause the `ship-it` job.
    - Unpause the `bump-capi-release` job.
1. **Fill out the release and publish it**
    - The `ship-it` pipeline should have created a draft GitHub release.
    - Paste in the release notes from the [generate-release-notes job](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/capi-team/pipelines/capi/jobs/generate-release-notes) into the relevant sections in the release draft.
    - Add a section about new [Cloud Controller Database Migrations](https://github.com/cloudfoundry/cloud_controller_ng/tree/main/db/migrations).
    - Add any highlights to the top of the release notes.
    - Publish the release.
1. **Follow-ups**
    - Tell folks you shipped it.
      - Announce in #capi
      - Any specific teams/people who were waiting on the release
    - If there were any changes to the V3 docs, [run the GitHub action](https://github.com/cloudfoundry/cloud_controller_ng/actions/workflows/deploy_v3_docs.yml)

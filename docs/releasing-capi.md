# How to cut a CAPI release
1. Make sure we're ready to release:
  - Are there any outstanding bugs or issues that need to be pulled in before we can release?
  - Ensure that API versions have been bumped after releasing the previous version ([v3 API version](https://github.com/cloudfoundry/cloud_controller_ng/blob/main/config/version), [v2 API version](https://github.com/cloudfoundry/cloud_controller_ng/blob/main/config/version_v2), [v2 API version in docs](https://github.com/cloudfoundry/cloud_controller_ng/blob/main/docs/v2/info/get_info.html)).
2. Ship it in CI:
  - Log in to [CAPI CI](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/capi-team/pipelines/capi)
  - Pause the `bump-capi-release` job (in the `capi-release` group)
  - Unpause & run the `ship-it` job (in the `ship-it` group)
  - Wait for the pipeline to complete.
  - Pause the `ship-it` job.
  - Unpause the `bump-capi-release` job.
3. Create the release notes.
Currently, we have to manually create the release notes.

  - Make sure your local copy of the repo is up to date: `cd` into `capi-release` and `git pull`
  - Run `git log 1.xxx.0...1.yyy.0` to get the list of commits since the last release (replace 1.xxx.0 with the last release number, and 1.yyy.0 with the newly generated release number).
      - The full commit message of a ‘Bump …’ commit should contain the relevant commit message and PR/Issue number for the release notes.
  - Clean up the release notes (e.g. remove duplicate messages, reword PR info if needed).
4. Fill out the release and publish it
  - The `ship-it` pipeline should have created a draft Github release.
  - Paste in the release notes into the relevant sections in the release draft.
  - Add any Highlights to the top of the release notes.
  - Put dependency bumps in a separate section.
  - Publish the release.
5. Follow up
  - Tell folks you shipped it.
      - Announce in #capi
      - Any specific teams/people who were waiting on the release
  - If there were any changes to the V3 docs, [run the github action](https://github.com/cloudfoundry/cloud_controller_ng/actions/workflows/deploy_v3_docs.yml)
  - If there were any changes to the V2 docs, push the V2 docs app via [CI](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/capi-team/pipelines/capi/jobs/update-and-push-docs-v2)

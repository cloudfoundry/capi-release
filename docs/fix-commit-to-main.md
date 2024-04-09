## Fixing accidental commits to `main`

### Basic Workflow

#### Example bad commit

```
$ git log
commit 504bb330f21b1895ec0b4b3aa4467bc8b2da3517
Author: Matthew Sykes and Zach Robinson <pair+matthew+zrobinson@pivotallabs.com>
Date:   Thu Sep 11 12:08:41 2014 -0700

    commit to fix
```

#### 1. Revert the accidental commit to `main`

```
$ git revert 504bb330f2
[main 36418aa] Revert "commit to fix"
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 bad-file

$ git log
commit 36418aa5530b958a5aebbb68a3981aaf5f3f8ea8
Author: Matthew Sykes and Zach Robinson <pair+matthew+zrobinson@pivotallabs.com>
Date:   Thu Sep 11 12:10:04 2014 -0700

    Revert "commit to fix"

    This reverts commit 504bb330f21b1895ec0b4b3aa4467bc8b2da3517.

commit 504bb330f21b1895ec0b4b3aa4467bc8b2da3517
Author: Matthew Sykes and Zach Robinson <pair+matthew+zrobinson@pivotallabs.com>
Date:   Thu Sep 11 12:08:41 2014 -0700

    commit to fix

```

#### 2. Merge `main` to `develop` so that `develop` stays ahead of `main`

This is normally done automatically by the [`merge-capi-release-main`](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/capi-team/pipelines/capi/jobs/merge-capi-release-main) CI job, but you'll want to do it manually so that you don't need to involve the ship-it pipes.

```
$ git checkout develop
$ git merge main
```

#### 3. (OPTIONAL): On `develop`, revert the revert commit if you want to keep the original changes

If the commits were entirely accidental and should be thrown away, you can skip this step. Be aware it's not always entirely obvious if you still want the changes, especially if develop made more changes to same thing since the accidental commit occurred. Consider carefully.

If the commits were intentional, but you meant to put them on `develop` instead of `main`, do the following:

```
$ git revert 36418aa5530b95
[develop 350b69a] Revert "Revert "commit to fix""
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 bad-file

$ git log
commit 350b69a103aa8de6e5a2c2d03086b729c4c40add
Author: Matthew Sykes and Zach Robinson <pair+matthew+zrobinson@pivotallabs.com>
Date:   Thu Sep 11 12:11:54 2014 -0700

    Revert "Revert "commit to fix""

    This reverts commit 36418aa5530b958a5aebbb68a3981aaf5f3f8ea8.

commit 47cc979340696dffa8a5abd6c1b652832b96628c
Merge: aec4251 36418aa
Author: CF MEGA BOT <cf-mega@pivotal.io>
Date:   Thu Sep 11 12:10:52 2014 -0700

    Merge remote-tracking branch 'main-repo/main' into HEAD

commit 36418aa5530b958a5aebbb68a3981aaf5f3f8ea8
Author: Matthew Sykes and Zach Robinson <pair+matthew+zrobinson@pivotallabs.com>
Date:   Thu Sep 11 12:10:04 2014 -0700

    Revert "commit to fix"

    This reverts commit 504bb330f21b1895ec0b4b3aa4467bc8b2da3517.

commit 504bb330f21b1895ec0b4b3aa4467bc8b2da3517
Author: Matthew Sykes and Zach Robinson <pair+matthew+zrobinson@pivotallabs.com>
Date:   Thu Sep 11 12:08:41 2014 -0700

    commit to fix
```

### Special Cases

#### What if there are multiple commits to revert?

Just revert them one-by-one in reverse order. Commit range notation can be helpful in this situation.

```
$ git revert --no-commit HEAD~2..HEAD
```

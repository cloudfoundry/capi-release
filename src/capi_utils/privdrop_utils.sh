#!/usr/bin/env bash

# run_as_vcap
#
# Exec-style replacement for `chpst -u vcap:vcap "$@"`.
function run_as_vcap() {
  setpriv --reuid=vcap --regid=vcap --clear-groups --no-new-privs -- "$@"
}

#!/usr/bin/env bash

# wait_for_server_to_become_unavailable
#
# @param url
# @param timeout
#
# Curls the given url every second.
# If timeout seconds pass without the curl failing,
# return 1.
#
function wait_for_server_to_become_unavailable() {
  local url=$1
  local timeout=$2
  for _ in $(seq "${timeout}"); do
    set +e
    curl -k -f --connect-timeout 1 "${url}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      return 0
    fi
    set -e
    sleep 1
  done

  echo "Endpoint ${url} did not go down after ${timeout} seconds"
  return 1
}

# wait_for_server_to_become_healthy
#
# @param url
# @param timeout
#
# Curls the given url every second.
# If timeout seconds pass without the curl succeeding,
# return 1.
#
function wait_for_server_to_become_healthy() {
  local url=$1
  local timeout=$2
  for _ in $(seq "${timeout}"); do
    set +e
    curl -k -f --connect-timeout 1 "${url}" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      return 0
    fi
    set -e
    sleep 1
  done

  echo "Endpoint ${url} failed to become healthy after ${timeout} seconds"
  return 1
}

# monit_monitor_job
#
# @param job_name
#
# Tells monit to monitor the given job.
#
function monit_monitor_job() {
  local job_name="$1"
  sudo /var/vcap/bosh/bin/monit monitor "${job_name}"
}

# monit_unmonitor_job
#
# @param job_name
#
# Tells monit to unmonitor the given job,
# then waits until the given job is reported unmonitored.
#
function monit_unmonitor_job() {
  local job_name="$1"
  sudo /var/vcap/bosh/bin/monit unmonitor "${job_name}"
  wait_unmonitor_job "${job_name}"
}

# wait_unmonitor_job
#
# @param job_name
#
# Waits until the given job is reported unmonitored.
#
function wait_unmonitor_job() {
  local job_name="$1"

  while true; do
    if [[ $(sudo /var/vcap/bosh/bin/monit summary | grep ${job_name} ) =~ .*${job_name}.*[[:space:]]not[[:space:]]monitored[[:space:]]; then
      echo "Unmonitored ${job_name}"
      return 0
    else
      echo "Waiting for ${job_name} to be unmonitored..."
    fi

    sleep 0.1
  done
}

# drain_job
#
# @param job_name
#
# Calls the drain script of the given job
#
function drain_job() {
  local job_name="$1"
  sudo "/var/vcap/jobs/${job_name}/bin/drain"
}

# monit_start_job
#
# @param job_name
#
# Starts the given job via monit.
# Will attempt to start the job 6 times
# with an interval of 1 second.
#
function monit_start_job() {
  local job_name="$1"
  local timeout=6
  for _ in $(seq "${timeout}"); do
    set +e
    sudo /var/vcap/bosh/bin/monit start "${job_name}"
    if [ $? -eq 0 ]; then
      return
    fi
    set -e
    sleep 1
  done

  echo "Monit job \"${job_name}\" failed to start after ${timeout} seconds"
  exit 1
}

function monit_stop_job() {
  local job_name="$1"
  sudo /var/vcap/bosh/bin/monit stop "${job_name}"
}

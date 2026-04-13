#!/usr/bin/env bash

# write_output_to_file_with_datetime
#
# @param log_dir [String] the directory where the log file should be written
# @param log_name [String] used to name the log files eg: log_name.log and log_name.err.log
#
# Send stdout and stderr to specified file. Prepends datetime to output in the log file.
function write_output_to_file_with_datetime {
  declare log_dir="$1" log_name="$2"

  exec > >(prepend_datetime >>"${log_dir}/${log_name}.log")
  exec 2> >(prepend_datetime >>"${log_dir}/${log_name}.err.log")
}

# write_output_with_datetime
#
# Send stdout and stderr with Prependended datetime
function write_output_with_datetime {
  exec > >(prepend_datetime >> /dev/stdout)
  exec 2> >(prepend_datetime >> /dev/stderr)
}

function prepend_datetime {
  awk -W interactive '{ system("echo -n [$(date +\"%Y-%m-%d %H:%M:%S%z\")]"); print " " $0 }'
}

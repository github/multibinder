#!/bin/sh
# Extends lib.sh for this project

project_setup () {
  local control_sock=${TEMPDIR}/multibinder.sock
  launch_service "multibinder" bundle exec multibinder ${control_sock}

  tries=0
  while [ ! -S $control_sock ]; do
    sleep .1
    echo 'Waiting for control socket...'
    tries=$((tries + 1))
    if [ $tries -gt 10 ]; then
      echo 'Giving up.'
      exit 1
    fi
  done
}

project_cleanup () {
  kill_service "multibinder"
}

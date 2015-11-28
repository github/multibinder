#!/bin/sh
#
# test-simple.sh: simple sanity checks

REALPATH=$(cd $(dirname "$0") && pwd)
. "${REALPATH}/lib.sh"

TEST_PORT=8000

tests_use_port $TEST_PORT

begin_test "server successfully binds and accepts through multibinder"
(
  setup

  BINDER_SOCK=${TEMPDIR}/multibinder.sock launch_service "http" ruby test/httpbinder.rb

  wait_for_port "binder" $(offset_port $TEST_PORT)

  curl http://localhost:$(offset_port $TEST_PORT)/ | grep -q 'Hello World'
)
end_test

begin_test "server can restart without requests failing while down"
(
  setup

  BINDER_SOCK=${TEMPDIR}/multibinder.sock launch_service "http" ruby test/httpbinder.rb

  wait_for_port "binder" $(offset_port $TEST_PORT)

  kill_service "http"

  curl --max-time 5 http://localhost:$(offset_port $TEST_PORT)/ | grep -q 'Hello World' &
  curl_pid=$!

  sleep 0.5

  # now restart the service
  BINDER_SOCK=${TEMPDIR}/multibinder.sock launch_service "http" ruby test/httpbinder.rb

  # curl should finish, and succeed
  wait $curl_pid
)
end_test

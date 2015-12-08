#!/bin/bash
#
# test-simple.sh: simple sanity checks

REALPATH=$(cd $(dirname "$0") && pwd)
. "${REALPATH}/lib.sh"

TEST_PORT=8000

tests_use_port $TEST_PORT

begin_test "server binds and accepts through multibinder"
(
  setup

  launch_service "http" bundle exec env MULTIBINDER_SOCK=${TEMPDIR}/multibinder.sock ruby test/httpbinder.rb $(offset_port $TEST_PORT)

  wait_for_port "binder" $(offset_port $TEST_PORT)

  curl --max-time 5 http://localhost:$(offset_port $TEST_PORT)/ | grep -q 'Hello World'
)
end_test

begin_test "server can restart without requests failing while down"
(
  setup

  launch_service "http" bundle exec env MULTIBINDER_SOCK=${TEMPDIR}/multibinder.sock ruby test/httpbinder.rb $(offset_port $TEST_PORT)

  wait_for_port "binder" $(offset_port $TEST_PORT)

  kill_service "http"

  curl --max-time 5 http://localhost:$(offset_port $TEST_PORT)/ | grep -q 'Hello World' &
  curl_pid=$!

  sleep 0.5

  # now restart the service
  launch_service "http" bundle exec env MULTIBINDER_SOCK=${TEMPDIR}/multibinder.sock ruby test/httpbinder.rb $(offset_port $TEST_PORT)

  # curl should finish, and succeed
  wait $curl_pid
)
end_test


begin_test "server can load a second copy then terminate the first"
(
  setup

  launch_service "http" bundle exec env MULTIBINDER_SOCK=${TEMPDIR}/multibinder.sock ruby test/httpbinder.rb $(offset_port $TEST_PORT) "first"
  wait_for_port "binder" $(offset_port $TEST_PORT)

  curl --max-time 5 http://localhost:$(offset_port $TEST_PORT)/r1 | grep -q 'Hello World first'

  launch_service "http2" bundle exec env MULTIBINDER_SOCK=${TEMPDIR}/multibinder.sock ruby test/httpbinder.rb $(offset_port $TEST_PORT) "second"

  curl --max-time 5 http://localhost:$(offset_port $TEST_PORT)/r2 | egrep -q 'Hello World (first|second)'

  kill_service "http"

  curl --max-time 5 http://localhost:$(offset_port $TEST_PORT)/r3 | grep -q 'Hello World second'

  kill_service "http2"
)
end_test

begin_test "multibinder restarts safely on sigusr1"
(
  setup

  launch_service "http" bundle exec env MULTIBINDER_SOCK=${TEMPDIR}/multibinder.sock ruby test/httpbinder.rb $(offset_port $TEST_PORT)
  wait_for_port "binder" $(offset_port $TEST_PORT)

  curl --max-time 5 http://localhost:$(offset_port $TEST_PORT)/r1 | grep -q 'Hello World'

  kill_service "http"

  lsof -p $(service_pid "multibinder")

  kill -USR1 $(service_pid "multibinder")

  # should still be running, should still be listening
  lsof -p $(service_pid "multibinder")
  lsof -i :$(offset_port $TEST_PORT) -a -p $(service_pid "multibinder")

  # should be able to request the bind again
  launch_service "http" bundle exec env MULTIBINDER_SOCK=${TEMPDIR}/multibinder.sock ruby test/httpbinder.rb $(offset_port $TEST_PORT)
  wait_for_port "multibinder" $(offset_port $TEST_PORT)

  # requests should work
  curl --max-time 5 http://localhost:$(offset_port $TEST_PORT)/r2 | grep -q 'Hello World'

  # and multibinder should have started listening on the control socket twice
  grep 'Respawning' $(service_log "multibinder")
  grep 'Listening for binds' $(service_log "multibinder") | grep -n 'Listen' | grep "2:"
)
end_test

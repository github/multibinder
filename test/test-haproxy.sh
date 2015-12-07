#!/bin/bash
#
# test-haproxy.sh: check that we can work with haproxy (if it's installed)

REALPATH=$(cd $(dirname "$0") && pwd)
. "${REALPATH}/lib.sh"

TEST_PORT=8000

tests_use_port $TEST_PORT

if ! which haproxy >/dev/null 2>&1; then
  echo "haproxy not available, skipping tests."
  exit 0
fi

begin_test "haproxy runs with multibinder"
(
  setup

  export TEMPDIR

  MULTIBINDER_SOCK=${TEMPDIR}/multibinder.sock launch_service "haproxy" bundle exec ruby test/haproxy_shim.rb $(offset_port $TEST_PORT)

  wait_for_port "haproxy" $(offset_port $TEST_PORT)

  curl --max-time 5 http://localhost:$(offset_port $TEST_PORT)/ | grep -q 'Request forbidden'
)
end_test

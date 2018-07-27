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

  launch_service "haproxy" bundle exec env MULTIBINDER_SOCK=${TEMPDIR}/multibinder.sock ruby test/haproxy_shim.rb $(offset_port $TEST_PORT)

  wait_for_port "haproxy" $(offset_port $TEST_PORT)

  curl --max-time 5 http://localhost:$(offset_port $TEST_PORT)/ | grep -q 'Request forbidden'
)
end_test

begin_test "haproxy can bind to large numbers of file descriptors"
(
  setup

  export TEMPDIR

  echo >$TEMPDIR/haproxy-many-fds.cfg.erb

  for i in $(seq 1000); do
    echo "  bind <%= bind_tcp('127.0.0.1', $((TEST_PORT + $i))) %>" >>$TEMPDIR/haproxy-many-fds.cfg.erb
  done

  bundle exec env MULTIBINDER_SOCK=${TEMPDIR}/multibinder.sock ruby bin/multibinder-haproxy-erb -f $TEMPDIR/haproxy-many-fds.cfg.erb --erb-write-only

  if grep 'bind fd@' $TEMPDIR/haproxy-many-fds.cfg | sort | uniq -d | grep -q 'bind fd@'; then
  	echo 'Expected unique FDs, but found duplicates:'
  	cat $TEMPDIR/haproxy-many-fds.cfg
  	exit 1
  fi
)
end_test

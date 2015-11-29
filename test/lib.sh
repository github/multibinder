#!/bin/sh
# Usage: . lib.sh
# Simple shell command language test library.
#
# Tests must follow the basic form:
#
#   begin_test "the thing"
#   (
#        set -e
#        echo "hello"
#        false
#   )
#   end_test
#
# When a test fails its stdout and stderr are shown.
#
# Note that tests must `set -e' within the subshell block or failed assertions
# will not cause the test to fail and the result may be misreported.
#
# Copyright (c) 2011-13 by Ryan Tomayko <http://tomayko.com>
# License: MIT

set -e

TEST_DIR=$(dirname "$0")
ROLE=$(basename $(dirname "$0"))
BASE_DIR=$(cd $(dirname "$0")/../ && pwd)

TEMPDIR=$(mktemp -d /tmp/test-XXXXXX)
HOME=$TEMPDIR; export HOME
TRASHDIR="${TEMPDIR}"
LOGDIR="$TEMPDIR/log"

BUILD_DIR=${TEMPDIR}/build
ROLE_DIR=$BUILD_DIR

# keep track of num tests and failures
tests=0
failures=0

#mkdir -p $TRASHDIR
mkdir -p $LOGDIR

# offset port numbers if running in '--batch' mode
TEST_PORT_OFFSET=0
if [ "$1" = "--batch" ]; then
  TEST_PORT_OFFSET=$(ls -1 $(dirname "$0")/test-*.sh | grep -n $(basename "$0") | grep -o "^[0-9]*")
  TEST_PORT_OFFSET=$(( $TEST_PORT_OFFSET - 1 ))
fi

# Sanity check up front that nothing is currently using the ports we're
# trying use; port collisions will cause non-obvious test failures.
tests_use_port () {
  local p=$(offset_port $1)

  set +e
  lsof -n -iTCP:$p | grep -q LISTEN
  if [ $? -eq 0 ]; then
    echo "**** $(basename "$0") FAIL: Found something using port $p, bailing."
    lsof -n -iTCP:$p | grep -e ":$p" | sed -e "s/^/lsof failure $(basename "$0"): /"
    exit 1
  fi
  set -e
}

# Given a port, increment it by our test number so multiple tests can run
# in parallel without conflicting.
offset_port () {
  local base_port="$1"

  echo $(( $base_port + $TEST_PORT_OFFSET ))
}

# Mark the beginning of a test. A subshell should immediately follow this
# statement.
begin_test () {
    test_status=$?
    [ -n "$test_description" ] && end_test $test_status
    unset test_status

    tests=$(( tests + 1 ))
    test_description="$1"

    exec 3>&1 4>&2
    out="$TRASHDIR/out"
    err="$TRASHDIR/err"
    exec 1>"$out" 2>"$err"

    echo "begin_test: $test_description"

    # allow the subshell to exit non-zero without exiting this process
    set -x +e
    before_time=$(date '+%s')
}

report_failure () {
  msg=$1
  desc=$2
  failures=$(( failures + 1 ))
  printf "test: %-60s $msg\n" "$desc ..."
  (
    echo "-- stdout --"
    sed 's/^/    /' <"$TRASHDIR/out"
    echo "-- stderr --"
    grep -a -v -e '^\+ end_test' -e '^+ set +x' <"$TRASHDIR/err" |
      sed 's/^/    /'

    for service_log in $(ls $LOGDIR/*.log); do
      echo "-- $(basename "$service_log") --"
      sed 's/^/    /' <"$service_log"
    done

    echo "-- end --"
  ) 1>&2
}

# Mark the end of a test.
end_test () {
    test_status="${1:-$?}"
    ex_fail="${2:-0}"
    after_time=$(date '+%s')
    set +x -e
    exec 1>&3 2>&4
    elapsed_time=$((after_time - before_time))

    if [ "$test_status" -eq 0 ]; then
      if [ "$ex_fail" -eq 0 ]; then
        printf "test: %-60s OK (${elapsed_time}s)\n" "$test_description ..."
      else
        report_failure "OK (unexpected)" "$test_description ..."
      fi
    else
      if [ "$ex_fail" -eq 0 ]; then
        report_failure "FAILED (${elapsed_time}s)" "$test_description ..."
      else
        printf "test: %-60s FAILED (expected)\n" "$test_description ..."
      fi
    fi
    unset test_description
}

# Mark the end of a test that is expected to fail.
end_test_exfail () {
  end_test $? 1
}

atexit () {
    [ -z "$KEEPTRASH" ] && rm -rf "$TEMPDIR"
    if [ $failures -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}
trap "atexit" EXIT

cleanup() {
    set +e

    project_cleanup "$@"

    for pid_file in $(ls ${TEMPDIR}/*.pid); do
      echo "Cleaning up process in $pid_file ..."
      kill $(cat ${pid_file}) || true
    done

    echo "Cleaning up any remaining pid files."
    rm -rf ${TEMPDIR}/*.pid

    if [ -f "$TEMPDIR/core" ]; then
      echo "found a coredump, failing"
      exit 1
    fi
}

setup() {
  trap cleanup EXIT
  trap cleanup INT
  trap cleanup TERM

  project_setup "$@"

  set -e
}

wait_for_file () {
  (
    SERVICE="$1"
    PID_FILE="$2"

    set +e

    tries=0

    echo "Waiting for $SERVICE to drop $PID_FILE"
    while [ ! -e "$PID_FILE" ]; do
      tries=$(( $tries + 1 ))
      if [ $tries -gt 50 ]; then
        echo "FAILED: $SERVICE did not drop $PID_FILE after $tries attempts"
        exit 1
      fi
      echo "Waiting for $SERVICE to drop $PID_FILE"
      sleep 0.1
    done
    echo "OK -- $SERVICE dropped $PID_FILE"
    exit 0
  )
}

# wait for a process to start accepting connections
wait_for_port () {
  (
    SERVICE="$1"
    SERVICE_PORT="$2"

    set +e

    tries=0

    echo "Waiting for $SERVICE to start accepting connections"
    if [ $(uname) = "Linux" ]; then
      echo "PROXY TCP4 127.0.0.1 127.0.0.1 123 123\r" | nc -q 0 localhost $SERVICE_PORT 2>&1 >/dev/null
    else
      echo "PROXY TCP4 127.0.0.1 127.0.0.1 123 123\r" | nc localhost $SERVICE_PORT 2>&1 >/dev/null
    fi
    while [ $? -ne 0 ]; do
      tries=$(( $tries + 1 ))
      if [ $tries -gt 50 ]; then
        echo "FAILED: $SERVICE not accepting connections after $tries attempts"
        exit 1
      fi
      echo "Waiting for $SERVICE to start accepting connections"
      sleep 0.1
      if [ $(uname) = "Linux" ]; then
        echo "PROXY TCP4 127.0.0.1 127.0.0.1 123 123\r" | nc -q 0 localhost $SERVICE_PORT 2>&1 >/dev/null
      else
        echo "PROXY TCP4 127.0.0.1 127.0.0.1 123 123\r" | nc localhost $SERVICE_PORT 2>&1 >/dev/null
      fi
    done
    echo "OK -- $SERVICE seems to be accepting connections"
    exit 0
  )
}

# Allow simple launching of a background service, keeping track of the pid
launch_service () {
  local service_name=$1
  shift

  "$@" >${LOGDIR}/${service_name}.log 2>&1 &
  echo "$!" > ${TEMPDIR}/${service_name}.pid
}

# Clean up after a service launched with launch_service
kill_service () {
  local service_name=$1
  kill $(cat ${TEMPDIR}/${service_name}.pid) || true
  rm -rf ${TEMPDIR}/${service_name}.pid
}

service_pid () {
  local service_name=$1
  cat ${TEMPDIR}/${service_name}.pid
}

service_log () {
  local service_name=$1
  echo ${LOGDIR}/${service_name}.log
}

# Stub out functions and let the project extend them
project_setup () {
  true
}

project_cleanup () {
  true
}

if [ -e "$BASE_DIR/test/lib-project.sh" ]; then
  . $BASE_DIR/test/lib-project.sh
fi

#!/usr/bin/env bash
set -e

sigterm_handler() {
  echo "STOP signal received, try to gracefully shutdown all services..."
  docker kill foreman_nls

  # wait for stop
  wait
}

trap "sigterm_handler; exit" SIGINT

if [ "$OSX" ]; then
  NETWORK=' -p 9345:9345 '
else
  NETWORK=' --net="host" '
fi

docker kill foreman_nls || true

docker pull docker-registry.pertimm.net/viky.ai/platform/nlp$1 && \
  docker run \
    -e VIKYAPP_BASEURL=$VIKYAPP_BASEURL \
    -e VIKYAPP_REDIS_PACKAGE_NOTIFIER=$VIKYAPP_REDIS_PACKAGE_NOTIFIER \
    ${NETWORK} -t --rm --name foreman_nls --init docker-registry.pertimm.net/viky.ai/platform/nlp$1

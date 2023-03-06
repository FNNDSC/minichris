#!/bin/bash -e
# purpose: start up miniChRIS using podman-compose (experimental)
#
# usage: ./podmanchris.sh [up|down]
#
# requirements:
# - rootless podman
# - podman container networking
# - python3
#
# podman-compose issues to watch:
# - https://github.com/containers/podman-compose/issues/88
# - https://github.com/containers/podman-compose/issues/430
#
# what's working:
# - CUBE
# - chrisomatic
# - swift
#
# what's not working:
# - pman & pfcon
#
# i.e. You are able to upload files, create users, register plugins,
# but any plugin you try to run by creating a plugin instance will fail immediately.

# Wrapper for development version of podman-compose
function podman_compose_devel () {
  if ! [ -d venv ]; then
    python3 -m venv venv
  fi
  { set +x; } 2> /dev/null
  source venv/bin/activate
  set -x
  if ! [ -f venv/bin/podman-compose ]; then
    pip3 install --user https://github.com/containers/podman-compose/archive/devel.tar.gz
  fi
  ./venv/bin/podman-compose "$@"
}

if [ "$1" = 'down' ]; then
  podman_compose_devel down -v
  exit $?
fi

if [ "$1" != 'up' ] && [ -n "$1" ]; then
  2>&1 echo "usage: $0 [up|down]"
  2>&1 echo "unrecognized command: \"$1\""
  exit 1
fi

podman_compose_devel up -d

# start podman API daemon in background
podman system service -t 0 &
# in theory, we might need to poll for the unix socket's appearance, but it's not necessary...

# run chrisomatic
chris_container_id=$(podman ps --filter 'label=com.docker.compose.service=chris' --quiet)
local_network_id=$(podman container inspect --format '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' $chris_container_id)
podman run --rm -it --network=$local_network_id \
  -v $PWD/chrisomatic.yml:/chrisomatic.yml:ro \
  -v /run/user/$(id -u)/podman/podman.sock:/var/run/docker.sock:rw \
  ghcr.io/fnndsc/chrisomatic:0.4.0

# stop background podman API daemon
kill -TERM %1

#!/usr/bin/env bash

set -e

function log() {
  echo "-----> $*"
}

function indent() {
  sed -e 's/^/       /'
}

if [ -z "$TAILSCALE_AUTH_KEY" ]; then
  log "[tailscale]: Will not start because TAILSCALE_AUTH_KEY is not set"

else
  if [ -z "$TAILSCALE_HOSTNAME" ]; then
    if [ -z "$HEROKU_APP_NAME" ]; then
      tailscale_hostname=$(hostname)
    else
      # Only use the first 8 characters of the commit sha.
      # Swap the . and _ in the dyno with a - since tailscale doesn't
      # allow for periods.
      DYNO=${DYNO//./-}
      DYNO=${DYNO//_/-}
      tailscale_hostname=${HEROKU_SLUG_COMMIT:0:8}"-$DYNO-$HEROKU_APP_NAME"
    fi
  else
    tailscale_hostname="$TAILSCALE_HOSTNAME"
  fi
  tailscaled -cleanup > /dev/null 2>&1
  (tailscaled -verbose ${TAILSCALED_VERBOSE:--1} --tun=userspace-networking --socks5-server=localhost:1055 > /dev/null 2>&1 &)  
  tailscale up \
    --authkey="${TAILSCALE_AUTH_KEY}?preauthorized=true&ephemeral=true" \
    --hostname="$tailscale_hostname" \
    --accept-dns=${TAILSCALE_ACCEPT_DNS:-true} \
    --accept-routes=${TAILSCALE_ACCEPT_ROUTES:-true} \
    --advertise-exit-node=${TAILSCALE_ADVERTISE_EXIT_NODE:-false} \
    --shields-up=${TAILSCALE_SHIELDS_UP:-false} \
    --advertise-tags=${TAILSCALE_ADVERTISE_TAGS:-} \
    --timeout=15s

  export ALL_PROXY=socks5://localhost:1055/
  log "[tailscale]: Started using hostname=$tailscale_hostname; SOCKS5 proxy available at localhost:1055"
fi
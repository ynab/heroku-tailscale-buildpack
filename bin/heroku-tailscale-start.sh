#!/usr/bin/env bash

set -e

if [ -z "$TAILSCALE_AUTH_KEY" ]; then
  echo "[tailscale]: Will not be available because TAILSCALE_AUTH_KEY is not set"
  exit 0
fi

wait_for_tailscale_running() {
    timeout=5     # Timeout in seconds
    interval=0.5  # Interval between checks
    elapsed=0

    while [ "$elapsed" -lt "$timeout" ]; do
        state=$(tailscale status -json | jq -r .BackendState)
        if [ "$state" = "Running" ]; then            
            return 0
        fi
        sleep "$interval"
        elapsed=$(echo "$elapsed + $interval" | bc)
    done
    
    return 1
}

if [ -z "$TAILSCALE_HOSTNAME" ]; then
  if [ -z "$HEROKU_APP_NAME" ]; then
    TAILSCALE_HOSTNAME=$(hostname)
  else
    # Only use the first 8 characters of the commit sha.
    # Swap the . and _ in the dyno with a - since tailscale doesn't
    # allow for periods.
    DYNO=${DYNO//./-}
    DYNO=${DYNO//_/-}
    TAILSCALE_HOSTNAME="heroku-$HEROKU_APP_NAME-${HEROKU_SLUG_COMMIT:0:8}-$DYNO"
  fi
else
  TAILSCALE_HOSTNAME="$TAILSCALE_HOSTNAME"
fi
tailscaled -cleanup > /dev/null 2>&1
(tailscaled -verbose ${TAILSCALED_VERBOSE:--1} --tun=userspace-networking --socks5-server=localhost:1055 > /dev/null 2>&1 &)  
tailscale up \
  --authkey="${TAILSCALE_AUTH_KEY}?preauthorized=true&ephemeral=true" \
  --hostname="$TAILSCALE_HOSTNAME" \
  --advertise-tags=${TAILSCALE_ADVERTISE_TAGS:-} \
  --accept-routes \
  --timeout=15s \
  ${TAILSCALE_ADDITIONAL_ARGS:---timeout=15s}

export ALL_PROXY=socks5://localhost:1055/

if wait_for_tailscale_running; then
  echo "[tailscale]: Connected to tailnet as hostname=$TAILSCALE_HOSTNAME; SOCKS5 proxy available at localhost:1055"
else
  echo "[tailscale]: Warning - Backend did not reach 'Running' state within timeout"
fi

#!/usr/bin/env bash

. utils.sh

function tailscaled() {
  echo ">>> mocked tailscaled -verbose ${TAILSCALED_VERBOSE:-0} call <<<"
}

export -f tailscaled


function tailscale() {
  # Sleep to allow tailscaled to finish processing in the
  # background and avoid flapping tests.
  sleep 0.01
  echo ">>> mocked tailscale call
--authkey="${TAILSCALE_AUTH_KEY}?preauthorized=true&ephemeral=true" 
--hostname=${TAILSCALE_HOSTNAME:-test}
--advertise-tags=${TAILSCALE_ADVERTISE_TAGS:-} \
<<<"
}

export -f tailscale


run_test sanity heroku-tailscale-start.sh
TAILSCALED_VERBOSE=1 \
  TAILSCALE_AUTH_KEY="ts-auth-test" \
  TAILSCALE_HOSTNAME="test-host" \        
  TAILSCALE_ADVERTISE_TAGS="tag:test" \
  run_test envs heroku-tailscale-start.sh

TAILSCALED_VERBOSE=1 \
  TAILSCALE_AUTH_KEY="ts-auth-test" \
  HEROKU_APP_NAME="heroku-app" \
  DYNO="another_web.1" \
  HEROKU_SLUG_COMMIT="hunter20123456789"\        
  TAILSCALE_ADVERTISE_TAGS="tag:test" \
  run_test hostname heroku-tailscale-start.sh
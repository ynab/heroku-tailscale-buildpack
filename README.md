# Heroku buildpack to use Tailscale on Heroku

Run [Tailscale](https://tailscale.com/) on a Heroku dyno.

This is based on https://tailscale.com/kb/1107/heroku/.

Thank you to @rdotts, @kongmadai, @mvisonneau for their work on tailscale-docker and tailscale-heroku.


## Usage

To set up your Heroku application:
1. Add the buildpack to your app with `heroku buildpacks:add https://github.com/ynab/heroku-tailscale-buildpack --app your-app-name`
1. Obtain a Tailscale Auth key and set the environment variable `TAILSCALE_AUTH_KEY` using its value: `heroku config:set TAILSCALE_AUTH_KEY="your-auth-key-or-oauth-secret" --app your-app-name`

    ⚠ Note: You may also provide an OAuth Client Secret for the `TAILSCALE_AUTH_KEY` value but when doing so, you must also specify at least one tag to assign using the config `TAILSCALE_ADVERTISE_TAGS`.

1. Configure your application to use the Tailscale network by sending network requests through the SOCKS5 proxy listening at `127.0.0.1:1005`.  If any of the following apply to your app, no changes will need to be made:
   1. Your app reads and respects the environment variable `ALL_PROXY`.
   2. You are using a Ruby on Rails app and calling `bundle exec ...`, `rake ...`, or `rails ...` to start your app.  This buildpack will automatically configure the environment to use the SOCKS proxy by configuring a ProxyChains passthrough script for these scripts.
    
    ⚠ Note: If you are not able to configure your application to send requests through a SOCKS5 proxy, you will need to use [ProxyChains](#proxychains).  See additional instructions [below](#proxychains).       

1. Push a change to your Heroku app to build and deploy a new version


## ProxyChains

The buildpack pre-installs [ProxyChains](https://github.com/rofl0r/proxychains-ng) which is a program that forces any TCP connection made by an application through a proxy like SOCKS5.  Usage of ProxyChains is only necessary if your application does not support SOCKS5 proxies natively.

To use ProxyChains, update your `Procfile` to prefix your command(s) with `bin/tailscale_proxy`.  For example, if you are using Django and Celery, your `Procfile` might look like this:

```
web: bin/tailscale_proxy uvicorn --host 0.0.0.0 --port "$PORT" myproject.project.asgi:application
worker: bin/tailscale_proxy celery -A myproject.project worker
```

If the `TAILSCALE_AUTH_KEY` environment variable is set, the `bin/tailscale_proxy` script will configure the application to use ProxyChains.  Otherwise, the application will be run without ProxyChains.

## Known issues

- Connecting via tailnet hostnames is not supported.  You must use the tailnet IP address of the target machine.

## Testing the integration

To test a connection, you can add the ``hello.ts.net`` machine into your network,
[follow the instructions here](https://tailscale.com/kb/1073/hello/?q=testing).  Once this machine is added to your network, you can test the connection by running:

```shell
heroku run heroku-tailscale-test.sh --app your-app-name
```

You should see curl respond with ``<a href="https://hello.ts.net">Found</a>.``


## Configuration

The following settings are available for configuration via environment variables:

- ``TAILSCALE_AUTH_KEY`` - Provide an Auth key for authentication.  You may alternatively provide an OAuth Client Secret but you must also set the `TAILSCALE_ADVERTISE_TAGS` environment variable. **This must be set.**
- ``TAILSCALE_ACCEPT_DNS`` - Accept DNS configuration from the admin console. Defaults 
  to accepting DNS settings.
- ``TAILSCALE_ACCEPT_ROUTES`` - Accept subnet routes that other nodes advertise. Linux devices 
  default to not accepting routes. Defaults to accepting.
- ``TAILSCALE_ADVERTISE_EXIT_NODES`` - Offer to be an exit node for outbound internet traffic 
  from the Tailscale network. Defaults to not advertising.
- ``TAILSCALE_ADVERTISE_TAGS`` - Tags to assign to this device.  If the `TAILSCALE_AUTH_KEY` is an OAuth Client Secret, this value is required.
- ``TAILSCALE_HOSTNAME`` - Provide a hostname to use for the device instead of the one provided 
  by the OS. Note that this will change the machine name used in MagicDNS. Defaults to the 
  hostname of the application (a guid). If you have [Heroku Labs runtime-dyno-metadata](https://devcenter.heroku.com/articles/dyno-metadata)
  enabled, it defaults to ``[commit]-[dyno]-[appname]``.
- ``TAILSCALE_SHIELDS_UP"`` - Block incoming connections from other devices on your Tailscale 
  network. Useful for personal devices that only make outgoing connections. Defaults to off.
- ``TAILSCALED_VERBOSE`` - Controls verbosity for the tailscaled command. Defaults to 0.

The following settings are for the compile process for the buildpack. If you change these, you must
trigger a new build to see the change. Simply changing the environment variables in Heroku will not
cause a rebuild. These are all optional and will default to the latest values.

- ``TAILSCALE_BUILD_TS_TARGETARCH`` - The target architecture for the Tailscale package.
- ``TAILSCALE_BUILD_EXCLUDE_START_SCRIPT_FROM_PROFILE_D`` - Excludes the start script from the
  [buildpack's ``.profile.d/`` folder](https://devcenter.heroku.com/articles/buildpack-api#profile-d-scripts).
  If you set this to true, you must call ``vendor/tailscale/heroku-tailscale-start.sh``. This likely should go
  into your ``.profile`` script ([see Heroku docs](https://devcenter.heroku.com/articles/dynos#the-profile-file)).
  Starting the script in your ``.profile`` file would allow you to better control environment
  variables in respect to the executables. For example, a specific dyno could change
  ``TAILSCALE_HOSTNAME`` before tailscale starts.
- ``TAILSCALE_BUILD_PROXYCHAINS_REPO`` - The repository to install the proxychains-ng library from.
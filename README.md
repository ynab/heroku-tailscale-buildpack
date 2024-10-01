# Heroku buildpack to use Tailscale on Heroku

Run [Tailscale](https://tailscale.com/) on a Heroku dyno.

This buildpack installs and configures Tailscale in [userspace networking](https://tailscale.com/kb/1112/userspace-networking) mode so that it is able to run on a Heroku dyno.  A SOCKS5 proxy is available at `localhost:1055` to provide access to a tailnet.

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
- ``TAILSCALE_ADVERTISE_TAGS`` - Tags to assign to this device.   Each tag name should be prefixed with `tag:` and multiple tags should be delimited with a comma.  For example, if you wanted to assign the tags `development-database` and `development-server` you would specify the value `tag:development-database,tag:development-server`.  If the `TAILSCALE_AUTH_KEY` is an OAuth Client Secret, this value is required.
- ``TAILSCALE_HOSTNAME`` - Provide a hostname to use for the device instead of the one provided 
  by the OS. Note that this will change the machine name used in MagicDNS. Defaults to the 
  hostname of the application (a guid). If you have [Heroku Labs runtime-dyno-metadata](https://devcenter.heroku.com/articles/dyno-metadata)
  enabled, it defaults to ``[appname]-[commit]-[dyno]``.
- `TAILSCALE_ADDITIONAL_ARGS` - Additional arguments to pass when running `tailscale up`.  See https://tailscale.com/kb/1080/cli for details.

Note: `--accept-routes` is always passed to `tailscale up` to ensure that any advertized routes are accepted by the Tailscale client.

## Credit

This approach is based on Tailscale Heroku/Docker docs here: https://tailscale.com/kb/1107/heroku/ but has been adapted for use as a Heroku buildpack.

Thank you to @rdotts, @kongmadai, @mvisonneau for the work on tailscale-docker and tailscale-heroku.

Thank you @tim-schilling for the work on the original [heroku-tailscale-buildpack](https://github.com/aspiredu/heroku-tailscale-buildpack) repo from which this repo was forked.
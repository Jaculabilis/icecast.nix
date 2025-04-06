# icecast.nix

This flake provides an alternative implementation of the upstream NixOS module for Icecast, an internet radio streaming server.

Icecast is configured entirely through one XML config file, including the plaintext of all passwords.
This interacts poorly with NixOS, where everything in the system closure is world-readable in `/nix/store`.
This module provides a way to stub out secret values in the config as `@@NAME@@` and substitue them from a secrets file containing `NAME=VALUE` lines.
This secrets file can then be secured and made accessible only to the Icecast service user.

## Usage

The NixOS module is available as `nixosModules.default`.
It will disable and replace the upstream `services.icecast` module.

The format of the secrets file is

```
NAME_ONE=VALUE_ONE
NAME_TWO=VALUE_TWO
```

Each occurrence of `@@NAME_ONE@@` in the Icecast config will be replaced by `VALUE_ONE`, and so on.

The upstream option `admin.password` is gone.
Instead, the secrets file is passed to the module via `secretsFile`.
The secrets file must contain an line for `ADMIN_PASSWORD` or the service will fail to substitute it.
Any unsubstituted secret will cause the service to fail to start.

Note also that the default value for `listen.address` has changed to `127.0.0.1`,
so it must be explicitly set to a publicly-accessible address to expose the service.

## Demo

For an example of using this module, see the configuration in [demo.nix](./demo.nix),
which can also be launched via `nixos-shell --flake .#demo`.

For an example of using [Liquidsoap](https://www.liquidsoap.info/doc-2.2.5/) to stream audio to the Icecast server, see the source defined in `source.nix`, which can be run as `nix run .#demo-source`.

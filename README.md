# csql

A shell script to manage multiple [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy) instances across GCP projects and environments.

## Features

- Start/stop/status for all instances with a single command
- Per-environment YAML config (dev, staging, prod, ...)
- `--env` flag to target a specific environment
- PID and log management via `~/.local/share/csql/`
- Uses `gcloud auth application-default` — no service account keys needed
- zsh tab-completion for subcommands and environment names

## Requirements

- [yq](https://github.com/mikefarah/yq) v4+
- [cloud-sql-proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy) v2+
- `gcloud auth application-default login` completed

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/caseyblaze/csql/main/install.sh | bash
```

Then reload your shell:

```bash
source ~/.zshrc
```

## Configuration

Create one YAML file per environment in `~/.config/cloud-sql-proxy/`:

```yaml
# ~/.config/cloud-sql-proxy/dev.yaml
instances:
  - name: my-project:asia-east1:main-db
    port: 5432
  - name: other-project:asia-east1:analytics-db
    port: 5433
  - name: my-project:asia-east1:psc-instance
    port: 5434
    psc: true   # connect via Private Service Connect
```

```yaml
# ~/.config/cloud-sql-proxy/staging.yaml
instances:
  - name: my-project:asia-east1:staging-db
    port: 5442
```

The instance `name` field is the **Connection name** found in GCP Console → Cloud SQL → your instance.

To change or add connections, edit the YAML files in `~/.config/cloud-sql-proxy/`.

### Port convention (suggested)

| Environment | Port range |
|-------------|------------|
| dev         | 5432–5439  |
| staging     | 5442–5449  |
| prod        | 5452–5459  |

## Tab completion

zsh completion is set up automatically by `install.sh`. Reload your shell
to activate it:

    source ~/.zshrc

Then:

    csql <TAB>              # start / stop / status / help
    csql start --env <TAB>  # completes your configured environments

If you installed manually, add this to your `~/.zshrc` (after `compinit`):

    source <(csql completion zsh)

## Usage

```bash
csql start              # start all environments
csql start --env dev    # start only dev
csql stop               # stop all
csql stop --env dev     # stop only dev
csql status             # show status of all instances
```

### Status output

```
ENV        INSTANCE                                      PORT   PID      STATUS
---------- --------------------------------------------- ------ -------- -------
dev        my-project:asia-east1:main-db                 5432   12345    running
dev        other-project:asia-east1:analytics-db         5433   12345    running
staging    my-project:asia-east1:staging-db              5442   -        stopped
```

All instances within the same environment share one PID — a single `cloud-sql-proxy` process handles them all.

## Logs

Proxy logs are written to `~/.local/share/csql/<env>.log`.

```bash
tail -f ~/.local/share/csql/dev.log
```

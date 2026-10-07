# csql

A shell script to manage multiple [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy) instances across GCP projects and environments.

## Features

- Start/stop/status for all instances with a single command
- Per-environment YAML config (dev, staging, prod, ...)
- `--env` flag to target a specific environment
- PID and log management via `~/.local/share/csql/`
- Uses `gcloud auth application-default` — no service account keys needed
- `csql login` re-authenticates and restarts only what was running
- Optional launchd watcher restarts proxies by itself when credentials change,
  and opens the Google sign-in when they expire
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

    csql <TAB>              # start / stop / restart / status / login / watch / help
    csql start --env <TAB>  # completes your configured environments
    csql watch <TAB>        # enable / disable / status

If you installed manually, add this to your `~/.zshrc`:

    # csql tab-completion
    if command -v csql >/dev/null; then
      whence compdef >/dev/null 2>&1 || { autoload -Uz compinit && compinit }
      source <(csql completion zsh)
    fi

Keep exactly one `compinit` in your `~/.zshrc`, above everything that registers
a completion. Each `compinit` resets zsh's completion table, so a second one
lower down wipes what was registered above it — gcloud, `bq`, `gsutil`, nvm and
bun all register at source time and stop completing. The guard above runs
`compinit` only if nothing else has already initialised the system.

## Usage

```bash
csql start              # start all environments
csql start --env dev    # start only dev
csql stop               # stop all
csql stop --env dev     # stop only dev
csql restart            # stop then start
csql restart --env dev  # restart only dev
csql status             # show status of all instances, plus auth
csql login              # re-authenticate and restart what was running
csql watch enable       # auto-restart whenever credentials change
```

### Status output

```
ENV        INSTANCE                                      PORT   PID      STATUS
---------- --------------------------------------------- ------ -------- -------
dev        my-project:asia-east1:main-db                 5432   12345    running
dev        other-project:asia-east1:analytics-db         5433   12345    running
staging    my-project:asia-east1:staging-db              5442   -        stopped

Auth:  credentials updated 2026-08-31 11:06 (authorized_user, quota project my-project)
Watch: enabled (proxies restart automatically when credentials change)
```

All instances within the same environment share one PID — a single `cloud-sql-proxy` process handles them all.

An environment that started before the current credentials were written shows as
`running (old auth)`, with the restart command to fix it.

An environment whose proxy Google has stopped accepting shows as
`running (auth expired)`. The process is still up and holding its ports, but
every connection fails with `invalid_grant` until you sign in again.

## Credentials and auto-restart

`cloud-sql-proxy` reads your Application Default Credentials once at startup and
then holds the refresh token in memory for the life of the process. It never
re-reads the file and has no reload signal, so running
`gcloud auth application-default login` again does nothing for a proxy that is
already up — it has to be restarted before the new credentials take effect.

That restart is the part `csql` automates.

### One command instead of three

```bash
csql login
```

Runs `gcloud auth application-default login`, then restarts exactly the
environments that were running. Environments you had deliberately stopped stay
stopped.

### Or don't run anything at all

```bash
csql watch enable
```

Installs a launchd agent that watches the credentials file. However you
re-authenticate — `csql login`, plain `gcloud`, a different terminal — the
running proxies pick up the new credentials on their own within a few seconds.

```bash
csql watch status    # whether it is on, and what it has done lately
csql watch disable   # remove it
```

The agent restarts only when the file's contents actually change, and only
environments that are running at that moment. Its log is
`~/.local/share/csql/watch.log`. macOS only — it is built on launchd.

Enable it from the installed copy (`~/bin/csql`), not from a checkout under
`~/Documents`, `~/Desktop` or `~/Downloads`. macOS protects those folders and
launchd cannot execute anything inside them, so the watcher would fail on every
wake-up. `csql watch enable` refuses rather than let that happen quietly.

### Expired sign-ins

Under a Google Workspace reauthentication policy, the credentials stop working
after a while. `cloud-sql-proxy` does not exit when that happens: it keeps the
ports open and fails every connection with
`invalid_grant "reauth related error (invalid_rapt)"`, which shows up only in
its log.

With the watcher enabled, csql asks Google for a token every five minutes, the
same plain refresh the proxy makes, so it notices the expiry before you try to
connect. If that check can't run (offline, or credentials that aren't a user
sign-in), it falls back to looking for `invalid_grant` in the proxy logs.

When the credentials are refused and a proxy is running, csql posts a macOS
notification and opens the Google sign-in in your browser. Finish signing in
there, and the proxies restart on their own. You don't need a terminal. If
nothing is running, it waits: the first check after `csql start` opens the
sign-in.

It asks once for each set of credentials. If you close that page, it is not
reopened every five minutes. Run `csql login` when you are ready; it also closes
any sign-in the watcher left waiting. `csql status` shows which environments are
affected either way.

### How long a sign-in lasts

Google doesn't tell users how long their reauthentication session is; only a
Workspace admin can see it (Admin console → Security → Access and data control
→ Google Cloud session control). The watcher measures it instead. The
credentials file is written at sign-in, and the five-minute check pins down
when Google stopped accepting it:

```
$ csql watch status
...
Last measured session:
  signed in 2026-10-02 23:35, last accepted 2026-10-03 11:30 (11h 55m), refused 2026-10-03 11:35 (12h 00m) [invalid_rapt]
```

Every measurement is kept in `~/.local/share/csql/watch.log`
(`grep 'session ended' ~/.local/share/csql/watch.log`).

Signing in itself still needs you, because Google's reauthentication asks for
your password or second factor in the browser. What goes away is noticing the
failure, finding the right command, and the `csql stop` / `csql start` afterwards.

## Logs

Proxy logs are written to `~/.local/share/csql/<env>.log`.

```bash
tail -f ~/.local/share/csql/dev.log
```

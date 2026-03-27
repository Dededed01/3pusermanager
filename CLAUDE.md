# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A minimal Docker-based 3proxy SOCKS5 proxy server with a Bash user management script. 3proxy is compiled from source inside a Docker multi-stage build (Alpine-based). Users are stored in plaintext `config/users.cfg` and hot-reloaded into the running container via `SIGHUP`.

## Common Commands

```bash
# Start the proxy
docker compose up -d

# Rebuild and restart (after Dockerfile changes)
docker compose up -d --build

# User management
./manage.sh add <user> [pass]    # add user, prints credentials + Telegram SOCKS5 link
./manage.sh remove <user>        # remove user
./manage.sh list                 # list all users
./manage.sh link <user>          # print Telegram SOCKS5 deep link for existing user

# View live logs
docker logs -f 3proxy
tail -f logs/3proxy.log
```

## Architecture

- **dockerfile** — multi-stage build: compiles 3proxy 0.9.4 from source, produces a minimal Alpine image
- **docker-compose.yml** — mounts `./config` → `/etc/3proxy` and `./logs` → `/var/log/3proxy`; exposes port 1080
- **config/3proxy.cfg** — proxy config: includes `users.cfg`, requires strong auth, runs SOCKS5 on port 1080, logs daily to `/var/log/3proxy/`
- **config/users.cfg** — user list in `users <name>:CL:<plaintext-password>` format; edited directly by `manage.sh`
- **manage.sh** — adds/removes users in `users.cfg` and sends `SIGHUP` to the running container to reload without restart

## Key Details

- Users are stored as **cleartext** passwords in `users.cfg` with the `CL` scheme (3proxy cleartext format).
- Hot-reload works via `docker kill --signal=HUP 3proxy` — no container restart needed when adding/removing users.
- `SERVER_IP` is auto-detected at script runtime via `curl -s ifconfig.me`; override manually in `manage.sh` if behind NAT.
- `maxconn 5` in `3proxy.cfg` limits simultaneous connections per user — adjust as needed.
- The `logs/` directory is git-tracked as an empty mount point; actual log files (e.g. `3proxy.log.YYYY.MM.DD`) are rotated daily.

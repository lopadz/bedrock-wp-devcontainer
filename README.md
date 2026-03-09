# Bedrock WordPress Dev Container

A VS Code Dev Container for [WordPress Bedrock](https://roots.io/bedrock/) local development, built for [OrbStack](https://orbstack.dev) on macOS.

Drop `.devcontainer/` into any project to get a fully configured WordPress environment — PHP, MariaDB, Caddy with trusted HTTPS, WP-CLI, and Composer — with no manual setup.

---

## Requirements

- macOS with [OrbStack](https://orbstack.dev) installed
- [VS Code](https://code.visualstudio.com) with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension

> OrbStack provides Docker and automatic `.orb.local` DNS resolution, which this setup depends on for HTTPS.

---

## Quick Start

1. Copy `.devcontainer/` into your project root (or use this repo as a template).
2. Copy the example env file and configure it:
   ```sh
   cp .devcontainer/.env.example .devcontainer/.env
   ```
3. Edit `.devcontainer/.env` — at minimum set `PROJECT_NAME` and `DOMAIN`.
4. Open the project in VS Code and select **Reopen in Container** when prompted.
5. Wait for the setup to complete — WordPress is installed automatically on first run.
6. Open `https://<your-domain>.orb.local` in your browser.

> **HTTPS just works.** OrbStack installs a trusted root CA on your Mac during its own setup, so all `.orb.local` domains are automatically trusted in Safari and Chrome. No manual certificate steps needed.

---

## What's Included

| Tool              | Details                                                            |
| ----------------- | ------------------------------------------------------------------ |
| PHP               | Configurable version (default 8.4), with FPM and common extensions |
| MariaDB           | Database server, auto-initialized and configured on first run      |
| Caddy             | Web server with automatic HTTPS via a local CA                     |
| WordPress Bedrock | Installed automatically if not already present                     |
| WP-CLI            | For managing WordPress from the terminal                           |
| Composer          | PHP dependency management                                          |
| Node.js + npm     | For theme/plugin build tooling                                     |
| Oh My Zsh         | Default shell for the dev user                                     |

VS Code extensions installed automatically: PHP Intelephense, XDebug, GitLens, Error Lens, WordPress Toolbox, Composer, ACF Snippets, dotenv, PHP DocBlocker, Claude Code.

---

## Configuration

All project-specific settings live in `.devcontainer/.env`. Copy `.env.example` as a starting point.

| Variable            | Description                                   | Example               |
| ------------------- | --------------------------------------------- | --------------------- |
| `PROJECT_NAME`      | Used for container and Docker volume names    | `myproject`           |
| `DOMAIN`            | Local domain — must end in `.orb.local`       | `myproject.orb.local` |
| `WP_ADMIN_USER`     | WordPress admin username                      | `admin`               |
| `WP_ADMIN_PASSWORD` | Admin password — leave empty to auto-generate | _(empty)_             |
| `WP_ADMIN_EMAIL`    | Admin email address                           | `admin@example.com`   |
| `PHP_VERSION`       | PHP version to install (see note below)       | `8.4`                 |
| `DB_PORT`           | Host port MariaDB is forwarded to             | `3306`                |
| `DB_NAME`           | Database name                                 | `myproject`           |
| `DB_USER`           | Database user                                 | `myproject`           |
| `DB_PASSWORD`       | Database password                             | `secret`              |
| `DB_PREFIX`         | WordPress table prefix                        | `wp_`                 |

> **PHP versions:** Ubuntu 24.04 ships PHP 8.3 and below in its default package repositories. PHP 8.4+ requires the [ondrej/php PPA](https://launchpad.net/~ondrej/+archive/ubuntu/php), which the Dockerfile adds automatically when `PHP_VERSION` is `8.4` or higher. Supported values: `8.1`, `8.2`, `8.3` (default repos), `8.4` (PPA).

The remaining variables (`DEV_USER`, `WORKSPACE_ROOT`, `DEVCONTAINER_DIR`, `WEB_ROOT`, `PHP_FPM_SOCKET`, `HTTP_PORT`, `HTTPS_PORT`) are stable across projects and rarely need changing. `DEV_USER` is named deliberately to avoid conflicting with the shell's `$USERNAME` variable.

> **Note:** `devcontainer.json` does not support reading from `.env` files, so three values there are intentionally hardcoded and must stay in sync manually:
>
> - `workspaceFolder: "/workspace"` — must match `WORKSPACE_ROOT`
> - `remoteUser: "dev"` — must match `DEV_USER`
> - `forwardPorts: [3306]` — the container's internal MariaDB port, always 3306 regardless of `DB_PORT`

---

## How It Works

The container runs three services managed by [supervisord](http://supervisord.org):

```
MariaDB → PHP-FPM → Caddy
```

On first open, VS Code triggers `post-create.sh` which:

1. Installs Bedrock via Composer (if not already present).
2. Generates `www/.env.local` with database credentials and WordPress salts.
3. Initializes the database and creates the user.
4. Installs WordPress via WP-CLI.

On subsequent opens, `post-create.sh` is skipped for already-complete steps and supervisord starts the services automatically.

Caddy issues a self-signed certificate from a local CA stored in a per-project Docker volume. OrbStack installs its own root CA system-wide, so `.orb.local` HTTPS is trusted automatically in Safari and Chrome — no manual certificate steps needed.

---

## Project Structure

```
.devcontainer/
├── .env                  # Your local config (git-ignored)
├── .env.example          # Template — copy this to .env
├── Caddyfile             # Caddy web server config
├── compose.yaml          # Docker Compose service definition
├── devcontainer.json     # VS Code Dev Container config
├── Dockerfile            # Container image
├── post-create.sh        # Post-create initialization script
└── supervisord.conf      # Process manager config
www/                      # Bedrock install (git-ignored, created on first run)
├── .env                  # Empty stub — tells Bedrock to load .env.local
├── .env.local            # Generated DB credentials and WP salts
├── composer.json         # Bedrock dependencies
├── vendor/               # Composer packages (Docker volume, persists rebuilds)
└── web/
    ├── app/              # Themes, plugins, mu-plugins
    │   ├── themes/
    │   ├── plugins/
    │   └── mu-plugins/
    ├── wp/               # WordPress core (Docker volume, persists rebuilds)
    └── index.php
```

---

## Reusing Across Projects

1. Copy `.devcontainer/` into your project.
2. Create `.devcontainer/.env` from `.env.example`.
3. Set a unique `PROJECT_NAME` and `DOMAIN` for each project (prevents Docker volume name collisions).

If your project already has a Bedrock `www/` directory, `post-create.sh` will detect `www/composer.json` and run `composer install` instead of a fresh install.

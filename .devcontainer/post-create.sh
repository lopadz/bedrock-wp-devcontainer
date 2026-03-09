#!/bin/zsh
set -e

echo "🚀 Setting up Bedrock WordPress development environment..."

# Ensure mounted directories have correct permissions
if [ -d "www/vendor" ]; then
    sudo chown -R $(whoami):$(whoami) www/vendor
fi
if [ -d "www/web/wp" ]; then
    sudo chown -R $(whoami):$(whoami) www/web/wp
fi

# Check if Bedrock is already installed
if [ -f "www/composer.json" ]; then
    echo "📦 Installing Composer dependencies..."
    composer install -d www
else
    echo "📥 Bedrock not found - installing into www/..."

    # Install Bedrock to temp directory
    composer create-project roots/bedrock /tmp/bedrock --no-dev --no-interaction

    # Copy files to www/ (excluding vendor)
    mkdir -p www
    setopt extended_glob
    cp -r /tmp/bedrock/^vendor(DN) www/
    rm -rf /tmp/bedrock

    # Install dependencies (populates the mounted vendor volume)
    echo "📦 Installing Composer dependencies..."
    composer install -d www --no-interaction
fi

# Generate www/.env.local if missing (always, not just on fresh installs)
if [ ! -f "www/.env.local" ]; then
    echo "🔑 Fetching WordPress salts..."
    SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/ | awk -F"'" '{print $2"=\047"$4"\047"}')

    cat > www/.env.local << EOF
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASSWORD}"
DB_PREFIX="${DB_PREFIX}"
DB_HOST="127.0.0.1"

WP_ENV="development"
WP_HOME="https://${DOMAIN}"
WP_SITEURL="https://${DOMAIN}/wp"
WP_MEMORY_LIMIT="256M"

${SALTS}
EOF
    echo "✅ Generated www/.env.local"
fi

# Ensure a base .env exists so Bedrock loads .env.local (Bedrock requires .env to exist)
if [ ! -f "www/.env" ]; then
    touch www/.env
    echo "✅ Created empty www/.env (values come from .env.local)"
fi

# ── Database & WordPress Setup ────────────────────────────────────────────────
echo "🗄️  Setting up database..."

# Start MariaDB temporarily (supervisord hasn't started yet at postCreateCommand time)
sudo -u mysql mariadbd --datadir=/var/lib/mysql > /dev/null 2>&1 &
MARIADB_PID=$!

# Wait for MariaDB to be ready (up to 30s)
for i in $(seq 1 30); do
    if sudo mysqladmin ping --silent 2>/dev/null; then
        break
    fi
    sleep 1
done

# Create database and user if they don't exist
sudo mysql -e "
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
" && echo "✅ Database '${DB_NAME}' ready"

# Install WordPress via WP-CLI if not already installed
if ! (cd www && wp core is-installed 2>/dev/null); then
    echo "🌐 Installing WordPress..."
    WP_INSTALL_ARGS=(
        --url="https://${DOMAIN}"
        --title="${PROJECT_NAME}"
        --admin_user="${WP_ADMIN_USER}"
        --admin_email="${WP_ADMIN_EMAIL}"
        --skip-email
    )
    [ -n "${WP_ADMIN_PASSWORD}" ] && WP_INSTALL_ARGS+=(--admin_password="${WP_ADMIN_PASSWORD}")
    (cd www && wp core install "${WP_INSTALL_ARGS[@]}") && echo "✅ WordPress installed"
    echo "   Admin URL: https://${DOMAIN}/wp/wp-admin"
    echo ""

    # Set permalink structure to post name
    (cd www && wp rewrite structure '/%postname%/' --hard) && echo "✅ Permalink structure set to post name"
fi

# Stop temporary MariaDB — supervisord will manage it from here
sudo kill $MARIADB_PID
wait $MARIADB_PID 2>/dev/null || true
sleep 1  # brief pause to ensure socket/pid are released

echo "✅ Setup complete!"
echo ""
echo "   • Services (MariaDB, PHP-FPM, Caddy) start automatically via supervisord"
echo "   • Access your site at https://${DOMAIN}"
echo ""

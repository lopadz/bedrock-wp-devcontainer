FROM ubuntu:24.04

ARG USERNAME
ARG PHP_VERSION

ENV DEBIAN_FRONTEND=noninteractive

# ── System packages ───────────────────────────────────────────────────────────
# PHP 8.4+ is not in Ubuntu 24.04 default repos — add ondrej/php PPA conditionally
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && if dpkg --compare-versions "${PHP_VERSION}" ge "8.4"; then \
        add-apt-repository -y ppa:ondrej/php && apt-get update; \
    fi \
    && apt-get install -y --no-install-recommends \
    caddy git zsh curl ca-certificates unzip sudo supervisor \
    nodejs npm mariadb-server \
    php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-mysql php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip php${PHP_VERSION}-gd php${PHP_VERSION}-curl php${PHP_VERSION}-intl \
    && rm -rf /var/lib/apt/lists/*

# ── Global CLI tools ──────────────────────────────────────────────────────────
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && curl -sL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

# ── Dev user + shell ──────────────────────────────────────────────────────────
RUN usermod -l ${USERNAME} -d /home/${USERNAME} -m ubuntu \
    && groupmod -n ${USERNAME} ubuntu \
    && usermod -s /bin/zsh ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /home/${USERNAME}/.oh-my-zsh \
    && cp /home/${USERNAME}/.oh-my-zsh/templates/zshrc.zsh-template /home/${USERNAME}/.zshrc \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.oh-my-zsh /home/${USERNAME}/.zshrc

# ── Service configuration ─────────────────────────────────────────────────────
RUN sed -i "s|listen = /run/php/php${PHP_VERSION}-fpm.sock|listen = 127.0.0.1:9000|" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
    && sed -i "s/^user = www-data$/user = ${USERNAME}/" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
    && sed -i "s/^group = www-data$/group = ${USERNAME}/" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf \
    && mkdir -p /run/php && chown ${USERNAME}:${USERNAME} /run/php \
    && printf "variables_order=EGPCS\nmemory_limit=256M\nmax_execution_time=180\nupload_max_filesize=128M\npost_max_size=128M\n" \
       | tee /etc/php/${PHP_VERSION}/cli/conf.d/99-custom.ini \
           /etc/php/${PHP_VERSION}/fpm/conf.d/99-custom.ini > /dev/null \
    && mkdir -p /var/lib/mysql /run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /run/mysqld \
    && mariadb-install-db --user=mysql --datadir=/var/lib/mysql \
    && chmod 755 /var/lib/mysql

COPY supervisord.conf /etc/supervisord.conf

USER ${USERNAME}

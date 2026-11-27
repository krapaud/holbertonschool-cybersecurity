# Je pars d'Ubuntu 20.04, comme demandé dans les exercices.
FROM ubuntu:20.04

LABEL org.opencontainers.image.title="The Hardened Shield" \
      org.opencontainers.image.description="Image Ubuntu pour le Web et SSH avec configuration automatique de la sécurité" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="NovaTech Solutions" \
      org.opencontainers.image.licenses="Educational"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# J'installe Nginx pour le Web et OpenSSH pour l'administration.
# J'ajoute PAM et Fail2ban pour les contrôles d'identité.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        fail2ban \
        iptables \
        libpam-google-authenticator \
        libpam-pwquality \
        nginx \
        openssh-server \
        python3 \
        python3-minimal \
        python3-pip \
        python3-venv \
        rsyslog \
        util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system appuser \
    && useradd --system --gid appuser --home-dir /var/lib/appuser \
        --create-home --shell /usr/sbin/nologin appuser \
    && useradd --create-home --uid 1001 --user-group \
        --shell /bin/bash shieldadmin \
    && passwd --lock shieldadmin \
    && install -d -o shieldadmin -g shieldadmin -m 0700 \
        /home/shieldadmin/.ssh \
    && install -d -o root -g root -m 0755 /var/lib/hardened-shield \
    && install -d -o root -g root -m 0755 /usr/share/hardened-shield \
        /run/ssh-host-keys \
    && install -d -o root -g root -m 0755 /opt/hardened-shield/scripts \
        /opt/hardened-shield/config \
    && install -d -o root -g root -m 0755 /run/sshd

WORKDIR /opt/hardened-shield

# Les scripts appartiennent à root et sont rendus exécutables dans l'image.
COPY --chown=root:root scripts/ /opt/hardened-shield/scripts/
COPY --chown=root:root config/ /opt/hardened-shield/config/
COPY --chown=root:root config/fail2ban-jail.local \
    /etc/fail2ban/jail.d/sshd.local
COPY --chown=root:root config/fail2ban-default /etc/default/fail2ban
RUN install -o root -g root -m 0644 \
        /opt/hardened-shield/config/nginx.conf /etc/nginx/nginx.conf \
    && install -o root -g root -m 0644 \
        /opt/hardened-shield/config/sshd_config /etc/ssh/sshd_config \
    && chmod 0755 /opt/hardened-shield/scripts/*.sh \
    && chmod 0755 /opt/hardened-shield/scripts/audit.py \
    && ssh-keygen -q -t ed25519 -N '' \
        -f /run/ssh-host-keys/ssh_host_ed25519_key \
    && /opt/hardened-shield/scripts/init-hardening.sh \
    && /opt/hardened-shield/scripts/init-identity.sh \
    && rm -f /run/ssh-host-keys/* \
    && rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub \
    && chown -R root:appuser /var/log/nginx \
    && chmod 0770 /var/log/nginx \
    && chmod 0660 /var/log/nginx/*.log \
    && install -d -o root -g root -m 0755 /run/ssh-host-keys

# Je ne copie aucun secret dans l'image. Les secrets sont fournis au lancement.
EXPOSE 80 22

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1/health || exit 1

ENTRYPOINT ["/opt/hardened-shield/scripts/init-services.sh"]

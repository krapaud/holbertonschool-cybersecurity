# Image de base Ubuntu LTS, pour garder les outils système connus des exercices.
FROM ubuntu:20.04

LABEL org.opencontainers.image.title="The Hardened Shield" \
      org.opencontainers.image.description="Ubuntu web and SSH base image with automated security initialization" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="NovaTech Solutions" \
      org.opencontainers.image.licenses="Educational"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Nginx sert de serveur Web; OpenSSH fournit l'administration distante.
# Les modules PAM et Fail2ban apportent les contrôles d'identité appris.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        fail2ban \
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
    && install -d -o root -g root -m 0755 /opt/hardened-shield/scripts \
        /opt/hardened-shield/config \
    && install -d -o root -g root -m 0755 /run/sshd

WORKDIR /opt/hardened-shield

# Les scripts restent détenus par root et exécutables par l'entrypoint.
COPY --chown=root:root scripts/ /opt/hardened-shield/scripts/
COPY --chown=root:root config/ /opt/hardened-shield/config/
RUN install -o root -g root -m 0644 \
        /opt/hardened-shield/config/nginx.conf /etc/nginx/nginx.conf \
    && install -o root -g root -m 0644 \
        /opt/hardened-shield/config/sshd_config /etc/ssh/sshd_config \
    && chmod 0755 /opt/hardened-shield/scripts/*.sh \
    && chmod 0755 /opt/hardened-shield/scripts/audit.py

# Aucun mot de passe ni secret privé n'est incorporé à l'image.
# Fournir les secrets au lancement via Docker secrets ou des fichiers montés.
EXPOSE 80 22

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1/health || exit 1

ENTRYPOINT ["/opt/hardened-shield/scripts/init-services.sh"]

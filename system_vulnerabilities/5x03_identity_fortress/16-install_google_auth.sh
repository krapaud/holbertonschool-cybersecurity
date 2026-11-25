#!/bin/bash

# J'installe le module PAM Google Authenticator et je vérifie son emplacement.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo to install the PAM module.'
fi

for command_name in apt-get dpkg-query grep head mktemp rm; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

package_name=libpam-google-authenticator
temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT
module_list=$temporary_directory/module-files

printf '=== Google Authenticator Installation ===\n\n'
printf 'Installing %s...\n' "$package_name"

if dpkg-query -W -f='${db:Status-Status}' "$package_name" 2>/dev/null | \
    grep -q '^installed$'; then
    printf ' Package: Already installed\n'
else
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y libpam-google-authenticator; then
        error 'Could not install libpam-google-authenticator.'
    fi
    printf ' Package: Installed\n'
fi

# Je récupère le chemin du module à partir des fichiers réellement installés.
if ! dpkg-query -L "$package_name" | \
    grep -E '/pam_google_authenticator[.]so$' > "$module_list"; then
    error 'The package is installed, but the PAM module was not found.'
fi

module_path=$(head -n 1 "$module_list")
[ -r "$module_path" ] || error "PAM module is not readable: $module_path"

printf '\nModule location:\n'
printf ' %s\n' "$module_path"
printf '\nNext steps:\n'
printf "  1. Run 'google-authenticator' as each user to generate secrets\n"
printf '  2. Configure /etc/pam.d/sshd to require the module\n'
printf '  3. Enable ChallengeResponseAuthentication in sshd_config\n'
printf '\nGoogle Authenticator PAM module: INSTALLED\n'

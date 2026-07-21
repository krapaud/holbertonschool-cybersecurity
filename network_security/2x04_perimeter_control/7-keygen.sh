#!/bin/bash
wg genkey > server_private && wg pubkey < server_private > server_public
wg genkey > client_private && wg pubkey < client_private > client_public


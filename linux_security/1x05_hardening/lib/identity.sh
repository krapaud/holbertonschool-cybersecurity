#!/bin/bash
harden_identity() {
    if ! grep -q "^PASS_MAX_DAYS" /etc/login.defs; then
        echo "PASS_MAX_DAYS=$PASS_MAX_DAYS" >> /etc/login.defs
        log "I-01: Max days of Password configured"
    else
        sed -i "s/^PASS_MAX_DAYS.*/PASS_MAX_DAYS=$PASS_MAX_DAYS/" /etc/login.defs
        log "I-01: Max days of password already configured"
    fi
    if ! grep -q "^PASS_MIN_LEN" /etc/login.defs; then
        echo "PASS_MIN_LEN=$PASS_MIN_LEN" >> /etc/login.defs
        log "I-01: Min length of Password configured"
    else
        sed -i "s/^PASS_MIN_LEN.*/PASS_MIN_LEN=$PASS_MIN_LEN/" /etc/login.defs
        log "I-01: Min length of password already configured"
    fi
    if ! grep -q "pam_pwquality" /etc/pam.d/common-password; then
        echo "password requisite pam_pwquality.so minlen=$PASS_MIN_LEN ucredit=$PASS_UCREDIT lcredit=$PASS_LCREDIT dcredit=$PASS_DCREDIT ocredit=$PASS_OCREDIT" >> /etc/pam.d/common-password
        log "I-01: Password complexity configured"
    else
        sed -i "s/.*pam_pwquality.*/password requisite pam_pwquality.so minlen=$PASS_MIN_LEN ucredit=$PASS_UCREDIT lcredit=$PASS_LCREDIT dcredit=$PASS_DCREDIT ocredit=$PASS_OCREDIT/" /etc/pam.d/common-password
        log "I-01: Password complexity already configured"
    fi
    if ! grep -q "pam_faillock" /etc/pam.d/common-auth; then
        echo "auth required pam_faillock.so deny=$FAIL_LOCK_ATTEMPTS" >> /etc/pam.d/common-auth
        log "I-02: Account lockout configured"
    else
        sed -i "s/.*pam_faillock.*/auth required pam_faillock.so deny=$FAIL_LOCK_ATTEMPTS/" /etc/pam.d/common-auth
        log "I-02: Account lockout already configured"
    fi
    for user in $(awk -F: '$3 > 1000 {print $1}' /etc/passwd); do
        if ! groups "$user" | grep -qE "sudo|wheel"; then
            userdel "$user"
            log "I-03: Deleted user $user"
        fi
    done
    passwd -l root
    log "I-04: Root password locked"
}

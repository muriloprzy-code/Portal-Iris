#!/usr/bin/env bash
set -euo pipefail

data_directory="${ISC_DATA_DIRECTORY:-/durable/iris}"
password_file="/home/irisowner/dev/docker/.runtime-password.txt"

# Do not repeat first-start credential setup on an existing durable %SYS.
if [[ -f "${data_directory}/iris.cpf" ]]; then
    exec /iris-main "$@"
fi

# IRIS for Health 2026.2 lacks CSPpwd and may exit after updating IRIS accounts.
# Complete the first-start sentinel cleanup only for that image shape.
if [[ ! -x /usr/irissys/bin/CSPpwd ]]; then
    set +e
    /iris-main --password-file "${password_file}" "$@"
    status=$?
    set -e

    if [[ "${status}" -ne 0 && -f "${data_directory}/iris.cpf" ]]; then
        rm -f "${password_file}"
        touch "${password_file}.done"
        exec /iris-main "$@"
    fi

    exit "${status}"
fi

exec /iris-main --password-file "${password_file}" "$@"

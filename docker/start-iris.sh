#!/usr/bin/env bash
set -euo pipefail

data_directory="${ISC_DATA_DIRECTORY:-/durable/iris}"
password_file="/home/irisowner/dev/docker/.runtime-password.txt"
# Applied after every start: the demo settings come from the environment (MYOWN_DEMO_*).
after_start="/home/irisowner/dev/docker/demo-start.sh"

# An image whose MyOwn Portal installation did not complete must not start silently.
if [[ ! -f /home/irisowner/dev/docker/.install-complete ]]; then
    echo "MyOwn Portal is not installed in this image (the image build did not finish)." >&2
    echo "Rebuild it: docker compose -f compose.yaml -f compose.aihub.yaml build --no-cache" >&2
    echo "If the build stopped for lack of memory, see 'Memory' in README.md." >&2
    exit 1
fi

# Do not repeat first-start credential setup on an existing durable %SYS.
if [[ -f "${data_directory}/iris.cpf" ]]; then
    exec /iris-main -a "${after_start}" "$@"
fi

# Some IRIS for Health images lack CSPpwd and may exit after updating accounts.
# Complete the first-start sentinel cleanup only for that image shape.
if [[ ! -x /usr/irissys/bin/CSPpwd ]]; then
    set +e
    /iris-main --password-file "${password_file}" -a "${after_start}" "$@"
    status=$?
    set -e

    if [[ "${status}" -ne 0 && -f "${data_directory}/iris.cpf" ]]; then
        rm -f "${password_file}"
        touch "${password_file}.done"
        exec /iris-main -a "${after_start}" "$@"
    fi

    exit "${status}"
fi

exec /iris-main --password-file "${password_file}" -a "${after_start}" "$@"

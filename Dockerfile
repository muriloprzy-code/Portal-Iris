ARG IMAGE=containers.intersystems.com/intersystems/iris-community:latest-em
FROM ${IMAGE}

USER root
WORKDIR /home/irisowner/dev
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /home/irisowner/dev

USER ${ISC_PACKAGE_MGRUSER}
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} . /home/irisowner/dev
ADD --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} \
    https://pm.community.intersystems.com/packages/zpm/latest/installer \
    /tmp/zpm.xml

# MYOWN_DEMO_PASSWORD sets the initial _SYSTEM password for this local
# demo container. It is supplied at build time (see compose.yaml and
# .env.example), never hardcoded in the ObjectScript source, so no
# credential is committed to the repository. Override it in .env for
# anything beyond a local, throwaway demo.
ARG MYOWN_DEMO_PASSWORD=change-me-please
RUN ISC_CPF_MERGE_FILE=/home/irisowner/dev/docker/merge.cpf \
    iris start IRIS && \
    iris session IRIS < /home/irisowner/dev/docker/iris.script && \
    iris session IRIS < /home/irisowner/dev/docker/finish-build.script && \
    iris stop IRIS quietly

# Durable %SYS (ISC_DATA_DIRECTORY, set in compose.yaml) means %SYS -- including
# Security.Users and the _SYSTEM account -- is installed FRESH, from scratch, the
# first time the container actually starts with an empty external volume. Whatever
# password this Dockerfile's own build-time IRIS instance had is local to that
# throwaway instance and never carries over, so setting it here via ObjectScript
# (as this project used to do) has no effect on the real container. A fresh IRIS
# Community instance's initial _SYSTEM password is always "SYS" and forces a
# change on first use, which the official iris-main entrypoint's --password-file
# flag (see compose.yaml's "command") is the supported way to drive non-interactively.
# The chosen password is written into the image here from the build argument --
# never hardcoded in source -- so compose.yaml can point --password-file at it.
RUN printf '%s' "${MYOWN_DEMO_PASSWORD}" > /home/irisowner/dev/docker/.runtime-password.txt

USER root
RUN mkdir -p /durable && \
    chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /durable
USER ${ISC_PACKAGE_MGRUSER}

EXPOSE 1972 52773

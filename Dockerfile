ARG IMAGE=containers.intersystems.com/intersystems/iris-community:2026.2
FROM ${IMAGE}

USER root
WORKDIR /home/irisowner/dev
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /home/irisowner/dev

USER ${ISC_PACKAGE_MGRUSER}
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} . /home/irisowner/dev
ADD --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} \
    https://pm.community.intersystems.com/packages/zpm/latest/installer \
    /tmp/zpm.xml

# Public local-demo credential; override it through .env before non-local use.
ARG MYOWN_DEMO_PASSWORD=change-me-please
RUN ISC_CPF_MERGE_FILE=/home/irisowner/dev/docker/merge.cpf \
    iris start IRIS && \
    iris session IRIS < /home/irisowner/dev/docker/iris.script && \
    iris session IRIS < /home/irisowner/dev/docker/finish-build.script && \
    iris stop IRIS quietly

# Durable %SYS is created at runtime, so the build-time account database is not
# retained. The startup wrapper passes this credential to iris-main only on the
# first start of a local demo volume.
RUN printf '%s' "${MYOWN_DEMO_PASSWORD}" > /home/irisowner/dev/docker/.runtime-password.txt

USER root
RUN chmod +x /home/irisowner/dev/docker/start-iris.sh
RUN mkdir -p /durable && \
    chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /durable
USER ${ISC_PACKAGE_MGRUSER}

ENTRYPOINT ["/tini", "--", "/home/irisowner/dev/docker/start-iris.sh"]

EXPOSE 1972 52773

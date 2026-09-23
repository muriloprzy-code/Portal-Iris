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

# MEUPORTAL_DEMO_PASSWORD sets the initial _SYSTEM password for this local
# demo container. It is supplied at build time (see compose.yaml and
# .env.example), never hardcoded in the ObjectScript source, so no
# credential is committed to the repository. Override it in .env for
# anything beyond a local, throwaway demo.
ARG MEUPORTAL_DEMO_PASSWORD=change-me-please
RUN ISC_CPF_MERGE_FILE=/home/irisowner/dev/docker/merge.cpf \
    MEUPORTAL_DEMO_PASSWORD=${MEUPORTAL_DEMO_PASSWORD} \
    iris start IRIS && \
    iris session IRIS < /home/irisowner/dev/docker/iris.script && \
    iris stop IRIS quietly

USER root
RUN mkdir -p /durable && \
    chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /durable
USER ${ISC_PACKAGE_MGRUSER}

EXPOSE 1972 52773

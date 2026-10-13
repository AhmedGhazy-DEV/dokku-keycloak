# Build context used by the keycloak plugin. The plugin supplies
# KEYCLOAK_IMAGE and writes build.env with the instance's build-time options.
ARG KEYCLOAK_IMAGE=quay.io/keycloak/keycloak:26.8.1

FROM ${KEYCLOAK_IMAGE} AS builder
ENV KC_DB=postgres \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true
COPY build.env /tmp/build.env
# `start --optimized` only works on an image whose build-time options were
# fixed here, so they are applied before `kc.sh build`.
RUN set -a && . /tmp/build.env && set +a && /opt/keycloak/bin/kc.sh build

FROM ${KEYCLOAK_IMAGE}
COPY --from=builder /opt/keycloak/ /opt/keycloak/
COPY docker-entrypoint.sh /opt/keycloak/bin/dokku-entrypoint.sh
# Dokku reads app.json from the image WORKDIR (/opt/keycloak) for image deploys.
COPY app.json /opt/keycloak/app.json
ENTRYPOINT ["/opt/keycloak/bin/dokku-entrypoint.sh"]
CMD ["start", "--optimized"]

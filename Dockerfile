# Should be compatible with redhat/ubi9 | https://almalinux.org/blog/almalinux-container-images-update-full-rhel-ubi-compatibility/
FROM almalinux/9-base AS ubi-micro-build

# Preparing curl for final image so we can do internal healthchecks
RUN mkdir -p /mnt/rootfs
RUN dnf install --installroot /mnt/rootfs curl --releasever 9 --setopt instal_weak_deps=false --nodocs -y \
    && dnf --installroot /mnt/roofs clean all \
    && rpm --root /mnt/rootfs -e --nodeps setup


FROM quay.io/keycloak/keycloak:24.0 as builder

WORKDIR /opt/keycloak

# Enable health and metrics
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true 

# Configure DB vendor
ENV KC_DB=mariadb

RUN /opt/keycloak/bin/kc.sh build


FROM quay.io/keycloak/keycloak:24.0 

COPY --from=ubi-micro-build /mnt/rootfs /
COPY --from=builder /opt/keycloak /opt/keycloak

# To prevent the "Local access required" view
ENV KEYCLOAK_ADMIN=admin 
ENV KEYCLOAK_ADMIN_PASSWORD=admin

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl --head -fsS http://localhost:8080/health/ready

ENTRYPOINT [ "/opt/keycloak/bin/kc.sh" ]
CMD [ "start", "--optimized", "--proxy-headers=xforwarded", "--http-enabled=true", "--hostname-strict=false" ]

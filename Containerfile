ARG BASE_IMAGE="osixia/baseimage:alpine-2.1.0"
FROM ${BASE_IMAGE}

ARG IMAGE="osixia/openldap:develop"
ENV CONTAINER_IMAGE=${IMAGE}

# Add OpenLDAP group and user
ARG OPENLDAP_GROUP_GID=911
ARG OPENLDAP_USER_UID=911

RUN container groups add "${OPENLDAP_GROUP_GID}" ldap \
    && container users add "${OPENLDAP_USER_UID}" ldap --group-id "${OPENLDAP_GROUP_GID}" --group-name ldap

# Set OpenLDAP version
ARG OPENLDAP_VERSION=2.6.15-r0
ENV OPENLDAP_VERSION="${OPENLDAP_VERSION}"

# Install all OpenLDAP packages
RUN container packages install --update --clean \
    openldap-backend-all="${OPENLDAP_VERSION}" \
    openldap-clients="${OPENLDAP_VERSION}" \
    openldap-overlay-all="${OPENLDAP_VERSION}" \
    openldap-passwd-argon2="${OPENLDAP_VERSION}" \
    openldap-passwd-pbkdf2="${OPENLDAP_VERSION}" \
    openldap-passwd-sha2="${OPENLDAP_VERSION}" \
    openldap="${OPENLDAP_VERSION}"

# Install some of my troubleshooting tools
RUN container packages install --update --clean \
    openssl \
    curl

COPY ldap.conf /etc/openldap/ldap.conf

COPY --chown=911:911 lanathome.org-root.crt /container/services/openldap/assets/certs/lanathome.org-root.crt
COPY --chown=911:911 ldap.lanathome.org.crt /container/services/openldap/assets/certs/ldap.lanathome.org.crt
COPY --chown=911:911 ldap.lanathome.org.key /container/services/openldap/assets/certs/ldap.lanathome.org.key


COPY lanathome.org-root.crt /usr/local/share/ca-certificates/lanathome.org-root.crt

RUN update-ca-certificates

COPY services /container/services

RUN container services install \
    && container services link

COPY environment /container/environment

USER ldap

EXPOSE 3890 6360
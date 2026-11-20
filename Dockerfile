ARG BASE_IMAGE="osixia/baseimage:alpine-2.1.0"
FROM ${BASE_IMAGE}

ARG IMAGE="osixia/openldap:develop"
ENV CONTAINER_IMAGE=${IMAGE}

# Add OpenLDAP group and user
ARG OPENLDAP_GROUP_GID=911
ARG OPENLDAP_USER_UID=911

# Install ca-certificates
RUN apk add --no-cache ca-certificates


# Install curl
RUN apk add --no-cache curl

# Install openssl
RUN apk add --no-cache openssl

# Copy my root CA certificate into the system directory
COPY ./lanathome.org-root.crt \
      /usr/local/share/ca-certificates/lanathome.org-root.crt

# Copy the ldap.lanathome.org CA certificate
COPY ./ldap.lanathome.org.crt \
      /usr/local/share/ca-certificates/ldap.lanathome.org.crt

# Copy the ldap.lanathome.org KEY certificate
COPY ./ldap.lanathome.org.key \
      /usr/local/share/ca-certificates/ldap.lanathome.org.key

# Update the trust store
RUN update-ca-certificates

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

COPY services /container/services

RUN container services install \
    && container services link

COPY environment /container/environment

COPY ./ldap.conf /etc/openldap/ldap.conf

USER ldap

EXPOSE 3890 6360

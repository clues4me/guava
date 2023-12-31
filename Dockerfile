#FROM library/tomcat:9-jre11-openjdk-bullseye
#Update Tomcat OS to Bookworm
#PostgreSQL revert back to 9.6 to provide backward compatibility with jwetzell version

FROM library/tomcat:9.0.80-jdk21-openjdk-bookworm

ENV ARCH=amd64 \
    GUAC_VER=1.5.3 \
    GUACAMOLE_HOME=/app/guacamole \
    PG_MAJOR=9.6 \
    PGDATA=/config/postgres \
    POSTGRES_USER=guacamole \
    POSTGRES_DB=guacamole_db

#Add new arg for new s6 runtime
ARG S6_OVERLAY_VERSION=3.1.5.0

# Add Postgres Repository
RUN apt-get update && apt-get install -y curl ca-certificates gnupg
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg > /dev/null
RUN echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" >> /etc/apt/sources.list.d/pgdg.list

# Install dependencies
RUN apt-get update \
 && apt-get install -y \
    libcairo2-dev libjpeg62-turbo-dev libpng-dev libavformat-dev libwebsockets-dev\
    libossp-uuid-dev libavcodec-dev libavutil-dev \
    libswscale-dev freerdp2-dev libfreerdp-client2-2 libpango1.0-dev \
    libssh2-1-dev libtelnet-dev libvncserver-dev \
    libpulse-dev libssl-dev libvorbis-dev libwebp-dev libwebsockets-dev \
    ghostscript xz-utils build-essential postgresql-${PG_MAJOR} \
  && rm -rf /var/lib/apt/lists/*


# Apply the s6-overlay using s6 version 3.1.5.0

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz

RUN mkdir -p ${GUACAMOLE_HOME} \
    ${GUACAMOLE_HOME}/lib \
    ${GUACAMOLE_HOME}/extensions

WORKDIR ${GUACAMOLE_HOME}

# Link FreeRDP to where guac expects it to be
RUN ln -s /usr/local/lib/freerdp /usr/lib/x86_64-linux-gnu/freerdp || exit 0

RUN echo $PATH

# Install patched guacamole-server for new debian bookworm

RUN curl -SLO "https://github.com/clues4me/guava/raw/master/guacamole-server-1.5.3.tar.gz" \
 && tar -xzf guacamole-server-${GUAC_VER}.tar.gz \
 && cd guacamole-server-${GUAC_VER} \
 && ./configure --enable-allow-freerdp-snapshots \
 && make -j$(getconf _NPROCESSORS_ONLN) \
 && make install \
 && cd .. \
 && rm -rf guacamole-server-${GUAC_VER}.tar.gz guacamole-server-${GUAC_VER} \
 && ldconfig


# Create directory for extensions
RUN mkdir ${GUACAMOLE_HOME}/extensions-available

# Install guacamole-client and postgres auth adapter
RUN set -x \
  && rm -rf ${CATALINA_HOME}/webapps/ROOT \
  && curl -SLo ${CATALINA_HOME}/webapps/ROOT.war "https://archive.apache.org/dist/guacamole/${GUAC_VER}/binary/guacamole-${GUAC_VER}.war" \
  && curl -SLo ${GUACAMOLE_HOME}/lib/postgresql-42.1.4.jar "https://jdbc.postgresql.org/download/postgresql-42.2.24.jar" \
  && curl -SLO "https://archive.apache.org/dist/guacamole/${GUAC_VER}/binary/guacamole-auth-jdbc-${GUAC_VER}.tar.gz" \
  && tar -xzf guacamole-auth-jdbc-${GUAC_VER}.tar.gz \
  && cp guacamole-auth-jdbc-${GUAC_VER}/postgresql/guacamole-auth-jdbc-postgresql-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions/ \
  && cp guacamole-auth-jdbc-${GUAC_VER}/postgresql/guacamole-auth-jdbc-postgresql-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  && cp guacamole-auth-jdbc-${GUAC_VER}/mysql/guacamole-auth-jdbc-mysql-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  && cp guacamole-auth-jdbc-${GUAC_VER}/sqlserver/guacamole-auth-jdbc-sqlserver-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  && cp -R guacamole-auth-jdbc-${GUAC_VER}/postgresql/schema ${GUACAMOLE_HOME}/ \
  && rm -rf guacamole-auth-jdbc-${GUAC_VER} guacamole-auth-jdbc-${GUAC_VER}.tar.gz

# add auth-sso to available extensions folder structur differs from other extensions
RUN set -xe \
  && echo "https://archive.apache.org/dist/guacamole/${GUAC_VER}/binary/guacamole-auth-sso-${GUAC_VER}.tar.gz" \
  && curl -SLO "https://archive.apache.org/dist/guacamole/${GUAC_VER}/binary/guacamole-auth-sso-${GUAC_VER}.tar.gz" \
  && tar -xzf guacamole-auth-sso-${GUAC_VER}.tar.gz \
  && cp guacamole-auth-sso-${GUAC_VER}/cas/guacamole-auth-sso-cas-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  && cp guacamole-auth-sso-${GUAC_VER}/openid/guacamole-auth-sso-openid-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  && cp guacamole-auth-sso-${GUAC_VER}/saml/guacamole-auth-sso-saml-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  && rm -rf guacamole-auth-sso-${GUAC_VER} guacamole-auth-sso-${GUAC_VER}.tar.gz

# add vault to available extensions folder structur differs from other extensions
RUN set -xe \
  && echo "https://archive.apache.org/dist/guacamole/${GUAC_VER}/binary/guacamole-vault-${GUAC_VER}.tar.gz" \
  && curl -SLO "https://archive.apache.org/dist/guacamole/${GUAC_VER}/binary/guacamole-vault-${GUAC_VER}.tar.gz" \
  && tar -xzf guacamole-vault-${GUAC_VER}.tar.gz \
  && cp guacamole-vault-${GUAC_VER}/ksm/guacamole-vault-ksm-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  && rm -rf guacamole-vault-${GUAC_VER} guacamole-vault-${GUAC_VER}.tar.gz

# Add optional extensions
RUN set -xe \
  && for i in auth-duo auth-header auth-json auth-ldap auth-quickconnect auth-totp history-recording-storage; do \
    echo "https://archive.apache.org/dist/guacamole/${GUAC_VER}/binary/guacamole-${i}-${GUAC_VER}.tar.gz" \
    && curl -SLO "https://archive.apache.org/dist/guacamole/${GUAC_VER}/binary/guacamole-${i}-${GUAC_VER}.tar.gz" \
    && tar -xzf guacamole-${i}-${GUAC_VER}.tar.gz \
    && cp guacamole-${i}-${GUAC_VER}/guacamole-${i}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
    && rm -rf guacamole-${i}-${GUAC_VER} guacamole-${i}-${GUAC_VER}.tar.gz \
  ;done


ENV PATH=/usr/lib/postgresql/${PG_MAJOR}/bin:$PATH
ENV GUACAMOLE_HOME=/config/guacamole

WORKDIR /config

COPY root /

EXPOSE 8080

ENTRYPOINT [ "/init" ]
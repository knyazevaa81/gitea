#Build stage
FROM golang:1.19-bullseye AS build-env

ARG GOPROXY
ENV GOPROXY ${GOPROXY:-direct}

ARG GITEA_VERSION
ARG TAGS="sqlite sqlite_unlock_notify"
ENV TAGS "bindata timetzdata $TAGS"
ARG CGO_EXTRA_CFLAGS

#Build deps

RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get -y install gcc g++ libc-dev git nodejs make sqlite3 curl
RUN npm install -g npm@latest

#Setup repo
COPY . ${GOPATH}/src/code.gitea.io/gitea
WORKDIR ${GOPATH}/src/code.gitea.io/gitea

#Checkout version if set
RUN make clean-all build

# Begin env-to-ini build
RUN go build contrib/environment-to-ini/environment-to-ini.go

FROM debian:bullseye-slim
LABEL maintainer="maintainers@gitea.io"

RUN apt-get update && apt-get -qy dist-upgrade && apt-get -qy --no-install-recommends install \
    bash \
    ca-certificates \
    curl \
    gettext \
    git \
    libpam-modules \
    openssh-server \
    s6 \
    sqlite3 \
    gosu \
    sudo \
    gnupg \
    s6 \
    nodejs \
    asciidoctor libfreetype6 python3-pip pandoc

RUN groupadd -r -g 1000 git
RUN useradd -r -M -d /data/git -s /bin/bash -u 1000 -g git git
RUN echo "git:*" | chpasswd -e
RUN mkdir -p /var/run/sshd

VOLUME ["/data"]

COPY docker/root /

COPY --from=build-env /go/src/code.gitea.io/gitea/gitea /app/gitea/gitea
COPY --from=build-env /go/src/code.gitea.io/gitea/environment-to-ini /usr/bin/

RUN chmod 755 /usr/bin/entrypoint /usr/local/bin/gitea /usr/bin/environment-to-ini /etc/s6/gitea/* /etc/s6/openssh/* /etc/s6/.s6-svscan/* /etc/s6/gitea/* /etc/s6/openssh/* /etc/s6/.s6-svscan/* /app/gitea/gitea

RUN pip3 install --upgrade pip && \
pip3 install -U setuptools && \
pip3 install --ignore-installed pyzmq && \
pip3 install -U jupyter docutils nbconvert

RUN apt clean

ENV USER git
ENV GITEA_CUSTOM /data/gitea

EXPOSE 22 3000
ENTRYPOINT ["/usr/bin/entrypoint"]
CMD ["/usr/bin/s6-svscan", "/etc/s6"]

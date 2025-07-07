FROM mcr.microsoft.com/devcontainers/base:0-alpine-3.20
# FROM mcr.microsoft.com/devcontainers/base:0-alpine-3.21

COPY host-ca-certificates.crt /tmp/host-ca-certificates.crt
RUN cat /tmp/host-ca-certificates.crt >> /etc/ssl/certs/ca-certificates.crt
RUN csplit -f /usr/local/share/ca-certificates/host-ca-certificate- -b '%02d.pem' -z -s /tmp/host-ca-certificates.crt '/-----BEGIN CERTIFICATE-----/' '{*}'
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Avoiding OpenSSH >8.8 for compatibility for now: https://github.com/microsoft/vscode-remote-release/issues/7482
RUN echo "@old https://dl-cdn.alpinelinux.org/alpine/v3.15/main" >> /etc/apk/repositories
# RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

RUN apk add --no-cache \
	git-lfs \
	nodejs \
	python3 \
	npm \
	make \
	g++ \
	docker-cli \
	docker-cli-buildx \
	docker-cli-compose \
	openssh-client-default@old \
	;

# Create buildkit builder that respects proxy settings
# This command runs on container start, not at build time where no docker.socket is available
# Use the entrypoint script as a workaround to create the builder
RUN cat <<EOF > /usr/local/bin/entrypoint.sh
#!/bin/sh
set -e
echo "Creating a buildx builder that respects proxy settings..."
docker buildx create --driver-opt env.http_proxy="$HTTP_PROXY" --driver-opt env.https_proxy="$HTTPS_PROXY" --name builder_with_proxy

echo "Executing the passed command... $(echo \$@)"
exec "\$@"
EOF

# Make the script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Use that builder per default
ENV BUILDX_BUILDER=builder_with_proxy

RUN npm config set cafile /etc/ssl/certs/ca-certificates.crt && cd && npm i node-pty || echo "Continuing without node-pty."

COPY .vscode-remote-containers /root/.vscode-remote-containers


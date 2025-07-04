# Build stage
FROM docker.io/library/node:20-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  python3 \
  make \
  g++ \
  git \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy all source files (including .git if needed)
COPY . .

# Build packages
RUN npm ci
RUN npm run build:packages

# Create package tarballs
RUN cd packages/core && npm pack --pack-destination=dist/
RUN cd packages/cli && npm pack --pack-destination=dist/

# Runtime stage
FROM docker.io/library/node:20-slim

ARG SANDBOX_NAME="gemini-cli-sandbox"
ARG CLI_VERSION_ARG
ENV SANDBOX="$SANDBOX_NAME"
ENV CLI_VERSION=$CLI_VERSION_ARG

# install minimal set of packages, then clean up
RUN apt-get update && apt-get install -y --no-install-recommends \
  python3 \
  make \
  g++ \
  man-db \
  curl \
  dnsutils \
  less \
  jq \
  bc \
  gh \
  git \
  unzip \
  rsync \
  ripgrep \
  procps \
  psmisc \
  lsof \
  socat \
  ca-certificates \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# set up npm global package folder under /usr/local/share
# give it to non-root user node, already set up in base image
RUN mkdir -p /usr/local/share/npm-global \
  && chown -R node:node /usr/local/share/npm-global
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# switch to non-root user node
USER node

# Copy built packages from builder stage
COPY --from=builder /app/packages/cli/dist/google-gemini-cli-*.tgz /usr/local/share/npm-global/gemini-cli.tgz
COPY --from=builder /app/packages/core/dist/google-gemini-cli-core-*.tgz /usr/local/share/npm-global/gemini-core.tgz

# install gemini-cli and clean up
RUN npm install -g /usr/local/share/npm-global/gemini-cli.tgz /usr/local/share/npm-global/gemini-core.tgz \
  && npm cache clean --force \
  && rm -f /usr/local/share/npm-global/gemini-{cli,core}.tgz

# default entrypoint when none specified
CMD ["gemini"]

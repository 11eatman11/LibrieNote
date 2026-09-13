ARG NUSQLITE3_DIR="/usr/local/lib/nusqlite3"
ARG NUSQLITE3_PATH="${NUSQLITE3_DIR}/libnusqlite3.so"

### STAGE 1: Build client frontend ###
FROM node:20-alpine AS build-client
WORKDIR /client
COPY client/package*.json ./
RUN npm ci
COPY client/ ./
RUN npm run generate

### STAGE 2: Build server dependencies ###
FROM node:20-alpine AS build-server

ARG NUSQLITE3_DIR
ARG TARGETPLATFORM

ENV NODE_ENV=production

RUN apk add --no-cache --update \
  curl \
  make \
  python3 \
  g++ \
  unzip

WORKDIR /server
COPY index.js package* /server/
COPY /server /server/server

RUN ARCH=$(uname -m) && \
  if [ "$ARCH" = "x86_64" ] || [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    curl -L -o /tmp/library.zip "https://github.com/mikiher/nunicode-sqlite/releases/download/v1.2/libnusqlite3-linux-musl-x64.zip" ; \
  elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ] || [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    curl -L -o /tmp/library.zip "https://github.com/mikiher/nunicode-sqlite/releases/download/v1.2/libnusqlite3-linux-musl-arm64.zip" ; \
  else \
    echo "Unsupported platform: $ARCH / $TARGETPLATFORM" && exit 1 ; \
  fi && \
  mkdir -p $NUSQLITE3_DIR && \
  unzip /tmp/library.zip -d $NUSQLITE3_DIR && \
  rm /tmp/library.zip

RUN npm ci --only=production

### STAGE 3: Create minimal runtime image ###
FROM node:20-alpine

ARG NUSQLITE3_DIR
ARG NUSQLITE3_PATH

# Install only runtime dependencies
RUN apk add --no-cache --update \
  tzdata \
  ffmpeg \
  tini

WORKDIR /app

# Copy compiled frontend and server from build stages
COPY --from=build-client /client/dist /app/client/dist
COPY --from=build-server /server /app
COPY --from=build-server ${NUSQLITE3_PATH} ${NUSQLITE3_PATH}

EXPOSE 80

ENV PORT=80
ENV NODE_ENV=production
ENV CONFIG_PATH="/config"
ENV METADATA_PATH="/metadata"
ENV SOURCE="docker"
ENV NUSQLITE3_DIR=${NUSQLITE3_DIR}
ENV NUSQLITE3_PATH=${NUSQLITE3_PATH}

ENTRYPOINT ["tini", "--"]
CMD ["node", "index.js"]

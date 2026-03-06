ARG CONTAINER_VERSION=13.351.0
ARG FOUNDRY_RELEASE_URL
ARG FOUNDRY_VERSION=13.351
ARG NODE_IMAGE_VERSION=22-bookworm-slim

FROM public.ecr.aws/docker/library/node:${NODE_IMAGE_VERSION} AS compile-typescript-stage

WORKDIR /root

COPY \
  package.json \
  package-lock.json \
  tsconfig.json \
  ./
RUN npm install && npm install --global typescript
COPY /src/*.ts src/
RUN tsc
RUN grep -l "#!" dist/*.js | xargs chmod a+x

FROM public.ecr.aws/docker/library/node:${NODE_IMAGE_VERSION} AS optional-release-stage

# This stage is optional and will only be executed if the FOUNDRY_RELEASE_URL or
# FOUNDRY_USERNAME and FOUNDRY_PASSWORD secrets are provided.  It will download
# and extract the Foundry VTT release for inclusion in the final stage.

ARG FOUNDRY_RELEASE_URL
ARG FOUNDRY_VERSION
ENV ARCHIVE="foundryvtt-${FOUNDRY_VERSION}.zip"

WORKDIR /root
COPY --from=compile-typescript-stage \
  /root/package.json \
  /root/package-lock.json \
  /root/dist/authenticate.js \
  /root/dist/get_release_url.js \
  /root/dist/logging.js \
  ./
# .placeholder file to mitigate https://github.com/moby/moby/issues/37965
RUN mkdir dist && touch dist/.placeholder

RUN \
  npm install && \
  DOWNLOAD_URL="${FOUNDRY_RELEASE_URL}"; \
  apt-get update && apt-get install -y unzip wget && \
  wget -O ${ARCHIVE} "${DOWNLOAD_URL}" && \
  mkdir -p "dist/resources/app" && \
  unzip -d "dist/resources/app" ${ARCHIVE};

FROM public.ecr.aws/docker/library/node:${NODE_IMAGE_VERSION} AS final-stage

ARG CONTAINER_VERSION
ARG FOUNDRY_VERSION
ARG TARGETPLATFORM

LABEL com.foundryvtt.version=${FOUNDRY_VERSION}
LABEL org.opencontainers.image.authors="markf+github@geekpad.com"
LABEL org.opencontainers.image.vendor="Geekpad"

ENV FOUNDRY_VERSION=${FOUNDRY_VERSION}
ENV HOME=/home/node

WORKDIR $HOME

COPY --from=optional-release-stage /root/dist/ .
COPY --from=compile-typescript-stage /root/dist/ .
COPY --chown=node:node \
  package.json \
  package-lock.json \
  src/check_health.sh \
  src/entrypoint.sh \
  src/launcher.sh \
  src/logging.sh \
  ./
RUN mkdir -p resources /data \
  && chmod a+rwx resources /data \
  && apt-get update && apt-get install -y \
  curl \
  file \
  jq \
  patch \
  sed \
  tzdata \
  unzip \
  && rm -rf /var/lib/apt/lists/* \
  && npm install && echo ${CONTAINER_VERSION} > image_version.txt

VOLUME ["/data"]
EXPOSE 30000/tcp

USER node
RUN find /home/node -maxdepth 1 -type f -name "*.sh" -exec sed -i 's/\r$//' {} \;

ENTRYPOINT ["./entrypoint.sh"]
CMD ["resources/app/main.mjs", "--port=30000", "--headless", "--noupdate",\
  "--dataPath=/data"]
HEALTHCHECK --start-period=3m --interval=30s --timeout=5s CMD ./check_health.sh
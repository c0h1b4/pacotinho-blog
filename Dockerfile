# syntax=docker/dockerfile:1.7@sha256:a57df69d0ea827fb7266491f2813635de6f17269be881f696fbfdf2d83dda33e

ARG SOURCE_DATE_EPOCH

FROM node:24.13.0-bookworm-slim@sha256:46feb5752989c05b8606e6323fbbc3db667d14ade1c24f5d0d44d9ca9909d607 AS base
ENV PNPM_HOME=/pnpm
ENV PATH="${PNPM_HOME}:${PATH}"
RUN corepack enable && corepack prepare pnpm@10.11.0 --activate

FROM base AS dependencies
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile --ignore-scripts

FROM base AS builder
ARG OCI_REVISION
ARG SOURCE_DATE_EPOCH
ENV PACOTINHO_SOURCE_REVISION="${OCI_REVISION}" \
    SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}"
WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN mkdir -p public \
    && pnpm run postinstall \
    && pnpm run build

FROM node:24.13.0-bookworm-slim@sha256:46feb5752989c05b8606e6323fbbc3db667d14ade1c24f5d0d44d9ca9909d607 AS runner
ARG OCI_REVISION
ARG OCI_VERSION
ARG OCI_CREATED
ARG OCI_SOURCE_COMMITTED_AT
ARG OCI_TREE
ARG OCI_BUILD_ID
ARG SOURCE_DATE_EPOCH
LABEL org.opencontainers.image.source="https://github.com/c0h1b4/pacotinho-blog" \
      org.opencontainers.image.revision="${OCI_REVISION}" \
      org.opencontainers.image.version="${OCI_VERSION}" \
      org.opencontainers.image.created="${OCI_CREATED}" \
      io.pacotinho.source.committed-at="${OCI_SOURCE_COMMITTED_AT}" \
      io.pacotinho.source.tree="${OCI_TREE}" \
      io.pacotinho.build.identity="${OCI_BUILD_ID}"
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
    PORT=3002 \
    HOSTNAME=0.0.0.0
COPY --from=builder --chown=node:node /app/public ./public
COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static
USER node
EXPOSE 3002
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:3002/blog').then(response=>process.exit(response.ok?0:1)).catch(()=>process.exit(1))"]
CMD ["node", "server.js"]

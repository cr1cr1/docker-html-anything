# syntax=docker/dockerfile:1
FROM node:22-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates python3 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/nexu-io/html-anything.git /app/html-anything
WORKDIR /app/html-anything
RUN npm install -g pnpm && pnpm install
# Patch agent invocation for detailed container logging (stdout, stderr, start, exit)
COPY scripts/patch-invoke-logging.py /tmp/patch-invoke-logging.py
RUN python3 /tmp/patch-invoke-logging.py
# Copy h2c custom server into the Next.js workspace
COPY scripts/server.ts /app/html-anything/next/server.ts
RUN NODE_ENV=production pnpm -F @html-anything/next build

FROM node:22-slim AS runner
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g pnpm
USER node
ENV PATH="/home/node/.local/share/mise/shims:/home/node/.local/bin:${PATH}"
RUN curl https://mise.run | sh
COPY --chown=node:node --from=builder /app/html-anything/ /app/html-anything/
# Copy mise config and install opencode + pi
WORKDIR /app/html-anything
COPY --chown=node:node mise.toml /app/html-anything/mise.toml
RUN mise trust /app/html-anything/mise.toml && mise up
EXPOSE 3000
ENV HOSTNAME=0.0.0.0
ENV PORT=3000
WORKDIR /app/html-anything/next
# Run the custom server instead of `next start`
CMD ["node", "server.ts"]

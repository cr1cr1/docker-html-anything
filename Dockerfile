# syntax=docker/dockerfile:1
FROM oven/bun:1-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/nexu-io/html-anything.git /app/html-anything
WORKDIR /app/html-anything
RUN bun install
RUN NODE_ENV=production bun -F @html-anything/next build
FROM oven/bun:1-slim AS runner
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

USER bun
ENV PATH="/home/bun/.local/share/mise/shims:/home/bun/.local/bin:${PATH}"
WORKDIR /app/html-anything

RUN curl https://mise.run | sh

# Copy full repo from builder (source + node_modules required for server)
COPY --chown=bun:bun --from=builder /app/html-anything/ /app/html-anything/
# Copy mise config and install opencode + pi
COPY --chown=bun:bun mise.toml /app/html-anything/mise.toml
RUN mise trust /app/html-anything/mise.toml && mise up
EXPOSE 3000
ENV PORT=3000
CMD ["bun", "-F", "@html-anything/next", "start", "--", "--hostname", "0.0.0.0"]

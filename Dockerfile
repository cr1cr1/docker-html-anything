# syntax=docker/dockerfile:1
FROM oven/bun:1-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/nexu-io/html-anything.git /app/html-anything
WORKDIR /app/html-anything
RUN bun install

FROM oven/bun:1-slim AS runner
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd -g 1000 appgroup \
 && useradd -u 1000 -g appgroup -m -s /bin/bash appuser

USER appuser
ENV PATH="/home/appuser/.local/share/mise/shims:/home/appuser/.local/bin:${PATH}"
WORKDIR /app/html-anything

RUN curl https://mise.run | sh

# Copy full repo from builder (source + node_modules required for dev server)
COPY --chown=appuser:appgroup --from=builder /app/html-anything/ /app/html-anything/
# Copy mise config and install opencode + pi
COPY --chown=appuser:appgroup mise.toml /app/html-anything/mise.toml
RUN mise trust /app/html-anything/mise.toml && mise up
EXPOSE 3000
ENV PORT=3000
CMD ["bun", "-F", "@html-anything/next", "dev", "--", "--hostname", "0.0.0.0"]
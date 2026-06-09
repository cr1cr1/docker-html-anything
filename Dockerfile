# syntax=docker/dockerfile:1
FROM oven/bun:1-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 https://github.com/nexu-io/html-anything.git /app/html-anything
WORKDIR /app/html-anything
RUN bun install

FROM oven/bun:1-slim AS runner
WORKDIR /app/html-anything
# Install mise
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN curl https://mise.run | sh
ENV PATH="/root/.local/share/mise/shims:/root/.local/bin:${PATH}"
# Copy full repo from builder (source + node_modules required for dev server)
COPY --from=builder /app/html-anything/ /app/html-anything/
# Copy mise config and install opencode + pi
COPY mise.toml /app/html-anything/mise.toml
RUN mise trust /app/html-anything/mise.toml && mise up
EXPOSE 3000
ENV PORT=3000
CMD ["bun", "-F", "@html-anything/next", "dev", "--", "--hostname", "0.0.0.0"]

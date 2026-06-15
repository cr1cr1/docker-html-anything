# docker-html-anything

Daily container build for the [`html-anything`](https://github.com/nexu-io/html-anything) Next.js application, packaged with Bun and mise-managed developer tools.

## What it does

- Clones `nexu-io/html-anything` into the image at build time
- Installs dependencies with Bun
- Bakes in `opencode` and `pi` via mise
- Runs the Next.js dev server on `0.0.0.0:3000`

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build (builder + runner) |
| `mise.toml` | Mise tool versions (`opencode`, `pi`) |
| `.dockerignore` | Keeps the build context small |
| `.github/workflows/daily-container.yml` | Daily cron + manual trigger workflow |
| `mise-tasks/build` | Build the image locally |
| `mise-tasks/test` | Build, run, health-check, and verify tools |
| `mise-tasks/run` | Run the container locally for development |
| `mise-tasks/stop` | Stop and remove the local container |

## Local development

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [mise](https://mise.jdx.dev/) (optional, for task runner convenience)

### Tasks

Scripts in `mise-tasks/` are executable shell scripts. Run them directly or via `mise run <task>`.

> **Note:** `mise run` auto-installs tools listed in `mise.toml` before executing tasks. If you hit GitHub rate limits, set a `GITHUB_TOKEN` or run the scripts directly with `./mise-tasks/<task>`.

#### Build

```bash
./mise-tasks/build
```

Or with Docker directly:

```bash
docker build -t html-anything:latest .
```

#### Test (build + run + verify + cleanup)

```bash
./mise-tasks/test
```

This will:
1. Build the image
2. Start a container on port `3007`
3. Wait for the app to respond
4. Verify `opencode` and `pi` are available inside the container
5. Clean up

Override the port or container name:

```bash
PORT=3008 NAME=my-test ./mise-tasks/test
```

#### Run for local development

```bash
./mise-tasks/run
```

Open http://localhost:3007. Stop with:

```bash
./mise-tasks/stop
```

#### Using `mise run`

If you prefer `mise run`:

```bash
mise run build
mise run test
mise run run
mise run stop
```

### Manual Docker commands

```bash
# Build
docker build -t html-anything:latest .

# Run
docker run -d --name ha -p 3007:3000 html-anything:latest

# Health-check
curl -sf http://localhost:3007

# Verify tools
docker exec ha opencode --version
docker exec ha pi --version

# Stop and remove
docker stop ha && docker rm ha
```

## GitHub Actions

The workflow `.github/workflows/daily-container.yml` runs:

- **Daily** at midnight UTC (`0 0 * * *`)
- **On demand** via `workflow_dispatch`

Steps:
1. Build the image
2. Start a container and health-check on `:3000`
3. Verify `opencode` and `pi` are present
4. Push `latest` and `YYYYMMDD` tags to GHCR

## Configuration

### Ports

The container exposes port `3000`. Map it to any host port:

```bash
docker run -d -p 3007:3000 html-anything:latest
```

### Mise tools

Edit `mise.toml` to add or change tools:

```toml
[tools]
opencode = "latest"
pi = "latest"
```

Then rebuild the image.

### Cloud model configuration

Both `opencode` and `pi` ship with built-in providers (Anthropic, OpenAI, Google Gemini, AWS Bedrock, Azure OpenAI) and support custom OpenAI-compatible endpoints. API keys should **never** be hardcoded in config files.

#### opencode

opencode reads `~/.opencode/opencode.json` (global) or `./opencode.json` (project-local). Use the `{env:VAR_NAME}` syntax for secrets:

```bash
# Set keys in your shell (or .env file)
export ANTHROPIC_API_KEY=sk-ant-...
export OPENAI_API_KEY=sk-...
export MOONSHOT_API_KEY=sk-moonshot-...
export ZAI_API_KEY=...
```

See [opencode.jsonc](kubernetes/opencode.jsonc) for an example with multiple providers. Use the `{env:VAR_NAME}` syntax for secrets:

Switch models interactively with `/models` or via CLI:

```bash
opencode run "Explain this code" --model anthropic/claude-sonnet-4-6
```

To use opencode inside the container, mount your config and pass env vars:

```bash
docker run -d \
  --name ha \
  -p 3007:3000 \
  -v "$HOME/.opencode:/home/bun/.opencode" \
  -e ANTHROPIC_API_KEY \
  -e OPENAI_API_KEY \
  -e MOONSHOT_API_KEY \
  -e ZAI_API_KEY \
  html-anything:latest
```

#### pi

pi reads `~/.pi/agent/models.json`. See [models.json](kubernetes/models.json) for an example with multiple providers. Use the `{env:VAR_NAME}` syntax for secrets:

To use pi inside the container, mount your config and pass env vars:

```bash
docker run -d \
  --name ha \
  -p 3007:3000 \
  -v "$HOME/.pi:/home/bun/.pi" \
  -e ANTHROPIC_API_KEY \
  -e OPENAI_API_KEY \
  -e MOONSHOT_API_KEY \
  -e ZAI_API_KEY \
  html-anything:latest
```

For local models (Ollama, LM Studio, llama.cpp), use the OpenAI-compatible adapter. See the [pi discussions](https://github.com/earendil-works/pi/discussions) and [opencode docs](https://opencode.ai/docs) for provider-specific details.

## Notes

- Uses `oven/bun:1-slim` (Debian-based) because mise-installed GitHub release binaries are linked against glibc, not musl.
- The `--hostname 0.0.0.0` flag is required; without it Next.js binds to `localhost` inside the container and is unreachable from the host.
- Container logs include `[harness]` prefixed startup diagnostics (tool versions and PATH) and per-conversion harness stdout/stderr output.

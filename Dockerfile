# STEP 1: Build Assets
FROM node:22-alpine AS build_assets

WORKDIR /app

# Copy asset files and install dependencies
COPY apps/dot_prompt_server/assets/package*.json ./apps/dot_prompt_server/assets/
RUN cd apps/dot_prompt_server/assets && npm ci

# Copy all assets and build
COPY apps/dot_prompt_server/assets/ ./apps/dot_prompt_server/assets/
RUN cd apps/dot_prompt_server/assets && npm run build

# STEP 2: Build App
FROM elixir:1.18-alpine AS build_app

RUN apk add --no-cache build-base git

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
COPY apps/dot_prompt/mix.exs ./apps/dot_prompt/
COPY apps/dot_prompt_server/mix.exs ./apps/dot_prompt_server/

RUN mix deps.get --only prod
RUN mix deps.compile

COPY config/ ./config/
COPY apps/ ./apps/

# Assets are optional for headless deployment
# COPY --from=build_assets /app/apps/dot_prompt_server/priv/static/ ./apps/dot_prompt_server/priv/static/

RUN mix do compile, release --overwrite

# STEP 3: Final Runtime Image
FROM alpine:3.19

# Install runtime dependencies and create a non-root user
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++ \
    libgcc \
    ca-certificates \
    tzdata && \
    addgroup -S elixir && \
    adduser -S elixir -G elixir

WORKDIR /app
RUN chown -R elixir:elixir /app

USER elixir

# Copy the release from build_app stage
COPY --from=build_app --chown=elixir:elixir /app/_build/prod/rel/dot_prompt_umbrella ./

# Runtime Environment Variables
ENV PORT=4000
EXPOSE 4000

# Entrypoint and Command
ENTRYPOINT ["/app/bin/dot_prompt_umbrella"]
CMD ["start"]

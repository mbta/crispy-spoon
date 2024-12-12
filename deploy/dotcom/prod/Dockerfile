###
# Three-stage Dockerfile
###

# 1.) Get the Elixir dependencies within an Elixir container
FROM hexpm/elixir:1.17.0-erlang-27.0-debian-buster-20240513-slim as elixir-builder

ENV LANG="C.UTF-8" MIX_ENV="prod"

WORKDIR /root

# Debian dependencies
RUN apt-get update --allow-releaseinfo-change && apt-get install -y curl git make build-essential

# Configure Git to use HTTPS in order to avoid issues with the internal MBTA network
RUN git config --global url.https://github.com/.insteadOf git://github.com/

# Install Hex+Rebar
RUN mix local.hex --force && \
	mix local.rebar --force

ADD . .

RUN mix deps.get --only prod

# 2) Build the frontend assets within a node.js container instead of installing node/npm
FROM node:18.17.1-buster as assets-builder

# Stop cypress from downloading it's massive binary.
ENV CYPRESS_INSTALL_BINARY=0

ARG SENTRY_DSN=""

# copy in Elixir deps required to build node modules for Phoenix
COPY --from=elixir-builder /root/deps /root/deps
# copy in static assets
ADD ./priv/static /root/priv/static
ADD ./assets /root/assets

WORKDIR /root/assets

RUN npm run install:ci

# required so that Tailwind styles used in Elixir templates are built
COPY ./lib/dotcom_web/ /root/lib/dotcom_web
# Compile JS/CSS to priv/static
RUN npm run webpack:build -- --env SENTRY_DSN=$SENTRY_DSN
# Create react_renderer/dist/app.js
RUN npm run webpack:build:react

# 3) now, build the application back in the Elixir container
FROM elixir-builder as app-builder

WORKDIR /root

# Add frontend assets, required by phx.digest
COPY --from=assets-builder /root/priv/static ./priv/static

# package source code for Sentry
RUN mix sentry.package_source_code

# re-compile the application after the assets are copied, since some of them
# are built into the application (SVG icons)
RUN mix do compile, phx.digest
RUN mix sentry.package_source_code
RUN mix release

# 4) Use the nodejs container for the runtime environment
# Since we're server-rendering the React templates, we need a Javascript engine running inside the container.
FROM node:18.17.1-buster-slim

# Set exposed ports
EXPOSE 4000

ENV PORT=4000 MIX_ENV="prod" PHX_SERVER=true TERM=xterm LANG="C.UTF-8" REPLACE_OS_VARS=true

# erlang-crypto requires system library libssl1.1
RUN apt-get update && apt-get install -y --no-install-recommends \
	libssl1.1 libsctp1 curl \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /root

COPY --from=app-builder /root/_build/prod/rel /root/rel
COPY --from=assets-builder /root/react_renderer/dist/app.js /root/rel/dotcom/app.js

RUN mkdir /root/work

WORKDIR /root/work

# run the application
CMD ["/root/rel/dotcom/bin/dotcom", "start"]

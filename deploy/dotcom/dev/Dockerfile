FROM hexpm/elixir:1.17.0-erlang-27.0-debian-buster-20240513-slim

RUN apt-get update && apt-get install -y curl git make build-essential inotify-tools
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get install -y nodejs

WORKDIR /app

COPY mix.exs .
COPY mix.lock .
COPY package.json .
COPY assets/package.json ./assets/package.json
COPY assets/package-lock.json ./assets/package-lock.json

RUN mix local.hex --force
RUN mix local.rebar --force

RUN mix deps.get
RUN mix deps.compile
RUN npm run assets:install -- --audit false --fund false --loglevel verbose

CMD mix deps.get && elixir --sname $SNAME --cookie foobarbaz -S mix phx.server

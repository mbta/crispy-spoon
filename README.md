![](https://github.com/mbta/dotcom/actions/workflows/tests.yml/badge.svg?branch=main)
![](https://github.com/mbta/dotcom/actions/workflows/docker.yml/badge.svg)
![](https://github.com/mbta/dotcom/actions/workflows/crawler.yml/badge.svg)

# Dotcom

The new face of https://www.mbta.com/. 

## Supported browsers 

We strive to support all users – but the variety of browsers, operating systems and devices available necessitates a more intentioned approach. Generally speaking, Dotcom supports the stable latest releases of all major web browsers (Chrome, Safari, Firefox, Microsoft Edge) and platforms (Windows, MacOS, iOS, Android). 
Other interfaces using the underlying engines of the aforementioned browsers – that's WebKit, Blink, Gecko – are not explicitly supported but are expected to function correctly.

From a development standpoint, polyfills and code transforms are implemented via [Babel](https://babeljs.io/docs/en/next/babel-preset-env.html#browserslist-integration) with the target browsers noted in [the site .browserslistrc](assets/.browserslistrc).


- [Getting Started](#getting-started)
- [Running the Server](#running-the-server)
- [Environment Variables](docs/ENVIRONMENT.md)
    - [`ALGOLIA_APP_ID`, `ALGOLIA_SEARCH_KEY`, and `ALGOLIA_WRITE_KEY`](docs/ENVIRONMENT.md#algolia_app_id-algolia_search_key-and-algolia_write_key)
    - [`CMS_API_BASE_URL`](docs/ENVIRONMENT.md#cms_api_base_url)
    - [`MBTA_API_BASE_URL`](docs/ENVIRONMENT.md#mbta_api_base_url)
    - [`MBTA_API_KEY`](docs/ENVIRONMENT.md#mbta_api_key)
- [Additional documentation](#additional-resources)

## Getting Started

Welcome to [Dotcom](https://www.notion.so/mbta-downtown-crossing/Dotcom-6aa7b0f0258446a197d35b1f05d90e96). There are more [details and background information in this Notion document](https://www.notion.so/mbta-downtown-crossing/Engineering-db62977f905347bab6fe94a2249a8a05), but read on to get started on your setup!

1. Request a V3 API key at https://api-dev.mbtace.com/. After getting an API key, it's customary to click "request increase" for your key's 'Per-Minute Limit'.

1. Install [Homebrew](https://docs.brew.sh/Installation.html):
    ```
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    ```

1. Install [asdf package version manager](https://github.com/asdf-vm/asdf)
   * Follow the instructions on https://github.com/asdf-vm/asdf
     
     ```shell
     brew install asdf
     ```
   * Install the necessary tools to set up asdf plugins:

     ```shell
     brew install gpg gawk # for nodejs plugin
     brew install autoconf openssl@1.1 # for erlang plugin
     brew install wxwidgets # optional for erlang for building with wxWidgets (start observer or debugger!)
     brew install libxslt fop # optional for erlang for building documentation and elixir reference builds
     ```

   * Add asdf plugins

     ```
     asdf plugin add erlang
     asdf plugin add elixir
     asdf plugin add nodejs
     ```
     You can verify the plugins were installed with `asdf plugin list`.

     While Erlang, Elixir, and NodeJS are essential for any development on Dotcom.

     You're welcome to add more plugins for personal use! But these are the ones set up in `.tool-versions` and invoked in the next step:

   * Now run the install:

     ```
     asdf install
     ```

   * Verify that all the languages for our setup were installed:

     ```
     asdf current
     ```

     You should see the following output with versions specified from `.tool-versions`:

     ```
      elixir         <version> (set by ~/dotcom/.tool-versions)
      erlang         <version> (set by ~/dotcom/.tool-versions)
      nodejs         <version> (set by ~/dotcom/.tool-versions)
      ...
     ```

     If you are missing any versions, you should re-run `asdf install`.

     You may have to individually install each version
     ```
     asdf install plugin_name <version> (set by ~/dotcom/.tool-versions)
     ```

1. Install our Elixir dependencies. From the root of this repo:
    ```
    mix deps.get
    ```


1. Install our Node dependencies. From the root of this repo:
    ```
    npm run assets:install
    ```
    You won't see a `node_modules` folder at the root of this project -- this installs packages into `assets`.

    Minor note - you may see a prompt to upgrade `npm`. This isn't needed, and `"lockfileVersion": 1` in our `assets/package-lock.json` file means it was generated with an `npm` version prior to 7.


1. Set up required environment variables:
    ```
    cp .env.template .env
    ```
   Then uncomment the `MBTA_API_KEY` line and fill it in with the key you obtained
   in the first step. If you have [direnv] installed (recommended), it will automatically load
   and unload the environment using this file. If not, `source .envrc` will load
   or update the variables in your shell session manually.

[direnv]: https://github.com/direnv/direnv

For details on environment configuration, including optional variables, see
[ENVIRONMENT.md](docs/ENVIRONMENT.md).

## Running the Server

The easiest way to develop MBTA dotcom is to use Docker Compose.

```
docker compose -f deploy/dev.yml up -d --build
```

This will set up Redis in cluster mode and run two versions of Dotcom with nginx load balancing requests between them.
Visit http://localhost:4001 to hit the load balancer.
http://localhost:4002 and http://localhost:4003 will take you directly to either of the two nodes.

You can even connect to individual Elixir nodes in order to run commands.
Let's say you want to connect to dotcom2 (the one running at http://localhost:4003).

```
docker exec -it deploy-dotcom-2-1 iex --sname foobarbaz --cookie foobarbaz

iex(foobarbaz@0b061394460f)1> node = :dotcom2@0b061394460f
:dotcom2@0b061394460f
iex(foobarbaz@0b061394460f)2> Node.connect(node)
true
iex(foobarbaz@0b061394460f)3> :rpc.call(node, Dotcom.Cache.Multilevel, :get, ["cms.repo|important-notices"])
...
```

Note that the address (the @... part) will be different every time.

---

If you choose not to use Docker Compose, you'll still have to run Redis cluster.
The easiest way to get it running is to download and compile it.

```
cd $HOME
wget https://github.com/redis/redis/archive/7.2.4.tar.gz
tar xvf 7.2.4.tar.gz
cd redis-7.2.4
make
./utils/create-cluster/create-cluster start
./utils/create-cluster/create-cluster create -f
```

When you're done with it:

```
./utils/create-cluster/create-cluster stop
cd $HOME
rm 7.2.4.tar.gz
rm -rf redis-7.2.4
```

Start the server with `iex -S mix phx.server`

Then, visit the site at http://localhost:4001.

## Algolia

[Algolia](https://www.algolia.com) powers our search features. Sometimes after content updates or GTFS releases we will find that the search results do not contain up-to-date results. When this happens you can re-index the Algolia data by running: `mix algolia.update`.

## Integration Tests

```
npm install --ignore-scripts
npx playwright test all-scenarios
```

You can run a single test (and optionally use `--debug` or `--ui`):

```
npx playwright test all-scenarios --grep @search_for_a_subway_line
```

## Load Tests

```
npm install --ignore-scripts
npx artillery run ./integration/load_tests/all-scenarios.yml --target http://localhost:4001
```

## Monitoring

```
npm install --ignore-scripts
npx pm2-runtime ./integration/monitor/ecosystem.config.js
```

## Additional Resources

New to the team, or looking for further developer resources?
- [Repo docs](docs): info about [testing](docs/TESTING.md) and other development details.
- [Intro to the V3 API](https://github.com/mbta/wiki/blob/master/api/intro.md): a starter guide to the data model with links to relevant API resources.
- [Dotcom Engineering Guide](https://docs.google.com/document/d/1Vg-8-APtBk7JYuj0TgWvcrWjU5mEA9vCk58aaJgq02Q/edit): a more comprehensive look at the Dotcom ecosystem, the V3 API Data Model, and other project info.
- Documentation for some [features that have come and gone](docs/SeasonalFeatures.md).

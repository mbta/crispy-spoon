const path = require("path");
const { merge } = require("webpack-merge");
const base = require("./webpack.config.base");

const port = process.env.WEBPACK_PORT || 8090;

module.exports = env =>
  merge(base, {
    mode: "development",

    devtool: "source-map",

    output: {
      publicPath: `http://localhost:${port}/`,
      path: path.resolve(__dirname, "../priv/static/css")
    },

    devServer: {
      host: "0.0.0.0",
      port: `${port}`,
      headers: {
        "Access-Control-Allow-Origin": "*"
      },
      devMiddleware: {
        writeToDisk: path => /\.css$/.test(path)
      },
      static: {
        directory: path.resolve(__dirname, "../priv/static/")
      },
      watchFiles: {
        paths: ['ts/**/*', 'js/**/*', 'css/**/*', 'vendor/**/*'],
        options: {
          usePolling: false,
          ignored: "/node_modules/"
        },
      },
      client: {
        logging: "warn",
        progress: true,
        overlay: {
          errors: true,
          warnings: true
        },
        reconnect: 5
      }
    }
  });

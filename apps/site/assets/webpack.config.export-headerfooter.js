const CopyWebpackPlugin = require("copy-webpack-plugin");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CssMinimizerPlugin = require("css-minimizer-webpack-plugin");
const { PurgeCSSPlugin } = require("purgecss-webpack-plugin");
const WebpackAssetsManifest = require("webpack-assets-manifest");

const path = require("path");
const glob = require("glob");
const sass = require("sass");

const babelLoader = {
  loader: "babel-loader",
  options: {
    configFile: path.resolve(__dirname, 'babel.config.js'),
  }
};

const tsLoader = {
  loader: "ts-loader",
  options: {
    configFile: path.resolve(__dirname, 'tsconfig.webpack.json')
  }
};

/**
 * Special configuration that outputs JavaScript, CSS, and static assets
 * for the MBTA.com header and footer. 
 * 
 * When run in both production and development modes, outputs with minified CSS and 
 * unminified CSS and JS, with sourcemaps. Also sets a hash for the filenames, 
 * and outputs head.html and script.html containing the appropriate <link> and 
 * <script> HTML tags linked to the output files.
 */
module.exports = (env, argv) => {
  const outputPath = path.resolve(__dirname, argv.outputPath ? argv.outputPath: "../../../../dotcomchrome");

  return ({
    mode: "production",
    entry: {
      dotcomchrome: "./export-headerfooter.ts"
    },
    output: {
      path: outputPath,
      filename: 'header.[contenthash].js', // css gets loaded through here
      crossOriginLoading: 'anonymous'
    },

    devtool: 'source-map',

    module: {
      rules: [
        {
          test: /\.(ts)$/,
          exclude: [/node_modules/],
          use: [babelLoader, tsLoader]
        },
        {
          test: /\.scss$/,
          use: [
            MiniCssExtractPlugin.loader,
            {
              loader: 'css-loader',
              options: {
                sourceMap: true,
                importLoaders: 1,
                url: false,
                esModule: true,
                modules: {
                  // namedExport: true,
                  localIdentName: "mbta__dotcomchrome__[local]",
                },
              },
            },
            {
              loader: 'sass-loader',
              options: {
                sourceMap: true,
                implementation: sass,
                sassOptions: {
                  includePaths: [
                    "node_modules/bootstrap/scss",
                    "node_modules/font-awesome/scss"
                  ],
                  outputStyle: "expanded",
                  quietDeps: true
                }
              },
            },
          ],
        }
      ]
    },

    plugins: [
      // extract CSS out of code, twice because we'll minify one
      new MiniCssExtractPlugin({
        filename: 'styles.[contenthash].min.css'
      }),
      new MiniCssExtractPlugin({
        filename: 'styles.[contenthash].css'
      }),

      // copy images and fonts
      new CopyWebpackPlugin({ patterns: [
            { from: "static/fonts/*", to: "fonts/[name][ext]" },
            { from: "static/favicon.ico", to: "favicon.ico" },
            { from: "static/images/mbta-logo.svg", to: "images/mbta-logo.svg" },
            { from: "static/images/mbta-name-and-logo.svg", to: "images/mbta-name-and-logo.svg" },
            { from: "static/images/mbta-logo-t-180.png", to: "images/mbta-logo-t-180.png" },
            { from: "static/images/mbta-logo-t-favicon.png", to: "images/mbta-logo-t-favicon.png" },
          ]}),

      // purge CSS based on HTML
      // depends on header.html and footer.html already being present at the outputPath.
      new PurgeCSSPlugin({
        fontFace: true, // remove unused @font-face
        keyframes: true, // remove unused keyframes
        paths: glob.sync(`${outputPath}/*.html`, { nodir: true }),
        rejected: true, // list removed things in stats
        variables: true, // remove unused --custom-properties
        safelist: {
          standard: [/c-modal__cover/],
          greedy: [/data-nav/, /data-search-open/, /aria-expanded/, /href/, /m-menu/, /m-footer/]
        },
        dynamicAttributes: [
          "aria-expanded",
          "href",
          "data-search-open",
          "data-nav-open",
          "data-nav"
        ]
      }),

      new WebpackAssetsManifest({
        integrity: true
      })
    ],

    optimization: {
      // only minimize the .min.css file
      minimizer: [
        new CssMinimizerPlugin({
          include: /min/,
          minimizerOptions: { preset: ["default", {
            discardComments: { removeAll: true },
          }] }
        })
      ],
    },

    resolve: {
      extensions: [".ts", ".js"]
    }
  })
};

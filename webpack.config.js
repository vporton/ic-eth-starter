const path = require('path');

// webpack.config.js
module.exports = {
    entry: './frontend/index.js',
    resolve: {
        modules: [path.resolve(__dirname, 'frontend'), 'node_modules'],
    },
};
  
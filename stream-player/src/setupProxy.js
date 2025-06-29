const { createProxyMiddleware } = require('http-proxy-middleware');

module.exports = function(app) {
  // Proxy HLS requests to the Go HLS server
  app.use(
    '/hls',
    createProxyMiddleware({
      target: 'http://localhost:8085',
      changeOrigin: true,
      logLevel: 'debug'
    })
  );
  
  // Proxy streams API requests
  app.use(
    '/streams',
    createProxyMiddleware({
      target: 'http://localhost:8085',
      changeOrigin: true,
      logLevel: 'debug'
    })
  );
};
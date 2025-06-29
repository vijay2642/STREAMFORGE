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
  
  // Proxy admin API requests to the Go admin service
  app.use(
    '/api/admin',
    createProxyMiddleware({
      target: 'http://localhost:9000',
      changeOrigin: true,
      logLevel: 'debug'
    })
  );
};
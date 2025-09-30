module.exports = (config, { strapi }) => {
  return async (ctx, next) => {
    if (ctx.path === '/_health') {
      try {
        // Check database connection
        await strapi.db.connection.raw('SELECT 1');
        
        ctx.status = 200;
        ctx.body = {
          status: 'ok',
          timestamp: new Date().toISOString(),
          uptime: process.uptime(),
          memory: process.memoryUsage(),
          version: process.version
        };
      } catch (error) {
        ctx.status = 503;
        ctx.body = {
          status: 'error',
          error: error.message,
          timestamp: new Date().toISOString()
        };
      }
      return;
    }
    
    await next();
  };
};

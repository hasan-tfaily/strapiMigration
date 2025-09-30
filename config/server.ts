export default ({ env }) => ({
  host: env("HOST", "127.0.0.1"),
  port: env.int("PORT", 1337),
  proxy: true,
  url: env("PUBLIC_URL", "https://165.232.76.106"),
  app: { keys: env.array("APP_KEYS") },
});

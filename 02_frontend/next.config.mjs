/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
  async rewrites() {
    const apiHost =
      process.env.API_HOST_INTERNAL ||
      (process.env.NODE_ENV === "production" ? "http://api:3001" : "http://localhost:3001");
    return [
      {
        source: "/api/:path*",
        destination: `${apiHost}/:path*`,
      },
      {
        source: "/attractions",
        destination: `${apiHost}/attractions`,
      },
    ];
  },
};

export default nextConfig;

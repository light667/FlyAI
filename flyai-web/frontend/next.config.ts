import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: 'standalone',
  typescript: {
    ignoreBuildErrors: true,
  },
  // Allow cross-origin HMR access from local network devices (Next.js 16+)
  allowedDevOrigins: ['10.0.11.85'],
};

export default nextConfig;

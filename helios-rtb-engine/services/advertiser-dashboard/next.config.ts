import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: 'standalone',
  
  // Allow production builds with linting warnings
  eslint: {
    // Warning: This allows production builds with warnings
    ignoreDuringBuilds: false,
  },
  
  // Disable strict TypeScript checks during build
  typescript: {
    ignoreBuildErrors: false,
  },
  
  // Environment variables available at runtime
  env: {
    NEXT_PUBLIC_ANALYTICS_API_URL: process.env.NEXT_PUBLIC_ANALYTICS_API_URL || 'http://localhost:8000',
  },
};

export default nextConfig;

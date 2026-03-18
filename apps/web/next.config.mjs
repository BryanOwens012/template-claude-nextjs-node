import path from 'path';

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  turbopack: {
    root: path.resolve(import.meta.dirname, '../..'),
  },
};

export default nextConfig;

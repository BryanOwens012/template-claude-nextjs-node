import type { Metadata, Viewport } from 'next';

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
  userScalable: true,
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
    { media: '(prefers-color-scheme: dark)', color: '#0a0a0a' },
  ],
};

export const metadata: Metadata = {
  title: {
    default: 'Next.js + Node.js Template',
    template: '%s | Next.js + Node.js',
  },
  description:
    'A production-ready template for rapidly spinning up full-stack applications with Next.js frontend and Node.js/Express backend services.',
  keywords: [
    'Next.js',
    'React',
    'Express',
    'Node.js',
    'TypeScript',
    'Tailwind CSS',
    'Full Stack',
    'Template',
    'Supabase',
    'Redis',
    'Radix UI',
    'shadcn/ui',
  ],
  authors: [{ name: 'Your Name' }],
  creator: 'Your Name',
  publisher: 'Your Name',
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'),
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000',
    siteName: 'Next.js + Node.js Template',
    title: 'Next.js + Node.js Template',
    description:
      'A template for rapidly spinning up full-stack applications with Next.js frontend and Node.js backend services.',
    images: [
      {
        url: '/icon.svg',
        width: 1200,
        height: 630,
        alt: 'Next.js + Node.js Template',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Next.js + Node.js Template',
    description:
      'A template for rapidly spinning up full-stack applications with Next.js frontend and Node.js backend services.',
    images: ['/icon.svg'],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  // Note: Icons (favicon, apple-icon) are auto-detected from app/ directory
  // Place icon.svg, favicon.ico, and apple-icon.png in app/ directory
  // See: https://nextjs.org/docs/app/api-reference/file-conventions/metadata/app-icons
};

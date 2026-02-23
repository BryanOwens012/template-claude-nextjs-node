import "./globals.css";

// Import metadata configuration
export { metadata, viewport } from "./metadata";

const RootLayout = ({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) => {
  return (
    <html lang="en">
      <head>
        {/* Preconnect to API domain for faster requests */}
        {process.env.NEXT_PUBLIC_API_URL && (
          <>
            <link
              rel="preconnect"
              href={process.env.NEXT_PUBLIC_API_URL}
              crossOrigin="anonymous"
            />
            <link rel="dns-prefetch" href={process.env.NEXT_PUBLIC_API_URL} />
          </>
        )}
      </head>
      <body className="antialiased">{children}</body>
    </html>
  );
};

export default RootLayout;

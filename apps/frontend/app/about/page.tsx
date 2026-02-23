import type { Metadata } from "next";
import Link from "next/link";

// Override metadata for this specific page
export const metadata: Metadata = {
  title: "About",
  description: "Learn more about this Next.js + FastAPI template",
};

const AboutPage = () => {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-8 gap-8">
      <main className="flex flex-col gap-8 items-center max-w-2xl">
        {/* Header */}
        <div className="text-center">
          <h1 className="text-4xl md:text-5xl font-bold mb-4">
            About This Template
          </h1>
          <p className="text-lg text-gray-600 dark:text-gray-400">
            Example route demonstrating Next.js App Router
          </p>
        </div>

        {/* Content */}
        <div className="w-full space-y-6">
          <div className="p-6 border border-gray-200 dark:border-gray-800 rounded-lg">
            <h2 className="text-2xl font-semibold mb-3">
              📁 File-Based Routing
            </h2>
            <p className="text-gray-600 dark:text-gray-400 mb-3">
              This page is located at <code className="bg-gray-100 dark:bg-gray-900 px-2 py-1 rounded">app/about/page.tsx</code>
            </p>
            <p className="text-gray-600 dark:text-gray-400">
              Next.js automatically creates the <code className="bg-gray-100 dark:bg-gray-900 px-2 py-1 rounded">/about</code> route
              based on the folder structure.
            </p>
          </div>

          <div className="p-6 border border-gray-200 dark:border-gray-800 rounded-lg">
            <h2 className="text-2xl font-semibold mb-3">
              🎯 Page-Specific Metadata
            </h2>
            <p className="text-gray-600 dark:text-gray-400">
              This page overrides the default metadata with its own title and description.
              Check the page source or browser tab to see &quot;About | Next.js + FastAPI&quot;
            </p>
          </div>

          <div className="p-6 border border-gray-200 dark:border-gray-800 rounded-lg">
            <h2 className="text-2xl font-semibold mb-3">
              🔧 Tech Stack
            </h2>
            <ul className="space-y-2 text-gray-600 dark:text-gray-400">
              <li>• <strong>Frontend:</strong> Next.js 15, React 19, TypeScript, Tailwind CSS</li>
              <li>• <strong>Backend:</strong> FastAPI, Python 3.11+, Async/Await</li>
              <li>• <strong>Database:</strong> Supabase (PostgreSQL)</li>
              <li>• <strong>Caching:</strong> Redis</li>
              <li>• <strong>Deployment:</strong> Vercel + Railway</li>
            </ul>
          </div>
        </div>

        {/* Navigation */}
        <div className="flex gap-4">
          <Link
            href="/"
            className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
          >
            ← Back to Home
          </Link>
          <a
            href="http://localhost:8000/docs"
            target="_blank"
            rel="noopener noreferrer"
            className="px-6 py-3 border border-gray-300 dark:border-gray-700 hover:border-gray-400 rounded-lg transition-colors"
          >
            API Docs →
          </a>
        </div>
      </main>

      {/* Footer */}
      <footer className="text-center text-sm text-gray-500 dark:text-gray-600">
        <p>
          This is an example route showing Next.js App Router conventions
        </p>
      </footer>
    </div>
  );
};

export default AboutPage;

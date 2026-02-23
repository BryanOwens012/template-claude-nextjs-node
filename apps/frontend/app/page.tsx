import Link from "next/link";
import ApiStatus from "@/components/ApiStatus";

const Home = () => {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-8 gap-8">
      <main className="flex flex-col gap-8 items-center max-w-2xl">
        {/* Header */}
        <div className="text-center">
          <h1 className="text-4xl md:text-6xl font-bold mb-4 bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
            Hello World!
          </h1>
          <p className="text-lg md:text-xl text-gray-600 dark:text-gray-400">
            Next.js + FastAPI Template
          </p>
        </div>

        {/* Feature Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 w-full">
          <div className="p-6 border border-gray-200 dark:border-gray-800 rounded-lg hover:border-blue-500 transition-colors">
            <h2 className="text-xl font-semibold mb-2">🚀 Next.js 15</h2>
            <p className="text-sm text-gray-600 dark:text-gray-400">
              Modern React framework with App Router, Server Components, and TypeScript
            </p>
          </div>

          <div className="p-6 border border-gray-200 dark:border-gray-800 rounded-lg hover:border-purple-500 transition-colors">
            <h2 className="text-xl font-semibold mb-2">⚡ FastAPI</h2>
            <p className="text-sm text-gray-600 dark:text-gray-400">
              High-performance Python backend with async support and auto-generated docs
            </p>
          </div>

          <div className="p-6 border border-gray-200 dark:border-gray-800 rounded-lg hover:border-green-500 transition-colors">
            <h2 className="text-xl font-semibold mb-2">🎨 Tailwind CSS</h2>
            <p className="text-sm text-gray-600 dark:text-gray-400">
              Utility-first CSS framework with dark mode support
            </p>
          </div>

          <div className="p-6 border border-gray-200 dark:border-gray-800 rounded-lg hover:border-orange-500 transition-colors">
            <h2 className="text-xl font-semibold mb-2">🔧 TypeScript</h2>
            <p className="text-sm text-gray-600 dark:text-gray-400">
              Type-safe development with modern ES6+ features
            </p>
          </div>
        </div>

        {/* API Status Component */}
        <ApiStatus />

        {/* Quick Links */}
        <div className="flex gap-4 items-center flex-wrap justify-center">
          <Link
            href="/about"
            className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
          >
            About →
          </Link>
          <a
            href="http://localhost:8000/docs"
            target="_blank"
            rel="noopener noreferrer"
            className="px-4 py-2 border border-gray-300 dark:border-gray-700 hover:border-gray-400 rounded-lg transition-colors"
          >
            API Docs
          </a>
          <a
            href="https://nextjs.org/docs"
            target="_blank"
            rel="noopener noreferrer"
            className="px-4 py-2 border border-gray-300 dark:border-gray-700 hover:border-gray-400 rounded-lg transition-colors"
          >
            Next.js Docs
          </a>
        </div>
      </main>

      {/* Footer */}
      <footer className="text-center text-sm text-gray-500 dark:text-gray-600">
        <p>
          Edit <code className="bg-gray-100 dark:bg-gray-900 px-2 py-1 rounded">app/page.tsx</code> to get started
        </p>
      </footer>
    </div>
  );
};

export default Home;

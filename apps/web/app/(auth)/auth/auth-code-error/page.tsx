'use client';

import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';

const AuthCodeErrorContent = () => {
  const searchParams = useSearchParams();
  const error = searchParams.get('error');
  const errorDescription = searchParams.get('error_description');

  return (
    <div className="w-full text-center">
      <h1 className="text-2xl font-bold text-gray-900 mb-4">Authentication Failed</h1>

      <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded">
        <p className="text-red-700 text-sm font-semibold mb-2">{error && `Error: ${error}`}</p>
        <p className="text-red-600 text-sm">
          {errorDescription || 'An error occurred during authentication. Please try again.'}
        </p>
      </div>

      <p className="text-gray-600 mb-6">
        If the problem persists, please try again or contact support.
      </p>

      <div className="flex flex-col gap-3">
        <Link
          href="/login"
          className="px-6 py-3 bg-blue-600 text-white font-semibold rounded hover:bg-blue-700 transition-colors"
        >
          Back to login
        </Link>
        <Link
          href="/"
          className="px-6 py-3 border border-gray-300 text-gray-900 font-semibold rounded hover:bg-gray-50 transition-colors"
        >
          Back to home
        </Link>
      </div>
    </div>
  );
};

const AuthCodeErrorPage = () => {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <AuthCodeErrorContent />
    </Suspense>
  );
};

export default AuthCodeErrorPage;

'use client';

import Link from 'next/link';
import { Suspense, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

const ResetPasswordContent = () => {
  const supabase = createClient();

  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);

  const handleReset = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);

    if (!email.trim()) {
      setError('Email is required');
      return;
    }

    setLoading(true);

    try {
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/auth/callback?type=recovery`,
      });

      if (resetError) {
        setError(resetError.message);
        return;
      }

      setSubmitted(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  if (submitted) {
    return (
      <div className="w-full">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Check your email</h1>
        <p className="text-gray-600 mb-6">
          If an account exists for <span className="font-semibold">{email}</span>, you&apos;ll
          receive a password reset link shortly.
        </p>

        <Link
          href="/login"
          className="block w-full px-6 py-3 font-semibold rounded transition-colors text-center bg-blue-600 text-white hover:bg-blue-700"
        >
          Back to login
        </Link>
      </div>
    );
  }

  return (
    <div className="w-full">
      <h1 className="text-3xl font-bold text-gray-900 mb-2">Reset password</h1>
      <p className="text-gray-600 mb-8">
        Enter your email and we&apos;ll send you a link to reset your password.
      </p>

      {error && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {error}
        </div>
      )}

      <form onSubmit={handleReset} className="mb-6">
        <div className="mb-6">
          <label htmlFor="email" className="block text-sm font-semibold text-gray-900 mb-2">
            Email <span className="text-red-600">*</span>
          </label>
          <input
            type="email"
            id="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-4 py-2 border border-gray-300 rounded text-base focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600"
            placeholder="you@example.com"
            required
            disabled={loading}
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className={`w-full px-6 py-3 font-semibold rounded transition-colors mb-4 ${
            loading
              ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
              : 'bg-blue-600 text-white hover:bg-blue-700'
          }`}
        >
          {loading ? 'Sending...' : 'Send reset link'}
        </button>
      </form>

      <p className="text-center text-sm text-gray-600 mt-6">
        Remember your password?{' '}
        <Link href="/login" className="text-blue-600 hover:underline font-semibold">
          Log in
        </Link>
      </p>
    </div>
  );
};

const ResetPasswordPage = () => {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <ResetPasswordContent />
    </Suspense>
  );
};

export default ResetPasswordPage;

'use client';

import { useRouter } from 'next/navigation';
import { Suspense, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

const UpdatePasswordContent = () => {
  const router = useRouter();
  const supabase = createClient();

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const validatePassword = (pwd: string) => {
    if (pwd.length < 12) return 'Password must be at least 12 characters';
    if (!/[a-z]/.test(pwd)) return 'Password must include a lowercase letter';
    if (!/[A-Z]/.test(pwd)) return 'Password must include an uppercase letter';
    if (!/[0-9]/.test(pwd)) return 'Password must include a number';
    if (!/[!@#$%^&*\-+~?_=]/.test(pwd))
      return 'Password must include a special character (e.g. -, *, !, +, ~, ?)';
    return null;
  };

  const handleUpdate = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);

    if (!password.trim()) {
      setError('Password is required');
      return;
    }

    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    const passwordError = validatePassword(password);
    if (passwordError) {
      setError(passwordError);
      return;
    }

    setLoading(true);

    try {
      const { error: updateError } = await supabase.auth.updateUser({
        password,
      });

      if (updateError) {
        setError(updateError.message);
        return;
      }

      router.push('/dashboard');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-full">
      <h1 className="text-3xl font-bold text-gray-900 mb-2">Set new password</h1>
      <p className="text-gray-600 mb-8">Enter your new password below.</p>

      {error && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {error}
        </div>
      )}

      <form onSubmit={handleUpdate} className="mb-6">
        <div className="mb-4">
          <label htmlFor="password" className="block text-sm font-semibold text-gray-900 mb-2">
            New Password <span className="text-red-600">*</span>
          </label>
          <input
            type="password"
            id="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full px-4 py-2 border border-gray-300 rounded text-base focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600"
            placeholder="Min. 12 characters"
            required
            disabled={loading}
          />
          <p className="text-xs text-gray-500 mt-1">
            Min. 12 characters with uppercase, lowercase, number, and special character
          </p>
        </div>

        <div className="mb-6">
          <label
            htmlFor="confirmPassword"
            className="block text-sm font-semibold text-gray-900 mb-2"
          >
            Confirm Password <span className="text-red-600">*</span>
          </label>
          <input
            type="password"
            id="confirmPassword"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            className="w-full px-4 py-2 border border-gray-300 rounded text-base focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600"
            placeholder="Re-enter password"
            required
            disabled={loading}
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className={`w-full px-6 py-3 font-semibold rounded transition-colors ${
            loading
              ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
              : 'bg-blue-600 text-white hover:bg-blue-700'
          }`}
        >
          {loading ? 'Updating...' : 'Update password'}
        </button>
      </form>
    </div>
  );
};

const UpdatePasswordPage = () => {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <UpdatePasswordContent />
    </Suspense>
  );
};

export default UpdatePasswordPage;

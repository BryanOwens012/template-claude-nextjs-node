'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import posthog from 'posthog-js';
import { Suspense, useState } from 'react';
import { isEmailInvited } from '@/lib/supabase/check-invite';
import { createClient } from '@/lib/supabase/client';

const SignupContent = () => {
  const router = useRouter();
  const supabase = createClient();

  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const validatePassword = (pwd: string) => {
    if (pwd.length < 12) return 'Password must be at least 12 characters';
    if (!/[a-z]/.test(pwd)) return 'Password must include a lowercase letter';
    if (!/[A-Z]/.test(pwd)) return 'Password must include an uppercase letter';
    if (!/[0-9]/.test(pwd)) return 'Password must include a number';
    if (!/[!@#$%^&*\-+~?_=]/.test(pwd))
      return 'Password must include a special character (e.g. -, *, !, +, ~, ?)';
    return null;
  };

  const handleSignup = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    setMessage(null);

    if (!firstName.trim()) {
      setError('First name is required');
      return;
    }

    if (!lastName.trim()) {
      setError('Last name is required');
      return;
    }

    if (!email.trim()) {
      setError('Email is required');
      return;
    }

    if (!password.trim()) {
      setError('Password is required');
      return;
    }

    const passwordError = validatePassword(password);
    if (passwordError) {
      setError(passwordError);
      return;
    }

    setLoading(true);

    try {
      const invited = await isEmailInvited(email);
      if (!invited) {
        setError('This email has not been invited.');
        setLoading(false);
        return;
      }

      setMessage('Creating your account...');

      const { error: signupError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            first_name: firstName,
            last_name: lastName,
          },
        },
      });

      if (signupError) {
        setError(signupError.message);
        setMessage(null);
        return;
      }

      posthog.capture('user_signed_up', { method: 'email' });
      setMessage('Account created! Logging in...');
      setFirstName('');
      setLastName('');
      setEmail('');
      setPassword('');

      setTimeout(() => {
        router.push('/dashboard');
      }, 2000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleSignup = async () => {
    setLoading(true);
    setError(null);

    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: `${window.location.origin}/auth/callback`,
        },
      });

      if (error) {
        setError(error.message);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  const handleMicrosoftSignup = async () => {
    setLoading(true);
    setError(null);

    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'azure',
        options: {
          redirectTo: `${window.location.origin}/auth/callback`,
          scopes: 'email',
        },
      });

      if (error) {
        setError(error.message);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-full">
      <h1 className="text-3xl font-bold text-gray-900 mb-10">Sign up</h1>

      {error && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {error}
        </div>
      )}

      {message && (
        <div className="mb-4 p-4 bg-green-50 border border-green-200 rounded text-green-700 text-sm">
          {message}
        </div>
      )}

      <button
        type="button"
        onClick={handleMicrosoftSignup}
        disabled={loading}
        className="w-full px-6 py-3 font-semibold rounded transition-colors border border-gray-300 text-gray-900 hover:bg-gray-50 mb-3 disabled:bg-gray-100 disabled:cursor-not-allowed"
      >
        <Image
          src="/sso/microsoft-logo.svg"
          alt="Microsoft"
          width={20}
          height={20}
          className="mr-2 -mt-0.5 inline-block"
        />
        Continue with Microsoft
      </button>

      <button
        type="button"
        onClick={handleGoogleSignup}
        disabled={loading}
        className="w-full px-6 py-3 font-semibold rounded transition-colors border border-gray-300 text-gray-900 hover:bg-gray-50 mb-6 disabled:bg-gray-100 disabled:cursor-not-allowed"
      >
        <Image
          src="/sso/google-logo.svg"
          alt="Google"
          width={20}
          height={20}
          className="mr-2 -mt-0.5 inline-block"
        />
        Continue with Google
      </button>

      <div className="relative mb-6">
        <div className="absolute inset-0 flex items-center">
          <div className="w-full border-t border-gray-300"></div>
        </div>
        <div className="relative flex justify-center text-sm">
          <span className="px-2 bg-white text-gray-500">OR</span>
        </div>
      </div>

      <form onSubmit={handleSignup} className="mb-6">
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div>
            <label htmlFor="firstName" className="block text-sm font-semibold text-gray-900 mb-2">
              First Name <span className="text-red-600">*</span>
            </label>
            <input
              type="text"
              id="firstName"
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded text-base focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600"
              placeholder="John"
              required
              disabled={loading}
            />
          </div>

          <div>
            <label htmlFor="lastName" className="block text-sm font-semibold text-gray-900 mb-2">
              Last Name <span className="text-red-600">*</span>
            </label>
            <input
              type="text"
              id="lastName"
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded text-base focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600"
              placeholder="Doe"
              required
              disabled={loading}
            />
          </div>
        </div>

        <div className="mb-4">
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

        <div className="mb-6">
          <label htmlFor="password" className="block text-sm font-semibold text-gray-900 mb-2">
            Password <span className="text-red-600">*</span>
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

        <button
          type="submit"
          disabled={loading}
          className={`w-full px-6 py-3 font-semibold rounded transition-colors mb-4 ${
            loading
              ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
              : 'bg-blue-600 text-white hover:bg-blue-700'
          }`}
        >
          {loading ? 'Signing up...' : 'Sign up'}
        </button>
      </form>

      <p className="text-center text-sm text-gray-600 mt-6">
        Already have an account?{' '}
        <Link href="/login" className="text-blue-600 hover:underline font-semibold">
          Log in
        </Link>
      </p>
    </div>
  );
};

const SignupPage = () => {
  return (
    <Suspense>
      <SignupContent />
    </Suspense>
  );
};

export default SignupPage;

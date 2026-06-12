'use client';

import posthog from 'posthog-js';
import { useState } from 'react';
import LoadingDialog from '@/components/ui/LoadingDialog';
import { createClient } from '@/lib/supabase/client';

const LogoutButton = () => {
  const [isLoggingOut, setIsLoggingOut] = useState(false);

  const handleLogout = async () => {
    setIsLoggingOut(true);
    try {
      const supabase = createClient();
      await supabase.auth.signOut();
      posthog.capture('user_logged_out');
      posthog.reset();
      window.location.href = '/';
    } catch (error) {
      console.error('Logout error:', error);
      setIsLoggingOut(false);
    }
  };

  return (
    <>
      <button
        type="button"
        onClick={handleLogout}
        disabled={isLoggingOut}
        className="text-sm text-gray-600 hover:text-gray-900 disabled:cursor-not-allowed"
      >
        {isLoggingOut ? 'Logging out...' : 'Log out'}
      </button>
      <LoadingDialog isLoading={isLoggingOut} label="Logging out…" />
    </>
  );
};

export default LogoutButton;

'use client';

import { useState } from 'react';
import { createClient } from '@/lib/supabase/client';

const LogoutButton = () => {
  const [loading, setLoading] = useState(false);

  const handleLogout = async () => {
    setLoading(true);
    try {
      const supabase = createClient();
      await supabase.auth.signOut();
      window.location.href = '/';
    } catch (error) {
      console.error('Logout error:', error);
      setLoading(false);
    }
  };

  return (
    <button
      type="button"
      onClick={handleLogout}
      disabled={loading}
      className="text-sm text-gray-600 hover:text-gray-900 disabled:cursor-not-allowed"
    >
      {loading ? 'Logging out...' : 'Log out'}
    </button>
  );
};

export default LogoutButton;

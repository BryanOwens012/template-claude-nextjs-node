export const dynamic = 'force-dynamic';

import { redirect } from 'next/navigation';
import LogoutButton from '@/components/LogoutButton';
import { PostHogIdentity } from '@/components/PostHogIdentity';
import { createClient } from '@/lib/supabase/server';

const DashboardLayout = async ({ children }: { children: React.ReactNode }) => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect('/login');
  }

  const displayName =
    user.user_metadata?.first_name && user.user_metadata?.last_name
      ? `${user.user_metadata.first_name} ${user.user_metadata.last_name}`
      : user.email;

  return (
    <div className="min-h-screen bg-gray-50">
      <PostHogIdentity userId={user.id} email={user.email ?? ''} />
      <header className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <h1 className="text-lg font-semibold text-gray-900">Dashboard</h1>
          <div className="flex items-center gap-4">
            <span className="text-sm text-gray-600">{displayName}</span>
            <LogoutButton />
          </div>
        </div>
      </header>
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">{children}</main>
    </div>
  );
};

export default DashboardLayout;

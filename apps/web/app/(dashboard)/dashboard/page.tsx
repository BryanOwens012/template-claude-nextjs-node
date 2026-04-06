export const dynamic = 'force-dynamic';

import { createClient } from '@/lib/supabase/server';

const DashboardPage = async () => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-2xl font-bold text-gray-900 mb-4">Welcome to the Dashboard</h2>
      <p className="text-gray-600">
        You are logged in as <span className="font-semibold">{user?.email}</span>
      </p>
    </div>
  );
};

export default DashboardPage;

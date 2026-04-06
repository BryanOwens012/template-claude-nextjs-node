import { NextResponse } from 'next/server';

export const GET = () => {
  const applicationId = process.env.AZURE_OAUTH_CLIENT_ID;

  if (!applicationId) {
    return NextResponse.json({ error: 'Not configured' }, { status: 404 });
  }

  return NextResponse.json(
    {
      associatedApplications: [{ applicationId }],
    },
    {
      headers: { 'Content-Type': 'application/json' },
    },
  );
};

'use client';

import posthog from 'posthog-js';
import { useEffect } from 'react';

interface Props {
  userId: string;
  email: string;
}

export const PostHogIdentity = ({ userId, email }: Props) => {
  useEffect(() => {
    posthog.identify(userId, { email });
  }, [userId, email]);
  return null;
};

'use server';

import { isAdminEmail } from '@/lib/utils/admin';

/**
 * Check if an email is allowed to sign up.
 * - Admin domain emails always pass.
 * - If INVITED_EMAILS is empty/unset, anyone can sign up (open mode).
 * - Otherwise, email must be in the comma-separated INVITED_EMAILS list.
 *
 * This is a server action — callable from client components and Route Handlers.
 */
export const isEmailInvited = async (email: string): Promise<boolean> => {
  if (isAdminEmail(email)) return true;

  const invitedEmails = process.env.INVITED_EMAILS ?? '';
  if (!invitedEmails.trim()) return true; // Open signup mode

  const list = invitedEmails
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);

  return list.includes(email.toLowerCase());
};

const ADMIN_EMAIL_DOMAIN = process.env.ADMIN_EMAIL_DOMAIN ?? '';

export const isAdminEmail = (email: string): boolean => {
  if (!ADMIN_EMAIL_DOMAIN || !email) return false;
  const atIndex = email.lastIndexOf('@');
  return (
    atIndex !== -1 && email.slice(atIndex + 1).toLowerCase() === ADMIN_EMAIL_DOMAIN.toLowerCase()
  );
};

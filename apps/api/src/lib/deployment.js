// These URLs are public browser destinations, never private service bindings.
export function appOrigin(env = process.env) {
  const url = env.APP_URL || (env.VERCEL_URL ? `https://${env.VERCEL_URL}` : 'http://localhost:5173');
  const parsed = new URL(url);
  if (!['http:', 'https:'].includes(parsed.protocol) || parsed.username || parsed.password) {
    throw new Error('APP_URL debe ser el origen HTTP(S) publico de la aplicacion.');
  }
  return parsed.origin;
}

export function allowedOrigins(env = process.env) {
  const origins = [appOrigin(env)];
  if (env.VERCEL_URL) origins.push(new URL(`https://${env.VERCEL_URL}`).origin);
  return origins;
}

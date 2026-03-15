export async function onRequest(context) {
  const clientId = context.env.GITHUB_CLIENT_ID;
  const origin = new URL(context.request.url).origin;
  const redirectUri = encodeURIComponent(`${origin}/oauth/callback`);
  const scope = encodeURIComponent("repo,user");

  return new Response(null, {
    status: 302,
    headers: {
      Location: `https://github.com/login/oauth/authorize?client_id=${clientId}&redirect_uri=${redirectUri}&scope=${scope}`,
    },
  });
}

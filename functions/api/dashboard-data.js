/**
 * Cloudflare Pages Function: /api/dashboard-data
 * WF7 Dashboard API へのプロキシ（CORS対応）
 */
export async function onRequest() {
  try {
    const res = await fetch(
      'https://n8n-37design.37d.jp/webhook/Hjb8yPWw97g6m0C5/webhooktrigger/wf7-dashboard-api',
      { cf: { cacheTtl: 0 } }
    );
    const data = await res.json();
    return new Response(JSON.stringify(data), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
      },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}

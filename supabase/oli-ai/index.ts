// Edge Function "oli-ai" cho Lớp học Ô Li
// Nhận yêu cầu từ web (đã đăng nhập), gọi AI bằng khóa giữ bí mật trên máy chủ, giới hạn số lượt mỗi ngày.
// Khóa AI đặt trong Supabase › Edge Functions › Secrets:
//   ANTHROPIC_API_KEY  (khuyên dùng)   hoặc   GEMINI_API_KEY + GEMINI_MODEL
// Tuỳ chọn: AI_LIMIT_STUDENT (mặc định 20 lượt/ngày), AI_LIMIT_TEACHER (mặc định 200), ANTHROPIC_MODEL, ANTHROPIC_MODEL_FAST
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const out = (o: unknown) => new Response(JSON.stringify(o), { headers: { ...CORS, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(url, service, { auth: { persistSession: false } });
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: { user } } = await admin.auth.getUser(jwt);
    if (!user) return out({ error: "Chưa đăng nhập", code: "not_granted" });

    const { data: prof } = await admin.from("profiles").select("role").eq("id", user.id).maybeSingle();
    if (!prof || !["teacher", "student"].includes(prof.role)) return out({ error: "Tài khoản chưa được duyệt", code: "not_granted" });

    const ANTH = Deno.env.get("ANTHROPIC_API_KEY");
    const GEM = Deno.env.get("GEMINI_API_KEY");
    if (!ANTH && !GEM) return out({ error: "Máy chủ chưa có khóa AI", code: "not_granted" });

    const body = await req.json().catch(() => ({}));
    if (body.ping) return out({ ok: true, provider: ANTH ? "anthropic" : "gemini" });

    const prompt = String(body.prompt ?? "").slice(0, 40000);
    if (!prompt) return out({ error: "Thiếu nội dung", code: "invalid_request" });

    // giới hạn lượt dùng mỗi ngày
    const limit = prof.role === "teacher" ? Number(Deno.env.get("AI_LIMIT_TEACHER") ?? 200) : Number(Deno.env.get("AI_LIMIT_STUDENT") ?? 20);
    const day = new Date().toISOString().slice(0, 10);
    const { data: u } = await admin.from("ai_usage").select("n").eq("uid", user.id).eq("day", day).maybeSingle();
    const used = u?.n ?? 0;
    if (used >= limit) return out({ error: "Hết lượt dùng AI hôm nay", code: "rate_limited" });
    await admin.from("ai_usage").upsert({ uid: user.id, day, n: used + 1 });

    const quick = body.tier === "quick";
    const json = !!body.json;
    const maxTokens = quick ? 800 : 8000;
    const system = "Bạn là trợ lí giáo dục của một trường THCS ở Việt Nam (chương trình GDPT 2018). Nội dung phải chính xác, phù hợp học sinh 11–15 tuổi, không có nội dung không phù hợp với trẻ em." +
      (json ? " Chỉ trả về đúng một giá trị JSON hợp lệ, không thêm lời giải thích, không dùng ```." : "");

    let text = "";
    if (ANTH) {
      const model = quick ? (Deno.env.get("ANTHROPIC_MODEL_FAST") ?? "claude-haiku-5-5") : (Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5-5");
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "x-api-key": ANTH, "anthropic-version": "2023-06-01", "content-type": "application/json" },
        body: JSON.stringify({ model, max_tokens: maxTokens, system, messages: [{ role: "user", content: prompt }] }),
      });
      const j = await r.json();
      if (!r.ok) return out({ error: j?.error?.message ?? "Lỗi dịch vụ AI", code: r.status === 429 ? "rate_limited" : "upstream_error" });
      text = (j.content ?? []).filter((c: { type: string }) => c.type === "text").map((c: { text: string }) => c.text).join("");
    } else {
      const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: "POST",
        headers: { "content-type": "application/json", "x-goog-api-key": GEM! },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: system }] },
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: { maxOutputTokens: maxTokens, ...(json ? { responseMimeType: "application/json" } : {}) },
        }),
      });
      const j = await r.json();
      if (!r.ok) return out({ error: j?.error?.message ?? "Lỗi dịch vụ AI", code: r.status === 429 ? "rate_limited" : "upstream_error" });
      text = (j.candidates?.[0]?.content?.parts ?? []).map((p: { text?: string }) => p.text ?? "").join("");
    }
    return out({ text });
  } catch (e) {
    return out({ error: String((e as Error)?.message ?? e), code: "upstream_error" });
  }
});

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type InvitePayload = {
  email?: string;
  full_name?: string;
  phone?: string;
  role?: string;
  status?: string;
  redirect_to?: string;
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {...corsHeaders, "Content-Type": "application/json"},
  });
}

function cleanUrl(value?: string | null) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.origin + url.pathname;
  } catch (_) {
    return null;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {headers: corsHeaders});
  }
  if (req.method !== "POST") {
    return jsonResponse(405, {success: false, message: "Phương thức không được hỗ trợ."});
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(500, {success: false, message: "Edge Function chưa được cấu hình biến môi trường."});
  }

  const authHeader = req.headers.get("authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return jsonResponse(401, {success: false, message: "Bạn cần đăng nhập để thực hiện thao tác này."});
  }

  let payload: InvitePayload;
  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse(400, {success: false, message: "Dữ liệu gửi lên không hợp lệ."});
  }

  const email = (payload.email || "").trim().toLowerCase();
  const fullName = (payload.full_name || "").trim();
  const phone = (payload.phone || "").trim();
  const role = (payload.role || "").trim();
  const status = (payload.status || "").trim();
  const validRoles = ["admin", "owner", "worker"];
  const validStatuses = ["active", "inactive", "locked"];

  if (!email) return jsonResponse(400, {success: false, message: "Vui lòng nhập email."});
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return jsonResponse(400, {success: false, message: "Email không hợp lệ."});
  }
  if (!validRoles.includes(role)) {
    return jsonResponse(400, {success: false, message: "Vai trò không hợp lệ."});
  }
  if (!validStatuses.includes(status)) {
    return jsonResponse(400, {success: false, message: "Trạng thái không hợp lệ."});
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {autoRefreshToken: false, persistSession: false},
  });

  const {data: callerData, error: callerError} = await supabase.auth.getUser(token);
  if (callerError || !callerData.user) {
    return jsonResponse(401, {success: false, message: "Phiên đăng nhập không hợp lệ hoặc đã hết hạn."});
  }

  const {data: callerProfile, error: profileError} = await supabase
    .from("profiles")
    .select("role,status")
    .eq("id", callerData.user.id)
    .maybeSingle();

  if (profileError) {
    return jsonResponse(500, {success: false, message: "Không thể kiểm tra quyền quản trị viên."});
  }
  if (!callerProfile || callerProfile.role !== "admin" || callerProfile.status !== "active") {
    return jsonResponse(403, {success: false, message: "Chỉ quản trị viên đang hoạt động mới được mời tài khoản."});
  }

  const fallbackRedirect = req.headers.get("origin") || "http://127.0.0.1:5500";
  const redirectTo = cleanUrl(payload.redirect_to) || cleanUrl(fallbackRedirect) || "http://127.0.0.1:5500";

  const {data: inviteData, error: inviteError} = await supabase.auth.admin.inviteUserByEmail(email, {
    redirectTo,
  });
  if (inviteError || !inviteData.user) {
    const message = inviteError?.message?.toLowerCase().includes("already")
      ? "Email này đã tồn tại trong Supabase Authentication."
      : "Không thể gửi email kích hoạt tài khoản.";
    return jsonResponse(400, {success: false, message});
  }

  const {error: upsertError} = await supabase
    .from("profiles")
    .upsert({
      id: inviteData.user.id,
      email,
      full_name: fullName,
      phone,
      role,
      status,
    }, {onConflict: "id"});

  if (upsertError) {
    return jsonResponse(500, {success: false, message: "Đã gửi email nhưng không thể lưu hồ sơ phân quyền."});
  }

  return jsonResponse(200, {
    success: true,
    message: "Đã gửi email kích hoạt tài khoản",
  });
});

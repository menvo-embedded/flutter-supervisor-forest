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
  owner_id?: string | null;
  password?: string;
  redirect_to?: string;
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
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
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, {
      success: false,
      message: "Phương thức không được hỗ trợ.",
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(500, {
      success: false,
      message: "Edge Function chưa được cấu hình biến môi trường.",
    });
  }

  const authHeader = req.headers.get("authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();

  if (!token) {
    return jsonResponse(401, {
      success: false,
      message: "Bạn cần đăng nhập để thực hiện thao tác này.",
    });
  }

  let payload: InvitePayload;

  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse(400, {
      success: false,
      message: "Dữ liệu gửi lên không hợp lệ.",
    });
  }

  const email = (payload.email || "").trim().toLowerCase();
  const fullName = (payload.full_name || "").trim();
  const phone = (payload.phone || "").trim();
  const role = (payload.role || "").trim();
  const status = (payload.status || "").trim();
  const password = payload.password && payload.password.length > 0
    ? payload.password
    : "123456";

  const validRoles = ["admin", "owner", "worker"];
  const validStatuses = ["active", "inactive", "locked"];

  if (!email) {
    return jsonResponse(400, {
      success: false,
      message: "Vui lòng nhập email.",
    });
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return jsonResponse(400, {
      success: false,
      message: "Email không hợp lệ.",
    });
  }

  if (!validRoles.includes(role)) {
    return jsonResponse(400, {
      success: false,
      message: "Vai trò không hợp lệ.",
    });
  }

  if (!validStatuses.includes(status)) {
    return jsonResponse(400, {
      success: false,
      message: "Trạng thái không hợp lệ.",
    });
  }

  if (password.length < 6) {
    return jsonResponse(400, {
      success: false,
      message: "Mật khẩu tạm thời phải có ít nhất 6 ký tự.",
    });
  }

  const rawOwnerId = (payload.owner_id || "").trim();

  if (role === "worker" && !rawOwnerId) {
    return jsonResponse(400, {
      success: false,
      message: "Vui lòng chọn chủ rừng cho tài khoản này.",
    });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: callerData, error: callerError } =
    await supabase.auth.getUser(token);

  if (callerError || !callerData.user) {
    return jsonResponse(401, {
      success: false,
      message: "Phiên đăng nhập không hợp lệ hoặc đã hết hạn.",
    });
  }

  const { data: callerProfile, error: profileError } = await supabase
    .from("profiles")
    .select("role,status")
    .eq("id", callerData.user.id)
    .maybeSingle();

  if (profileError) {
    return jsonResponse(500, {
      success: false,
      message: "Không thể kiểm tra quyền quản trị viên.",
    });
  }

  if (
    !callerProfile ||
    callerProfile.role !== "admin" ||
    callerProfile.status !== "active"
  ) {
    return jsonResponse(403, {
      success: false,
      message: "Chỉ quản trị viên đang hoạt động mới được tạo tài khoản.",
    });
  }

  if (role === "worker") {
    const { data: ownerRow, error: ownerError } = await supabase
      .from("forest_owners")
      .select("id")
      .eq("id", rawOwnerId)
      .maybeSingle();

    if (ownerError || !ownerRow) {
      return jsonResponse(400, {
        success: false,
        message: "Chủ rừng được chọn không tồn tại.",
      });
    }
  }

  const { data: createdData, error: createError } =
    await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        phone,
        role,
      },
    });

  if (createError || !createdData.user) {
    const message = createError?.message?.toLowerCase() || "";
    return jsonResponse(400, {
      success: false,
      message: message.includes("already") || message.includes("exists") || message.includes("registered")
        ? "Email này đã tồn tại trong hệ thống."
        : createError?.message || "Không thể tạo tài khoản.",
    });
  }

  const createdUserId = createdData.user.id;
  let finalOwnerId: string | null = null;
  let createdOwnerId: string | null = null;

  if (role === "worker") {
    finalOwnerId = rawOwnerId;
  } else if (role === "owner") {
    const { data: linkedOwner, error: lookupError } = await supabase
      .from("forest_owners")
      .select("id")
      .eq("email", email)
      .limit(1)
      .maybeSingle();

    if (lookupError) {
      await supabase.auth.admin.deleteUser(createdUserId);
      return jsonResponse(500, {
        success: false,
        message: "Không thể kiểm tra hồ sơ chủ rừng.",
      });
    }

    const ownerId = linkedOwner?.id || createdUserId;
    const ownerDetails = {
      owner_name: fullName || email,
      email,
      phone,
    };
    const ownerResult = linkedOwner
      ? await supabase
        .from("forest_owners")
        .update(ownerDetails)
        .eq("id", ownerId)
        .select("id")
        .single()
      : await supabase
        .from("forest_owners")
        .insert({
          id: ownerId,
          owner_code: `OWNER-${ownerId.replaceAll("-", "").slice(0, 8).toUpperCase()}`,
          type: "individual",
          ...ownerDetails,
        })
        .select("id")
        .single();
    const { data: ownerRow, error: ownerError } = ownerResult;

    if (ownerError || !ownerRow) {
      await supabase.auth.admin.deleteUser(createdUserId);
      return jsonResponse(500, {
        success: false,
        message: "Không thể tạo hoặc liên kết hồ sơ chủ rừng.",
      });
    }

    if (!linkedOwner) createdOwnerId = ownerRow.id;
    finalOwnerId = ownerRow.id;
  }

  const { error: upsertError } = await supabase.from("profiles").upsert(
    {
      id: createdUserId,
      email,
      full_name: fullName,
      phone,
      role,
      status,
      owner_id: finalOwnerId,
    },
    { onConflict: "id" },
  );

  if (upsertError) {
    if (createdOwnerId) {
      await supabase.from("forest_owners").delete().eq("id", createdOwnerId);
    }
    await supabase.auth.admin.deleteUser(createdUserId);
    return jsonResponse(500, {
      success: false,
      message: "Không thể lưu hồ sơ phân quyền cho tài khoản.",
    });
  }

  return jsonResponse(200, {
    success: true,
    message: "Tạo tài khoản thành công. Người dùng có thể đăng nhập bằng mật khẩu tạm thời.",
  });
});

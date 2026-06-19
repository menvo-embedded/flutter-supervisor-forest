import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type DeleteUserPayload = {
  user_id?: string;
  email?: string;
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

  const token = (req.headers.get("authorization") || "")
    .replace(/^Bearer\s+/i, "")
    .trim();

  if (!token) {
    return jsonResponse(401, {
      success: false,
      message: "Bạn cần đăng nhập để thực hiện thao tác này.",
    });
  }

  let payload: DeleteUserPayload;
  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse(400, {
      success: false,
      message: "Dữ liệu gửi lên không hợp lệ.",
    });
  }

  const userId = (payload.user_id || "").trim();
  const email = (payload.email || "").trim().toLowerCase();

  if (!userId || !email) {
    return jsonResponse(400, {
      success: false,
      message: "Thiếu user_id hoặc email của tài khoản cần xóa.",
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

  const { data: callerProfile, error: callerProfileError } = await supabase
    .from("profiles")
    .select("role,status")
    .eq("id", callerData.user.id)
    .maybeSingle();

  if (callerProfileError) {
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
      message: "Chỉ quản trị viên đang hoạt động mới được xóa tài khoản.",
    });
  }

  if (callerData.user.id === userId) {
    return jsonResponse(400, {
      success: false,
      message: "Bạn không thể tự xóa tài khoản đang đăng nhập.",
    });
  }

  const { data: targetProfile, error: targetProfileError } = await supabase
    .from("profiles")
    .select("id,email,role,owner_id")
    .eq("id", userId)
    .maybeSingle();

  if (targetProfileError) {
    return jsonResponse(500, {
      success: false,
      message: "Không thể kiểm tra tài khoản cần xóa.",
    });
  }

  if (!targetProfile) {
    return jsonResponse(404, {
      success: false,
      message: "Tài khoản không tồn tại trong hồ sơ người dùng.",
    });
  }

  if ((targetProfile.email || "").trim().toLowerCase() !== email) {
    return jsonResponse(400, {
      success: false,
      message: "Email xác nhận không khớp với tài khoản cần xóa.",
    });
  }

  if (targetProfile.role === "admin") {
    const { count: adminCount, error: adminCountError } = await supabase
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("role", "admin");

    if (adminCountError) {
      return jsonResponse(500, {
        success: false,
        message: "Không thể kiểm tra số lượng quản trị viên.",
      });
    }

    if ((adminCount || 0) <= 1) {
      return jsonResponse(400, {
        success: false,
        message: "Không thể xóa quản trị viên cuối cùng trong hệ thống.",
      });
    }
  }

  if (targetProfile.role === "worker") {
    const [checkinsResult, logbooksResult] = await Promise.all([
      supabase
        .from("checkins")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId),
      supabase
        .from("logbooks")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId),
    ]);

    if (checkinsResult.error || logbooksResult.error) {
      return jsonResponse(500, {
        success: false,
        message: "Không thể kiểm tra dữ liệu phát sinh của tài khoản.",
      });
    }

    if ((checkinsResult.count || 0) > 0 || (logbooksResult.count || 0) > 0) {
      return jsonResponse(400, {
        success: false,
        message: "Tài khoản đã có dữ liệu phát sinh. Vui lòng khóa tài khoản thay vì xóa để giữ lịch sử.",
      });
    }
  }

  if (targetProfile.role === "owner" && targetProfile.owner_id) {
    const [projectsResult, workersResult] = await Promise.all([
      supabase
        .from("forest_projects")
        .select("id", { count: "exact", head: true })
        .eq("owner_id", targetProfile.owner_id),
      supabase
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("role", "worker")
        .eq("owner_id", targetProfile.owner_id),
    ]);

    if (projectsResult.error || workersResult.error) {
      return jsonResponse(500, {
        success: false,
        message: "Không thể kiểm tra dữ liệu liên kết của chủ rừng.",
      });
    }

    if ((projectsResult.count || 0) > 0 || (workersResult.count || 0) > 0) {
      return jsonResponse(400, {
        success: false,
        message: "Chủ rừng đang có dự án hoặc nhân viên liên kết. Vui lòng chuyển dữ liệu hoặc khóa tài khoản trước khi xóa.",
      });
    }
  }

  const { error: authDeleteError } = await supabase.auth.admin.deleteUser(userId);
  if (authDeleteError) {
    return jsonResponse(400, {
      success: false,
      message: `Không thể xóa tài khoản đăng nhập: ${authDeleteError.message}`,
    });
  }

  const { error: profileDeleteError } = await supabase
    .from("profiles")
    .delete()
    .eq("id", userId);

  if (profileDeleteError) {
    return jsonResponse(500, {
      success: false,
      message: "Đã xóa tài khoản đăng nhập nhưng không thể xóa hồ sơ người dùng.",
    });
  }

  return jsonResponse(200, {
    success: true,
    message: "Đã xóa tài khoản người dùng thành công.",
  });
});

from pathlib import Path
from datetime import datetime
import re

path = Path(r"D:\qlr-main\flutter-supervisor-forest-dev\web_dashboard\index.html")

if not path.exists():
    raise FileNotFoundError(f"Không tìm thấy file: {path}")

html = path.read_text(encoding="utf-8", errors="ignore")

backup = path.with_name(f"index.backup-password-reset-{datetime.now().strftime('%Y%m%d-%H%M%S')}.html")
backup.write_text(html, encoding="utf-8")

start = "<!-- QLR_PASSWORD_RESET_START -->"
end = "<!-- QLR_PASSWORD_RESET_END -->"

html = re.sub(
    re.escape(start) + r".*?" + re.escape(end),
    "",
    html,
    flags=re.S,
)

block = r'''
<!-- QLR_PASSWORD_RESET_START -->
<style>
  .qlr-reset-modal-backdrop {
    position: fixed;
    inset: 0;
    z-index: 99999;
    background: rgba(15, 23, 42, 0.58);
    display: none;
    align-items: center;
    justify-content: center;
    padding: 18px;
  }

  .qlr-reset-modal-backdrop.show {
    display: flex;
  }

  .qlr-reset-modal {
    width: min(420px, 100%);
    background: #ffffff;
    color: #111827;
    border-radius: 18px;
    box-shadow: 0 28px 80px rgba(15, 23, 42, 0.35);
    padding: 22px;
    font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  }

  .qlr-reset-modal h3 {
    margin: 0 0 8px;
    font-size: 20px;
    font-weight: 800;
  }

  .qlr-reset-modal p {
    margin: 0 0 16px;
    color: #64748b;
    font-size: 14px;
    line-height: 1.5;
  }

  .qlr-reset-field {
    margin-bottom: 12px;
  }

  .qlr-reset-field label {
    display: block;
    margin-bottom: 6px;
    font-size: 13px;
    font-weight: 700;
    color: #334155;
  }

  .qlr-reset-field input {
    width: 100%;
    box-sizing: border-box;
    border: 1px solid #cbd5e1;
    border-radius: 12px;
    padding: 12px 13px;
    outline: none;
    font-size: 14px;
  }

  .qlr-reset-field input:focus {
    border-color: #16a34a;
    box-shadow: 0 0 0 3px rgba(22, 163, 74, 0.16);
  }

  .qlr-reset-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    margin-top: 16px;
  }

  .qlr-reset-btn {
    border: 0;
    border-radius: 12px;
    padding: 11px 14px;
    font-size: 14px;
    font-weight: 800;
    cursor: pointer;
  }

  .qlr-reset-btn.secondary {
    background: #f1f5f9;
    color: #334155;
  }

  .qlr-reset-btn.primary {
    background: #16a34a;
    color: #ffffff;
  }

  .qlr-forgot-password-link {
    display: inline-flex;
    margin-top: 10px;
    border: 0;
    background: transparent;
    color: #16a34a;
    font-weight: 800;
    cursor: pointer;
    font-size: 14px;
    padding: 0;
  }

  .qlr-forgot-floating {
    position: fixed;
    right: 18px;
    bottom: 18px;
    z-index: 9999;
    border: 0;
    border-radius: 999px;
    padding: 12px 16px;
    background: #16a34a;
    color: white;
    font-weight: 800;
    box-shadow: 0 16px 40px rgba(15, 23, 42, 0.25);
    cursor: pointer;
  }
</style>

<div id="qlrForgotPasswordModal" class="qlr-reset-modal-backdrop">
  <div class="qlr-reset-modal">
    <h3>Quên mật khẩu</h3>
    <p>Nhập email tài khoản. Hệ thống sẽ gửi link tạo mật khẩu mới về email.</p>

    <div class="qlr-reset-field">
      <label>Email</label>
      <input id="qlrResetEmailInput" type="email" placeholder="Nhập email của bạn">
    </div>

    <div class="qlr-reset-actions">
      <button type="button" class="qlr-reset-btn secondary" onclick="qlrCloseForgotPasswordModal()">Hủy</button>
      <button type="button" class="qlr-reset-btn primary" onclick="qlrSendPasswordResetEmail()">Gửi link</button>
    </div>
  </div>
</div>

<div id="qlrRecoveryPasswordModal" class="qlr-reset-modal-backdrop">
  <div class="qlr-reset-modal">
    <h3>Tạo mật khẩu mới</h3>
    <p>Nhập mật khẩu mới cho tài khoản của bạn.</p>

    <div class="qlr-reset-field">
      <label>Mật khẩu mới</label>
      <input id="qlrNewPasswordInput" type="password" placeholder="Tối thiểu 6 ký tự">
    </div>

    <div class="qlr-reset-field">
      <label>Xác nhận mật khẩu</label>
      <input id="qlrConfirmPasswordInput" type="password" placeholder="Nhập lại mật khẩu mới">
    </div>

    <div class="qlr-reset-actions">
      <button type="button" class="qlr-reset-btn secondary" onclick="qlrCloseRecoveryPasswordModal()">Đóng</button>
      <button type="button" class="qlr-reset-btn primary" onclick="qlrUpdateRecoveryPassword()">Cập nhật</button>
    </div>
  </div>
</div>

<script>
(function () {
  const QLR_SUPABASE_URL = 'https://idlkismulbicwcxxqakk.supabase.co';
  const QLR_SUPABASE_ANON_KEY = 'sb_publishable_COYn1MjvO-miTOtNrcBYnA_2-7jstbH';

  let qlrPasswordAuthClient = null;

  function qlrToast(message, type = 'info') {
    try {
      if (typeof showToast === 'function') return showToast(message, type);
      if (typeof showNotification === 'function') return showNotification(message, type);
      if (typeof toast === 'function') return toast(message, type);
    } catch (_) {}
    alert(message);
  }

  function qlrLoadScript(src) {
    return new Promise((resolve, reject) => {
      const existed = Array.from(document.scripts).some(s => s.src && s.src.includes(src));
      if (existed) return resolve();

      const script = document.createElement('script');
      script.src = src;
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }

  async function qlrGetAuthClient() {
    try {
      if (typeof supabaseClient !== 'undefined' && supabaseClient && supabaseClient.auth) {
        return supabaseClient;
      }
    } catch (_) {}

    try {
      if (typeof client !== 'undefined' && client && client.auth) {
        return client;
      }
    } catch (_) {}

    if (window.supabaseClient && window.supabaseClient.auth) {
      return window.supabaseClient;
    }

    if (window.client && window.client.auth) {
      return window.client;
    }

    if (window.supabase && window.supabase.auth && !window.supabase.createClient) {
      return window.supabase;
    }

    if (!window.supabase || !window.supabase.createClient) {
      await qlrLoadScript('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2');
    }

    if (!qlrPasswordAuthClient) {
      qlrPasswordAuthClient = window.supabase.createClient(
        QLR_SUPABASE_URL,
        QLR_SUPABASE_ANON_KEY
      );
    }

    return qlrPasswordAuthClient;
  }

  window.getPasswordRedirectUrl = function () {
    const origin = window.location.origin;
    const pathname = window.location.pathname || '/';

    if (pathname.endsWith('/index.html')) {
      return `${origin}${pathname}`;
    }

    if (pathname.endsWith('/')) {
      return `${origin}${pathname}index.html`;
    }

    return `${origin}${pathname}/index.html`;
  };

  if (typeof window.getInviteRedirectUrl !== 'function') {
    window.getInviteRedirectUrl = function () {
      return window.getPasswordRedirectUrl();
    };
  }

  window.qlrOpenForgotPasswordModal = function () {
    const modal = document.getElementById('qlrForgotPasswordModal');
    if (modal) modal.classList.add('show');

    const input = document.getElementById('qlrResetEmailInput');
    if (input) {
      const emailInput = document.querySelector('input[type="email"], input[name="email"], #email');
      if (emailInput && emailInput.value) input.value = emailInput.value.trim();
      setTimeout(() => input.focus(), 80);
    }
  };

  window.qlrCloseForgotPasswordModal = function () {
    const modal = document.getElementById('qlrForgotPasswordModal');
    if (modal) modal.classList.remove('show');
  };

  window.qlrOpenRecoveryPasswordModal = function () {
    const modal = document.getElementById('qlrRecoveryPasswordModal');
    if (modal) modal.classList.add('show');

    const input = document.getElementById('qlrNewPasswordInput');
    if (input) setTimeout(() => input.focus(), 80);
  };

  window.qlrCloseRecoveryPasswordModal = function () {
    const modal = document.getElementById('qlrRecoveryPasswordModal');
    if (modal) modal.classList.remove('show');
  };

  window.qlrSendPasswordResetEmail = async function () {
    const input = document.getElementById('qlrResetEmailInput');
    const email = input ? input.value.trim() : '';

    if (!email) {
      qlrToast('Vui lòng nhập email', 'error');
      return;
    }

    try {
      const authClient = await qlrGetAuthClient();

      const { error } = await authClient.auth.resetPasswordForEmail(email, {
        redirectTo: window.getPasswordRedirectUrl()
      });

      if (error) throw error;

      qlrToast('Đã gửi link đổi mật khẩu. Vui lòng kiểm tra email.', 'success');
      window.qlrCloseForgotPasswordModal();
    } catch (error) {
      console.error('qlrSendPasswordResetEmail error:', error);
      qlrToast(error.message || 'Không thể gửi link đổi mật khẩu', 'error');
    }
  };

  window.qlrUpdateRecoveryPassword = async function () {
    const newPassword = document.getElementById('qlrNewPasswordInput')?.value || '';
    const confirmPassword = document.getElementById('qlrConfirmPasswordInput')?.value || '';

    if (!newPassword || newPassword.length < 6) {
      qlrToast('Mật khẩu phải có ít nhất 6 ký tự', 'error');
      return;
    }

    if (newPassword !== confirmPassword) {
      qlrToast('Mật khẩu xác nhận không khớp', 'error');
      return;
    }

    try {
      const authClient = await qlrGetAuthClient();

      const { error } = await authClient.auth.updateUser({
        password: newPassword
      });

      if (error) throw error;

      qlrToast('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.', 'success');
      window.qlrCloseRecoveryPasswordModal();

      try {
        await authClient.auth.signOut();
      } catch (_) {}

      const cleanUrl = `${window.location.origin}${window.location.pathname}`;
      window.history.replaceState({}, document.title, cleanUrl);
    } catch (error) {
      console.error('qlrUpdateRecoveryPassword error:', error);
      qlrToast(error.message || 'Không thể đổi mật khẩu', 'error');
    }
  };

  function qlrAddForgotPasswordButton() {
    const existed = Array.from(document.querySelectorAll('button, a'))
      .some(el => (el.textContent || '').toLowerCase().includes('quên mật khẩu'));

    if (existed) return;

    const passwordInput = document.querySelector('input[type="password"]');
    const loginForm = passwordInput ? passwordInput.closest('form') : null;
    const loginBox = loginForm || (passwordInput ? passwordInput.parentElement : null);

    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = loginBox ? 'qlr-forgot-password-link' : 'qlr-forgot-floating';
    btn.textContent = 'Quên mật khẩu?';
    btn.addEventListener('click', window.qlrOpenForgotPasswordModal);

    if (loginBox) {
      loginBox.appendChild(btn);
    } else {
      document.body.appendChild(btn);
    }
  }

  async function qlrHandlePasswordRecoveryRedirect() {
    try {
      const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''));
      const searchParams = new URLSearchParams(window.location.search);

      const hashType = hashParams.get('type');
      const searchType = searchParams.get('type');
      const code = searchParams.get('code');

      const isRecovery =
        hashType === 'recovery' ||
        searchType === 'recovery' ||
        window.location.hash.includes('type=recovery') ||
        window.location.search.includes('type=recovery');

      const authClient = await qlrGetAuthClient();

      try {
        authClient.auth.onAuthStateChange((event) => {
          if (event === 'PASSWORD_RECOVERY') {
            window.qlrOpenRecoveryPasswordModal();
          }
        });
      } catch (_) {}

      if (code) {
        const { error } = await authClient.auth.exchangeCodeForSession(code);
        if (error) {
          console.error('exchangeCodeForSession error:', error);
        }
      }

      if (isRecovery || code) {
        window.qlrOpenRecoveryPasswordModal();
      }
    } catch (error) {
      console.error('qlrHandlePasswordRecoveryRedirect error:', error);
    }
  }

  function qlrInitPasswordReset() {
    qlrAddForgotPasswordButton();
    qlrHandlePasswordRecoveryRedirect();

    setTimeout(qlrAddForgotPasswordButton, 800);
    setTimeout(qlrAddForgotPasswordButton, 1800);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', qlrInitPasswordReset);
  } else {
    qlrInitPasswordReset();
  }
})();
</script>
<!-- QLR_PASSWORD_RESET_END -->
'''

if "</body>" in html:
    html = html.replace("</body>", block + "\n</body>", 1)
else:
    html += "\n" + block

path.write_text(html, encoding="utf-8")

print("DONE")
print(f"Patched: {path}")
print(f"Backup : {backup}")

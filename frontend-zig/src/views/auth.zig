// src/views/auth.zig - Màn hình đăng nhập và đăng ký
// DevOps Sentinel Frontend - Zig 0.16.0

const std = @import("std");
const js = @import("../js.zig");
const state = @import("../state.zig");
const routing = @import("../routing.zig");
const api = @import("../api/calls.zig");
const helpers = @import("helpers.zig");

// ============================================================
// ĐĂNG NHẬP
// ============================================================

var _dang_nhap_busy = false;

pub fn hienThiTrangDangNhap() void {
    if (state.layTrangThai().daDangNhap()) {
        routing.chuyenHuong("#/dashboard");
        return;
    }

    const app = js.getElementById("app");
    if (!js.isValid(app)) return;
    js.clearChildren(app);

    const container = js.createElement("div");
    js.addClass(container, "auth-container");
    js.setInnerHtml(container,
        \\<div class="auth-card">
        \\  <div class="brand-header">
        \\    <div class="brand-logo-wrap">
        \\      <div class="brand-logo">🛡️</div>
        \\      <div class="brand-glow"></div>
        \\    </div>
        \\    <h1>DevOps Sentinel</h1>
        \\    <p>Hệ thống giám sát triển khai tự động CI/CD</p>
        \\  </div>
        \\
        \\  <div class="demo-accounts-box">
        \\    <span class="demo-title">⚡ Chọn nhanh tài khoản Demo:</span>
        \\    <div class="demo-buttons">
        \\      <button type="button" class="btn-demo" id="demo-admin" title="Admin">
        \\        <span class="demo-role admin">Admin</span>
        \\      </button>
        \\      <button type="button" class="btn-demo" id="demo-lead" title="Team Lead">
        \\        <span class="demo-role lead">Team Lead</span>
        \\      </button>
        \\      <button type="button" class="btn-demo" id="demo-viewer" title="Viewer">
        \\        <span class="demo-role viewer">Viewer</span>
        \\      </button>
        \\    </div>
        \\  </div>
        \\
        \\  <form id="form-dang-nhap" class="form-wrapper" onsubmit="return false;">
        \\    <div class="form-group">
        \\      <label for="input-email">Địa chỉ Email</label>
        \\      <div class="input-with-icon">
        \\        <span class="input-icon">✉️</span>
        \\        <input type="email" id="input-email" placeholder="tenban@congty.com"
        \\               value="admin@devops-sentinel.local" required autocomplete="email" />
        \\      </div>
        \\    </div>
        \\    <div class="form-group">
        \\      <label for="input-password">Mật khẩu</label>
        \\      <div class="input-with-icon">
        \\        <span class="input-icon">🔒</span>
        \\        <input type="password" id="input-password" placeholder="••••••••"
        \\               value="Sentinel@123456" required autocomplete="current-password" />
        \\      </div>
        \\    </div>
        \\    <div id="auth-alert" class="alert-box" style="display: none;"></div>
        \\    <button type="submit" id="btn-dang-nhap" class="btn btn-primary btn-block">
        \\      <span class="btn-text">Đăng Nhập</span>
        \\    </button>
        \\    <div class="auth-footer">
        \\      Chưa có tài khoản? <a href="#/register">Đăng ký thành viên mới</a>
        \\    </div>
        \\  </form>
        \\</div>
    );
    js.appendChild(app, container);

    // Gắn sự kiện demo accounts
    ganDemoAccount("demo-admin", "admin@devops-sentinel.local", "Sentinel@123456");
    ganDemoAccount("demo-lead", "lead@devops-sentinel.local", "Sentinel@123456");
    ganDemoAccount("demo-viewer", "viewer@devops-sentinel.local", "Sentinel@123456");

    // Gắn sự kiện đăng nhập
    const btn = js.getElementById("btn-dang-nhap");
    if (js.isValid(btn)) {
        const cb_id = routing.allocEvent(xuLyDangNhap);
        js.addEventListener(btn, "click", cb_id);
    }

    const form = js.getElementById("form-dang-nhap");
    if (js.isValid(form)) {
        const cb_id = routing.allocEvent(xuLyDangNhap);
        js.addEventListener(form, "submit", cb_id);
    }
}

fn ganDemoAccount(btn_id: []const u8, email: []const u8, mat_khau: []const u8) void {
    _ = email;
    _ = mat_khau;
    const btn = js.getElementById(btn_id);
    if (!js.isValid(btn)) return;
    // Note: Zig closures don't capture variables easily, so we use a workaround
    // Mỗi demo button gắn callback riêng
    if (std.mem.eql(u8, btn_id, "demo-admin")) {
        const cb_id = routing.allocEvent(onClickDemoAdmin);
        js.addEventListener(btn, "click", cb_id);
    } else if (std.mem.eql(u8, btn_id, "demo-lead")) {
        const cb_id = routing.allocEvent(onClickDemoLead);
        js.addEventListener(btn, "click", cb_id);
    } else if (std.mem.eql(u8, btn_id, "demo-viewer")) {
        const cb_id = routing.allocEvent(onClickDemoViewer);
        js.addEventListener(btn, "click", cb_id);
    }
}

fn setDemoAccount(email: []const u8, mat_khau: []const u8) void {
    const inp_email = js.getElementById("input-email");
    const inp_pass = js.getElementById("input-password");
    if (js.isValid(inp_email)) js.setValue(inp_email, email);
    if (js.isValid(inp_pass)) js.setValue(inp_pass, mat_khau);
    var msg_buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "ℹ️ Đã nạp tài khoản: {s}", .{email}) catch return;
    helpers.hienThiThongBaoAuth("auth-alert", "info", msg);
}

fn onClickDemoAdmin() void {
    setDemoAccount("admin@devops-sentinel.local", "Sentinel@123456");
}
fn onClickDemoLead() void {
    setDemoAccount("lead@devops-sentinel.local", "Sentinel@123456");
}
fn onClickDemoViewer() void {
    setDemoAccount("viewer@devops-sentinel.local", "Sentinel@123456");
}

fn xuLyDangNhap() void {
    if (_dang_nhap_busy) return;

    var email_buf: [256]u8 = undefined;
    var pass_buf: [256]u8 = undefined;

    const inp_email = js.getElementById("input-email");
    const inp_pass = js.getElementById("input-password");

    if (!js.isValid(inp_email) or !js.isValid(inp_pass)) return;

    const email = js.getValue(inp_email, &email_buf);
    const mat_khau = js.getValue(inp_pass, &pass_buf);

    const email_trim = std.mem.trim(u8, email, " \t");
    if (email_trim.len == 0 or mat_khau.len == 0) {
        helpers.hienThiThongBaoAuth("auth-alert", "error", "Vui lòng nhập đầy đủ Email và Mật khẩu.");
        return;
    }

    _dang_nhap_busy = true;

    const btn = js.getElementById("btn-dang-nhap");
    if (js.isValid(btn)) {
        js.setAttribute(btn, "disabled", "true");
        js.setInnerHtml(btn, "<span class=\"spinner-sm\"></span> Đang xác thực...");
    }

    api.dangNhap(email_trim, mat_khau, onDangNhapResponse);
}

fn onDangNhapResponse(err: ?[]const u8) void {
    _dang_nhap_busy = false;

    const btn = js.getElementById("btn-dang-nhap");
    if (js.isValid(btn)) {
        js.removeAttribute(btn, "disabled");
        js.setInnerHtml(btn, "<span class=\"btn-text\">Đăng Nhập</span>");
    }

    if (err) |e| {
        var msg_buf: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "❌ Đăng nhập thất bại: {s}", .{e}) catch return;
        helpers.hienThiThongBaoAuth("auth-alert", "error", msg);
    } else {
        helpers.hienThiThongBaoAuth("auth-alert", "success", "✅ Xác thực thành công! Đang chuyển hướng...");
        routing.chuyenHuong("#/dashboard");
    }
}

// ============================================================
// ĐĂNG KÝ
// ============================================================

var _dang_ky_busy = false;

pub fn hienThiTrangDangKy() void {
    if (state.layTrangThai().daDangNhap()) {
        routing.chuyenHuong("#/dashboard");
        return;
    }

    const app = js.getElementById("app");
    if (!js.isValid(app)) return;
    js.clearChildren(app);

    const container = js.createElement("div");
    js.addClass(container, "auth-container");
    js.setInnerHtml(container,
        \\<div class="auth-card">
        \\  <div class="brand-header">
        \\    <div class="brand-logo-wrap">
        \\      <div class="brand-logo">🛡️</div>
        \\      <div class="brand-glow"></div>
        \\    </div>
        \\    <h1>Tạo Tài Khoản Mới</h1>
        \\    <p>Gia nhập DevOps Sentinel để giám sát CI/CD toàn diện</p>
        \\  </div>
        \\
        \\  <form id="form-dang-ky" class="form-wrapper" onsubmit="return false;">
        \\    <div class="form-group">
        \\      <label for="input-name">Họ và Tên</label>
        \\      <div class="input-with-icon">
        \\        <span class="input-icon">👤</span>
        \\        <input type="text" id="input-name" placeholder="Nguyễn Văn A" required />
        \\      </div>
        \\    </div>
        \\    <div class="form-group">
        \\      <label for="input-email">Địa chỉ Email</label>
        \\      <div class="input-with-icon">
        \\        <span class="input-icon">✉️</span>
        \\        <input type="email" id="input-email" placeholder="dev@congty.com" required autocomplete="email" />
        \\      </div>
        \\    </div>
        \\    <div class="form-group">
        \\      <label for="input-password">Mật khẩu</label>
        \\      <div class="input-with-icon">
        \\        <span class="input-icon">🔒</span>
        \\        <input type="password" id="input-password" placeholder="Tối thiểu 6 ký tự" required autocomplete="new-password" />
        \\      </div>
        \\    </div>
        \\    <div class="form-group">
        \\      <label for="input-password-confirm">Xác nhận Mật khẩu</label>
        \\      <div class="input-with-icon">
        \\        <span class="input-icon">🛡️</span>
        \\        <input type="password" id="input-password-confirm" placeholder="Nhập lại mật khẩu trên" required autocomplete="new-password" />
        \\      </div>
        \\    </div>
        \\    <div id="auth-alert" class="alert-box" style="display: none;"></div>
        \\    <button type="submit" id="btn-dang-ky" class="btn btn-primary btn-block">
        \\      <span class="btn-text">Tạo Tài Khoản</span>
        \\    </button>
        \\    <div class="auth-footer">
        \\      Đã có tài khoản? <a href="#/login">Quay lại Đăng nhập</a>
        \\    </div>
        \\  </form>
        \\</div>
    );
    js.appendChild(app, container);

    const btn = js.getElementById("btn-dang-ky");
    if (js.isValid(btn)) {
        const cb_id = routing.allocEvent(xuLyDangKy);
        js.addEventListener(btn, "click", cb_id);
    }

    const form = js.getElementById("form-dang-ky");
    if (js.isValid(form)) {
        const cb_id = routing.allocEvent(xuLyDangKy);
        js.addEventListener(form, "submit", cb_id);
    }
}

fn xuLyDangKy() void {
    if (_dang_ky_busy) return;

    var ten_buf: [256]u8 = undefined;
    var email_buf: [256]u8 = undefined;
    var pass_buf: [256]u8 = undefined;
    var xac_nhan_buf: [256]u8 = undefined;

    const inp_ten = js.getElementById("input-name");
    const inp_email = js.getElementById("input-email");
    const inp_pass = js.getElementById("input-password");
    const inp_xac_nhan = js.getElementById("input-password-confirm");

    const ten = std.mem.trim(u8, js.getValue(inp_ten, &ten_buf), " \t");
    const email = std.mem.trim(u8, js.getValue(inp_email, &email_buf), " \t");
    const mat_khau = js.getValue(inp_pass, &pass_buf);
    const xac_nhan = js.getValue(inp_xac_nhan, &xac_nhan_buf);

    if (ten.len == 0 or email.len == 0 or mat_khau.len == 0) {
        helpers.hienThiThongBaoAuth("auth-alert", "error", "Vui lòng điền đầy đủ các thông tin bắt buộc.");
        return;
    }

    if (mat_khau.len < 6) {
        helpers.hienThiThongBaoAuth("auth-alert", "error", "Mật khẩu phải có độ dài tối thiểu 6 ký tự.");
        return;
    }

    if (!std.mem.eql(u8, mat_khau, xac_nhan)) {
        helpers.hienThiThongBaoAuth("auth-alert", "error", "Mật khẩu xác nhận không trùng khớp.");
        return;
    }

    _dang_ky_busy = true;

    const btn = js.getElementById("btn-dang-ky");
    if (js.isValid(btn)) {
        js.setAttribute(btn, "disabled", "true");
        js.setInnerHtml(btn, "<span class=\"spinner-sm\"></span> Đang tạo tài khoản...");
    }

    api.dangKy(ten, email, mat_khau, xac_nhan, onDangKyResponse);
}

fn onDangKyResponse(err: ?[]const u8) void {
    _dang_ky_busy = false;

    const btn = js.getElementById("btn-dang-ky");
    if (js.isValid(btn)) {
        js.removeAttribute(btn, "disabled");
        js.setInnerHtml(btn, "<span class=\"btn-text\">Tạo Tài Khoản</span>");
    }

    if (err) |e| {
        var msg_buf: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "❌ Đăng ký không thành công: {s}", .{e}) catch return;
        helpers.hienThiThongBaoAuth("auth-alert", "error", msg);
    } else {
        helpers.hienThiThongBaoAuth("auth-alert", "success", "✅ Tạo tài khoản thành công! Đang chuyển hướng...");
        routing.chuyenHuong("#/dashboard");
    }
}

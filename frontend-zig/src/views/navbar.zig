// src/views/navbar.zig - Thanh điều hướng chung
// DevOps Sentinel Frontend - Zig 0.16.0

const std = @import("std");
const js = @import("../js.zig");
const state = @import("../state.zig");
const routing = @import("../routing.zig");
const api = @import("../api/calls.zig");
const helpers = @import("helpers.zig");

/// Tạo và trả về handle của thanh điều hướng Navbar
/// tab_hien_tai: "dashboard", "projects", "alerts", "teams"
pub fn taoThanhDieuHuong(tab_hien_tai: []const u8) js.DomHandle {
    const tt = state.layTrangThai();

    var ten_nd: []const u8 = "Người dùng";
    var vai_tro: []const u8 = "viewer";
    if (tt.nguoi_dung) |nd| {
        ten_nd = nd.getName();
        vai_tro = nd.getRole();
    }

    // Badge vai trò
    var lop_vai_tro: []const u8 = "badge-role-viewer";
    var ten_hien_thi_vai_tro: []const u8 = "Viewer";
    if (std.mem.eql(u8, vai_tro, "admin")) {
        lop_vai_tro = "badge-role-admin";
        ten_hien_thi_vai_tro = "Admin";
    } else if (std.mem.eql(u8, vai_tro, "team_lead")) {
        lop_vai_tro = "badge-role-lead";
        ten_hien_thi_vai_tro = "Team Lead";
    }

    // Active tabs
    const active_db = if (std.mem.eql(u8, tab_hien_tai, "dashboard")) "active" else "";
    const active_proj = if (std.mem.eql(u8, tab_hien_tai, "projects")) "active" else "";
    const active_alert = if (std.mem.eql(u8, tab_hien_tai, "alerts")) "active" else "";
    const active_teams = if (std.mem.eql(u8, tab_hien_tai, "teams")) "active" else "";

    // Polling badge
    const polling_html: []const u8 = if (tt.polling_kich_hoat)
        "<span class=\"pulse-dot-live\"></span> Live (4s)"
    else
        "⏸️ Tạm dừng";
    const polling_class: []const u8 = if (tt.polling_kich_hoat)
        "badge badge-live"
    else
        "badge badge-live paused";

    var chu_cai_buf: [4]u8 = undefined;
    const chu_cai = helpers.layChuCaiDau(ten_nd, &chu_cai_buf);

    const thanh_nav = js.createElement("header");
    if (!js.isValid(thanh_nav)) return js.INVALID_HANDLE;
    js.addClass(thanh_nav, "app-navbar");

    var nav_html: [4096]u8 = undefined;
    const html = std.fmt.bufPrint(&nav_html,
        \\<div class="nav-left">
        \\  <a href="#/dashboard" class="nav-brand">
        \\    <span class="brand-radar">
        \\      <span class="radar-dot"></span>
        \\      <span class="radar-wave"></span>
        \\    </span>
        \\    <span class="brand-name">DevOps Sentinel</span>
        \\    <span class="badge badge-wasm">Zig v1.0</span>
        \\  </a>
        \\  <nav class="nav-menu">
        \\    <a href="#/dashboard" class="nav-link {s}"><span class="icon">📊</span> Tổng quan</a>
        \\    <a href="#/projects" class="nav-link {s}"><span class="icon">📁</span> Dự án</a>
        \\    <a href="#/alerts" class="nav-link {s}"><span class="icon">🚨</span> Cảnh báo</a>
        \\    <a href="#/teams" class="nav-link {s}"><span class="icon">👥</span> Nhóm</a>
        \\  </nav>
        \\</div>
        \\<div class="nav-user">
        \\  <button id="btn-toggle-polling" class="{s}" title="Bật/Tắt cập nhật thời gian thực">{s}</button>
        \\  <div class="user-profile-chip">
        \\    <div class="user-avatar">{s}</div>
        \\    <div class="user-meta">
        \\      <span class="user-name">{s}</span>
        \\      <span class="badge {s}">{s}</span>
        \\    </div>
        \\  </div>
        \\  <button id="btn-dang-xuat" class="btn btn-outline btn-sm btn-logout" title="Đăng xuất">
        \\    <span>🚪</span> Đăng xuất
        \\  </button>
        \\</div>
    , .{
        active_db, active_proj, active_alert, active_teams,
        polling_class, polling_html,
        chu_cai, ten_nd, lop_vai_tro, ten_hien_thi_vai_tro,
    }) catch return thanh_nav;

    js.setInnerHtml(thanh_nav, html);

    // Gắn sự kiện toggle polling
    const btn_polling = js.querySelector(thanh_nav, "#btn-toggle-polling");
    if (js.isValid(btn_polling)) {
        const cb_id = routing.allocEvent(onTogglePolling);
        js.addEventListener(btn_polling, "click", cb_id);
    }

    // Gắn sự kiện đăng xuất
    const btn_xuat = js.querySelector(thanh_nav, "#btn-dang-xuat");
    if (js.isValid(btn_xuat)) {
        const cb_id = routing.allocEvent(onDangXuat);
        js.addEventListener(btn_xuat, "click", cb_id);
    }

    return thanh_nav;
}

var _navbar_handle: js.DomHandle = js.INVALID_HANDLE;

fn onTogglePolling() void {
    const tt = state.layTrangThai();
    const kich_hoat = tt.chuyenDoiPolling();

    const btn = js.getElementById("btn-toggle-polling");
    if (!js.isValid(btn)) return;

    if (kich_hoat) {
        js.removeClass(btn, "paused");
        js.setInnerHtml(btn, "<span class=\"pulse-dot-live\"></span> Live (4s)");
    } else {
        js.addClass(btn, "paused");
        js.setInnerHtml(btn, "⏸️ Tạm dừng");
    }
}

fn onDangXuat() void {
    api.dangXuat();
    routing.chuyenHuong("#/login");
}

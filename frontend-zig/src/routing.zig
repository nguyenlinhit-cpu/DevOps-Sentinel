// src/routing.zig - Hash-based router cho Zig WASM
// DevOps Sentinel Frontend - Zig 0.16.0
//
// Tương đương với dieu_huong.go trong frontend Go.

const std = @import("std");
const js = @import("js.zig");
const state = @import("state.zig");

// ============================================================
// KIỂU DỮ LIỆU
// ============================================================

/// Callback điều hướng nhận đường dẫn và tham số động
pub const RouteHandler = *const fn (path: []const u8, params: RouteParams) void;

pub const RouteParams = struct {
    id: ?[]const u8 = null,
    // Lưu tham số trong buffer tĩnh
    id_buf: [64]u8 = [_]u8{0} ** 64,
    id_len: usize = 0,

    pub fn getId(self: *const RouteParams) ?[]const u8 {
        if (self.id_len == 0) return null;
        return self.id_buf[0..self.id_len];
    }
};

// ============================================================
// CÁC TUYẾN ĐƯỜNG
// ============================================================

const Route = struct {
    pattern: []const u8,
    handler: RouteHandler,
    has_dynamic_segment: bool = false,
    param_name: []const u8 = "",
};

const MAX_ROUTES = 32;

var routes: [MAX_ROUTES]Route = undefined;
var route_count: usize = 0;
var not_found_handler: ?RouteHandler = null;
var default_route: []const u8 = "#/dashboard";
var hashchange_callback_id: u32 = 100; // ID cố định cho hashchange

// ID event callbacks
const EVENT_HASHCHANGE: u32 = 100;

/// Export được gọi từ JS khi có sự kiện
export fn wasm_dispatch_event(callback_id: u32) void {
    switch (callback_id) {
        EVENT_HASHCHANGE => {
            dieu_phoi();
        },
        else => {
            // Delegate tới event handler registry
            dispatchEventCallback(callback_id);
        },
    }
}

// ============================================================
// REGISTRY SỰ KIỆN (EVENT CALLBACKS)
// ============================================================

const EventEntry = struct {
    active: bool = false,
    handler: *const fn () void = undefined,
};

const MAX_EVENTS = 256;
var event_callbacks: [MAX_EVENTS]EventEntry = [_]EventEntry{.{}} ** MAX_EVENTS;
var next_event_id: u32 = 200;

pub fn allocEvent(handler: *const fn () void) u32 {
    var i: u32 = 0;
    while (i < MAX_EVENTS) : (i += 1) {
        if (!event_callbacks[i].active) {
            event_callbacks[i] = .{ .active = true, .handler = handler };
            const id = next_event_id;
            next_event_id += 1;
            _ = id;
            return i + 200; // ID = index + 200 offset
        }
    }
    return 0;
}

pub fn freeEvent(callback_id: u32) void {
    if (callback_id < 200) return;
    const slot = callback_id - 200;
    if (slot < MAX_EVENTS) {
        event_callbacks[slot].active = false;
    }
}

fn dispatchEventCallback(callback_id: u32) void {
    if (callback_id < 200) return;
    const slot = callback_id - 200;
    if (slot >= MAX_EVENTS) return;
    if (event_callbacks[slot].active) {
        event_callbacks[slot].handler();
    }
}

// ============================================================
// ĐĂNG KÝ TUYẾN ĐƯỜNG
// ============================================================

pub fn dangKy(pattern: []const u8, handler: RouteHandler) void {
    if (route_count >= MAX_ROUTES) return;

    var has_dynamic = false;
    var param_name: []const u8 = "";

    // Kiểm tra có segment động không (ví dụ: {id})
    if (std.mem.indexOf(u8, pattern, "{")) |start| {
        if (std.mem.indexOf(u8, pattern, "}")) |end| {
            has_dynamic = true;
            param_name = pattern[start+1..end];
        }
    }

    routes[route_count] = .{
        .pattern = pattern,
        .handler = handler,
        .has_dynamic_segment = has_dynamic,
        .param_name = param_name,
    };
    route_count += 1;
}

pub fn dangKyKhongTimThay(handler: RouteHandler) void {
    not_found_handler = handler;
}

// ============================================================
// CHUYỂN HƯỚNG
// ============================================================

pub fn chuyenHuong(hash: []const u8) void {
    js.setHash(hash);
    dieu_phoi();
}

pub fn layDuongDanHienTai(buf: []u8) []u8 {
    return js.getHash(buf);
}

// ============================================================
// KHỞI CHẠY ROUTER
// ============================================================

pub fn khoiChay() void {
    js.listenHashchange(EVENT_HASHCHANGE);
    dieu_phoi();
}

// ============================================================
// ĐIỀU PHỐI
// ============================================================

pub fn dieu_phoi() void {
    js.scrollToTop();

    var hash_buf: [256]u8 = undefined;
    const hash = js.getHash(&hash_buf);

    const tt = state.layTrangThai();

    // Nếu không có hash, điều hướng về mặc định
    if (hash.len == 0 or std.mem.eql(u8, hash, "#")) {
        if (tt.daDangNhap()) {
            chuyenHuong(default_route);
        } else {
            chuyenHuong("#/login");
        }
        return;
    }

    // Bảo vệ route: chưa đăng nhập mà vào trang nội bộ
    const is_public = std.mem.eql(u8, hash, "#/login") or std.mem.eql(u8, hash, "#/register");
    if (!tt.daDangNhap() and !is_public) {
        chuyenHuong("#/login");
        return;
    }

    // Đã đăng nhập mà vào login/register
    if (tt.daDangNhap() and is_public) {
        chuyenHuong(default_route);
        return;
    }

    // Tìm tuyến đường khớp chính xác
    var i: usize = 0;
    while (i < route_count) : (i += 1) {
        const route = routes[i];
        if (std.mem.eql(u8, route.pattern, hash) and !route.has_dynamic_segment) {
            route.handler(hash, .{});
            return;
        }
    }

    // Tìm tuyến đường động
    i = 0;
    while (i < route_count) : (i += 1) {
        const route = routes[i];
        if (!route.has_dynamic_segment) continue;

        var params = RouteParams{};
        if (matchDynamic(route.pattern, hash, &params)) {
            route.handler(hash, params);
            return;
        }
    }

    // 404
    if (not_found_handler) |handler| {
        handler(hash, .{});
    } else {
        chuyenHuong(default_route);
    }
}

/// Kiểm tra xem hash có khớp với pattern động không
/// Ví dụ: pattern="#/projects/{id}", hash="#/projects/42" → id="42"
fn matchDynamic(pattern: []const u8, actual: []const u8, params: *RouteParams) bool {
    // Tách theo "/"
    var pat_parts: [8][]const u8 = undefined;
    var act_parts: [8][]const u8 = undefined;
    var pat_count: usize = 0;
    var act_count: usize = 0;

    // Parse pattern
    var iter = std.mem.splitScalar(u8, pattern, '/');
    while (iter.next()) |part| {
        if (pat_count >= 8) break;
        pat_parts[pat_count] = part;
        pat_count += 1;
    }

    // Parse actual
    var iter2 = std.mem.splitScalar(u8, actual, '/');
    while (iter2.next()) |part| {
        if (act_count >= 8) break;
        act_parts[act_count] = part;
        act_count += 1;
    }

    if (pat_count != act_count) return false;

    var j: usize = 0;
    while (j < pat_count) : (j += 1) {
        const pp = pat_parts[j];
        const ap = act_parts[j];

        if (pp.len > 2 and pp[0] == '{' and pp[pp.len-1] == '}') {
            // Dynamic segment - lưu giá trị
            const n = @min(ap.len, params.id_buf.len - 1);
            @memcpy(params.id_buf[0..n], ap[0..n]);
            params.id_len = n;
        } else if (!std.mem.eql(u8, pp, ap)) {
            return false;
        }
    }

    return true;
}

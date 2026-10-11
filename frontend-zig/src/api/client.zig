// src/api/client.zig - HTTP API Client cho Zig WASM
// DevOps Sentinel Frontend - Zig 0.16.0
//
// Sử dụng async callback pattern qua js_fetch extern.
// Mọi request đều async - kết quả trả về qua wasm_fetch_callback export.

const std = @import("std");
const js = @import("../js.zig");
const state = @import("../state.zig");

// ============================================================
// HỆ THỐNG CALLBACK ASYNC
// ============================================================

/// Callback function type cho API response
pub const FetchCallback = *const fn (status: u32, body: []const u8) void;

/// Bảng lưu callbacks đang chờ (max 64 concurrent requests)
const MAX_CALLBACKS = 64;
const CallbackEntry = struct {
    active: bool = false,
    callback: FetchCallback = undefined,
};

var callbacks: [MAX_CALLBACKS]CallbackEntry = [_]CallbackEntry{.{}} ** MAX_CALLBACKS;
var next_callback_id: u32 = 1;

fn allocCallback(cb: FetchCallback) u32 {
    var i: u32 = 0;
    while (i < MAX_CALLBACKS) : (i += 1) {
        if (!callbacks[i].active) {
            callbacks[i] = .{ .active = true, .callback = cb };
            const id = next_callback_id;
            next_callback_id += 1;
            if (next_callback_id == 0) next_callback_id = 1;
            // Lưu id thực trong slot
            _ = id;
            return i + 1; // callback_id = slot index + 1
        }
    }
    return 0; // Hết slot
}

/// Export function: được JavaScript gọi khi fetch hoàn thành
export fn wasm_fetch_callback(callback_id: u32, status: u32, body_ptr: [*]const u8, body_len: usize) void {
    const slot = callback_id - 1;
    if (slot >= MAX_CALLBACKS) return;
    if (!callbacks[slot].active) return;

    const cb = callbacks[slot].callback;
    callbacks[slot].active = false;
    const body = body_ptr[0..body_len];
    cb(status, body);
}

// ============================================================
// TIỆN ÍCH XÂY DỰNG URL
// ============================================================

var api_base: [256]u8 = [_]u8{0} ** 256;
var api_base_len: usize = 0;

pub fn khoiTaoApiBase() void {
    var hostname_buf: [128]u8 = undefined;
    const hostname = js.getHostname(&hostname_buf);
    if (hostname.len == 0) {
        const default = "http://localhost:8000/api/v1";
        @memcpy(api_base[0..default.len], default);
        api_base_len = default.len;
    } else {
        var buf: [256]u8 = undefined;
        const result = std.fmt.bufPrint(&buf, "http://{s}:8000/api/v1", .{hostname}) catch {
            const default = "http://localhost:8000/api/v1";
            @memcpy(api_base[0..default.len], default);
            api_base_len = default.len;
            return;
        };
        @memcpy(api_base[0..result.len], result);
        api_base_len = result.len;
    }
}

fn buildUrl(path: []const u8, buf: []u8) []u8 {
    const base = api_base[0..api_base_len];
    const total = base.len + path.len;
    if (total > buf.len) return buf[0..0];
    @memcpy(buf[0..base.len], base);
    @memcpy(buf[base.len..total], path);
    return buf[0..total];
}

// ============================================================
// HÀM GỌI API
// ============================================================

/// Thực hiện HTTP GET request (có auth)
pub fn get(path: []const u8, callback: FetchCallback) void {
    getAuth(path, true, callback);
}

/// GET không cần auth
pub fn getNoAuth(path: []const u8, callback: FetchCallback) void {
    getAuth(path, false, callback);
}

fn getAuth(path: []const u8, need_auth: bool, callback: FetchCallback) void {
    var url_buf: [512]u8 = undefined;
    const url = buildUrl(path, &url_buf);

    const tt = state.layTrangThai();
    const token = if (need_auth) tt.getAccessToken() else "";

    const cb_id = allocCallback(callback);
    if (cb_id == 0) {
        js.logError("API client: Hết slot callback!", .{});
        return;
    }

    js.fetch(url, "GET", "", token, cb_id);
}

/// POST request (có auth, có body JSON)
pub fn post(path: []const u8, body: []const u8, callback: FetchCallback) void {
    postAuth(path, body, true, callback);
}

/// POST không cần auth
pub fn postNoAuth(path: []const u8, body: []const u8, callback: FetchCallback) void {
    postAuth(path, body, false, callback);
}

fn postAuth(path: []const u8, body: []const u8, need_auth: bool, callback: FetchCallback) void {
    var url_buf: [512]u8 = undefined;
    const url = buildUrl(path, &url_buf);

    const tt = state.layTrangThai();
    const token = if (need_auth) tt.getAccessToken() else "";

    const cb_id = allocCallback(callback);
    if (cb_id == 0) return;

    js.fetch(url, "POST", body, token, cb_id);
}

/// DELETE request (có auth)
pub fn delete(path: []const u8, callback: FetchCallback) void {
    var url_buf: [512]u8 = undefined;
    const url = buildUrl(path, &url_buf);

    const tt = state.layTrangThai();
    const token = tt.getAccessToken();

    const cb_id = allocCallback(callback);
    if (cb_id == 0) return;

    js.fetch(url, "DELETE", "", token, cb_id);
}

// ============================================================
// KIỂM TRA RESPONSE
// ============================================================

/// Kiểm tra xem response có thành công không (success:true)
pub fn isSuccess(body: []const u8) bool {
    const idx = std.mem.indexOf(u8, body, "\"success\":true") orelse
                std.mem.indexOf(u8, body, "\"success\": true") orelse
                return false;
    _ = idx;
    return true;
}

/// Trích xuất thông báo lỗi từ response JSON
pub fn extractError(body: []const u8, buf: []u8) []u8 {
    // Tìm error.message
    if (std.mem.indexOf(u8, body, "\"error\":")) |_| {
        if (std.mem.indexOf(u8, body, "\"message\":")) |start| {
            var pos = start + 10;
            while (pos < body.len and (body[pos] == ' ' or body[pos] == '\t')) pos += 1;
            if (pos < body.len and body[pos] == '"') {
                pos += 1;
                var end = pos;
                while (end < body.len and body[end] != '"') end += 1;
                const msg = body[pos..end];
                const n = @min(msg.len, buf.len);
                @memcpy(buf[0..n], msg[0..n]);
                return buf[0..n];
            }
        }
    }
    // Fallback: message ở top level
    if (std.mem.indexOf(u8, body, "\"message\":")) |start| {
        var pos = start + 10;
        while (pos < body.len and (body[pos] == ' ' or body[pos] == '\t')) pos += 1;
        if (pos < body.len and body[pos] == '"') {
            pos += 1;
            var end = pos;
            while (end < body.len and body[end] != '"') end += 1;
            const msg = body[pos..end];
            const n = @min(msg.len, buf.len);
            @memcpy(buf[0..n], msg[0..n]);
            return buf[0..n];
        }
    }
    const fallback = "Lỗi không xác định";
    const n = @min(fallback.len, buf.len);
    @memcpy(buf[0..n], fallback[0..n]);
    return buf[0..n];
}

/// Trích xuất trường "data" từ response
pub fn extractData(body: []const u8) []const u8 {
    // Tìm "data": { hoặc "data": [
    const data_key = "\"data\":";
    const idx = std.mem.indexOf(u8, body, data_key) orelse return "";
    var pos = idx + data_key.len;
    while (pos < body.len and (body[pos] == ' ' or body[pos] == '\t')) pos += 1;
    if (pos >= body.len) return "";

    const start = pos;
    const open_char: u8 = body[pos];
    const close_char: u8 = if (open_char == '{') '}' else if (open_char == '[') ']' else return body[pos..pos];

    var depth: i32 = 0;
    var end = pos;
    while (end < body.len) : (end += 1) {
        if (body[end] == open_char) depth += 1;
        if (body[end] == close_char) {
            depth -= 1;
            if (depth == 0) {
                end += 1;
                break;
            }
        }
        if (body[end] == '"') {
            end += 1;
            while (end < body.len and body[end] != '"') {
                if (body[end] == '\\') end += 1;
                end += 1;
            }
        }
    }

    return body[start..end];
}

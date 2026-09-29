// src/json.zig - JSON parsing và serialization tối giản cho Zig WASM
// DevOps Sentinel Frontend - Zig 0.16.0
//
// Vì môi trường freestanding không có allocator đầy đủ,
// ta dùng static buffer và parsing thủ công cho các trường hợp cụ thể.

const std = @import("std");
const state = @import("state.zig");

// ============================================================
// TIỆN ÍCH PARSING JSON ĐƠN GIẢN
// ============================================================

/// Trích xuất giá trị string từ JSON: "key":"value" → value
pub fn extractStr(json: []const u8, key: []const u8, buf: []u8) ?[]u8 {
    var key_buf: [256]u8 = undefined;
    const key_pattern = std.fmt.bufPrint(&key_buf, "\"{s}\":", .{key}) catch return null;

    const start_key = std.mem.indexOf(u8, json, key_pattern) orelse return null;
    var pos = start_key + key_pattern.len;

    // Bỏ qua khoảng trắng
    while (pos < json.len and (json[pos] == ' ' or json[pos] == '\t')) pos += 1;

    if (pos >= json.len) return null;

    if (json[pos] == '"') {
        // String value
        pos += 1;
        var end = pos;
        while (end < json.len and json[end] != '"') {
            if (json[end] == '\\') end += 1; // skip escaped char
            end += 1;
        }
        const val = json[pos..end];
        if (val.len > buf.len) return null;
        @memcpy(buf[0..val.len], val);
        return buf[0..val.len];
    } else if (json[pos] == 'n' and pos + 3 < json.len and std.mem.eql(u8, json[pos..pos+4], "null")) {
        return null;
    }

    return null;
}

/// Trích xuất số nguyên từ JSON
pub fn extractI64(json: []const u8, key: []const u8) ?i64 {
    var key_buf: [256]u8 = undefined;
    const key_pattern = std.fmt.bufPrint(&key_buf, "\"{s}\":", .{key}) catch return null;

    const start_key = std.mem.indexOf(u8, json, key_pattern) orelse return null;
    var pos = start_key + key_pattern.len;

    while (pos < json.len and (json[pos] == ' ' or json[pos] == '\t')) pos += 1;

    if (pos >= json.len) return null;

    var end = pos;
    while (end < json.len and (json[end] == '-' or (json[end] >= '0' and json[end] <= '9'))) {
        end += 1;
    }

    if (end == pos) return null;
    return std.fmt.parseInt(i64, json[pos..end], 10) catch null;
}

/// Trích xuất số thực từ JSON
pub fn extractF64(json: []const u8, key: []const u8) ?f64 {
    var key_buf: [256]u8 = undefined;
    const key_pattern = std.fmt.bufPrint(&key_buf, "\"{s}\":", .{key}) catch return null;

    const start_key = std.mem.indexOf(u8, json, key_pattern) orelse return null;
    var pos = start_key + key_pattern.len;

    while (pos < json.len and (json[pos] == ' ' or json[pos] == '\t')) pos += 1;

    if (pos >= json.len) return null;

    var end = pos;
    while (end < json.len and (json[end] == '-' or json[end] == '.' or (json[end] >= '0' and json[end] <= '9'))) {
        end += 1;
    }

    if (end == pos) return null;
    return std.fmt.parseFloat(f64, json[pos..end]) catch null;
}

/// Trích xuất boolean từ JSON
pub fn extractBool(json: []const u8, key: []const u8) ?bool {
    var key_buf: [256]u8 = undefined;
    const key_pattern = std.fmt.bufPrint(&key_buf, "\"{s}\":", .{key}) catch return null;

    const start_key = std.mem.indexOf(u8, json, key_pattern) orelse return null;
    var pos = start_key + key_pattern.len;

    while (pos < json.len and (json[pos] == ' ' or json[pos] == '\t')) pos += 1;

    if (pos + 4 <= json.len and std.mem.eql(u8, json[pos..pos+4], "true")) return true;
    if (pos + 5 <= json.len and std.mem.eql(u8, json[pos..pos+5], "false")) return false;
    return null;
}

/// Lấy mảng JSON (trả về slice của toàn bộ chuỗi mảng)
pub fn extractArray(json: []const u8, key: []const u8) ?[]const u8 {
    var key_buf: [256]u8 = undefined;
    const key_pattern = std.fmt.bufPrint(&key_buf, "\"{s}\":", .{key}) catch return null;

    const start_key = std.mem.indexOf(u8, json, key_pattern) orelse return null;
    var pos = start_key + key_pattern.len;

    while (pos < json.len and (json[pos] == ' ' or json[pos] == '\t')) pos += 1;

    if (pos >= json.len or json[pos] != '[') return null;

    var depth: i32 = 0;
    var end = pos;
    while (end < json.len) : (end += 1) {
        if (json[end] == '[') depth += 1;
        if (json[end] == ']') {
            depth -= 1;
            if (depth == 0) {
                end += 1;
                break;
            }
        }
        // Skip string contents
        if (json[end] == '"') {
            end += 1;
            while (end < json.len and json[end] != '"') {
                if (json[end] == '\\') end += 1;
                end += 1;
            }
        }
    }

    return json[pos..end];
}

/// Lấy object JSON lồng nhau theo key
pub fn extractObject(json: []const u8, key: []const u8) ?[]const u8 {
    var key_buf: [256]u8 = undefined;
    const key_pattern = std.fmt.bufPrint(&key_buf, "\"{s}\":", .{key}) catch return null;

    const start_key = std.mem.indexOf(u8, json, key_pattern) orelse return null;
    var pos = start_key + key_pattern.len;

    while (pos < json.len and (json[pos] == ' ' or json[pos] == '\t')) pos += 1;

    if (pos >= json.len) return null;
    if (json[pos] == 'n') return null; // null

    if (json[pos] != '{') return null;

    var depth: i32 = 0;
    var end = pos;
    while (end < json.len) : (end += 1) {
        if (json[end] == '{') depth += 1;
        if (json[end] == '}') {
            depth -= 1;
            if (depth == 0) {
                end += 1;
                break;
            }
        }
        if (json[end] == '"') {
            end += 1;
            while (end < json.len and json[end] != '"') {
                if (json[end] == '\\') end += 1;
                end += 1;
            }
        }
    }

    return json[pos..end];
}

/// Iterate các object trong mảng JSON
/// Gọi callback cho mỗi object JSON, trả về false để dừng
pub fn iterateArray(arr_json: []const u8, comptime T: type, callback: fn(item_json: []const u8, index: usize) bool) void {
    _ = T;
    if (arr_json.len == 0 or arr_json[0] != '[') return;

    var pos: usize = 1;
    var index: usize = 0;

    while (pos < arr_json.len) {
        // Bỏ qua khoảng trắng và dấu phẩy
        while (pos < arr_json.len and (arr_json[pos] == ' ' or arr_json[pos] == '\n' or arr_json[pos] == '\r' or arr_json[pos] == '\t' or arr_json[pos] == ',')) {
            pos += 1;
        }

        if (pos >= arr_json.len or arr_json[pos] == ']') break;

        if (arr_json[pos] == '{') {
            // Tìm object kết thúc
            var depth: i32 = 0;
            var end = pos;
            while (end < arr_json.len) : (end += 1) {
                if (arr_json[end] == '{') depth += 1;
                if (arr_json[end] == '}') {
                    depth -= 1;
                    if (depth == 0) {
                        end += 1;
                        break;
                    }
                }
                if (arr_json[end] == '"') {
                    end += 1;
                    while (end < arr_json.len and arr_json[end] != '"') {
                        if (arr_json[end] == '\\') end += 1;
                        end += 1;
                    }
                }
            }

            const item_json = arr_json[pos..end];
            if (!callback(item_json, index)) return;
            pos = end;
            index += 1;
        } else {
            pos += 1;
        }
    }
}

// ============================================================
// PARSE / SERIALIZE SPECIFIC TYPES
// ============================================================

/// Parse NguoiDung từ JSON {"id":1,"name":"...","email":"...","role":"..."}
pub fn parseUser(json_str: []const u8) !state.NguoiDung {
    var nd = state.NguoiDung{};

    nd.id = extractI64(json_str, "id") orelse 0;

    var name_buf: [256]u8 = undefined;
    if (extractStr(json_str, "name", &name_buf)) |v| {
        const len = @min(v.len, nd.name.len - 1);
        @memcpy(nd.name[0..len], v[0..len]);
        nd.name_len = len;
    }

    var email_buf: [256]u8 = undefined;
    if (extractStr(json_str, "email", &email_buf)) |v| {
        const len = @min(v.len, nd.email.len - 1);
        @memcpy(nd.email[0..len], v[0..len]);
        nd.email_len = len;
    }

    var role_buf: [64]u8 = undefined;
    if (extractStr(json_str, "role", &role_buf)) |v| {
        const len = @min(v.len, nd.role.len - 1);
        @memcpy(nd.role[0..len], v[0..len]);
        nd.role_len = len;
    }

    return nd;
}

/// Serialize NguoiDung thành JSON
pub fn serializeUser(nd: state.NguoiDung, buf: []u8) ![]u8 {
    return std.fmt.bufPrint(buf, "{{\"id\":{d},\"name\":\"{s}\",\"email\":\"{s}\",\"role\":\"{s}\"}}", .{
        nd.id, nd.getName(), nd.getEmail(), nd.getRole(),
    });
}

/// Parse trường "success" và "data" từ response JSON chuẩn
pub fn parseApiResponse(json_str: []const u8) struct {
    success: bool,
    message: []const u8,
    data: ?[]const u8,
} {
    const success = extractBool(json_str, "success") orelse false;

    // Extract message
    var msg_buf: [512]u8 = undefined;
    const message = extractStr(json_str, "message", &msg_buf) orelse "";
    _ = message; // Will be accessed via static buffer

    const data_obj = extractObject(json_str, "data");
    const data_arr = extractArray(json_str, "data");

    // Tìm data field - có thể là object hoặc array
    var key_buf: [64]u8 = undefined;
    const key_pattern = std.fmt.bufPrint(&key_buf, "\"data\":", .{}) catch {
        return .{ .success = success, .message = "", .data = null };
    };

    var data: ?[]const u8 = null;
    if (std.mem.indexOf(u8, json_str, key_pattern) != null) {
        data = data_obj orelse data_arr;
    }

    return .{ .success = success, .message = "", .data = data };
}

// ============================================================
// ESCAPING HTML
// ============================================================

/// Escape các ký tự HTML nguy hiểm trong chuỗi (chống XSS)
pub fn escapeHtml(input: []const u8, buf: []u8) []u8 {
    var out_pos: usize = 0;
    for (input) |c| {
        switch (c) {
            '<' => {
                if (out_pos + 4 > buf.len) break;
                @memcpy(buf[out_pos..out_pos+4], "&lt;");
                out_pos += 4;
            },
            '>' => {
                if (out_pos + 4 > buf.len) break;
                @memcpy(buf[out_pos..out_pos+4], "&gt;");
                out_pos += 4;
            },
            '&' => {
                if (out_pos + 5 > buf.len) break;
                @memcpy(buf[out_pos..out_pos+5], "&amp;");
                out_pos += 5;
            },
            '"' => {
                if (out_pos + 6 > buf.len) break;
                @memcpy(buf[out_pos..out_pos+6], "&quot;");
                out_pos += 6;
            },
            else => {
                if (out_pos >= buf.len) break;
                buf[out_pos] = c;
                out_pos += 1;
            },
        }
    }
    return buf[0..out_pos];
}

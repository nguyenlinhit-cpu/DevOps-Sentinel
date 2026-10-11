// src/views/helpers.zig - Các hàm tiện ích dùng chung giữa các view
// DevOps Sentinel Frontend - Zig 0.16.0

const std = @import("std");
const js = @import("../js.zig");
const types = @import("../api/types.zig");

// ============================================================
// ĐỊNH DẠNG TRẠNG THÁI PIPELINE
// ============================================================

pub const TrangThaiInfo = struct {
    ten: []const u8,
    badge_class: []const u8,
    icon: []const u8,
};

pub fn dinhDangTrangThai(trang_thai: []const u8) TrangThaiInfo {
    if (std.mem.eql(u8, trang_thai, "success")) {
        return .{ .ten = "Thành công", .badge_class = "badge-success", .icon = "✓" };
    } else if (std.mem.eql(u8, trang_thai, "failed")) {
        return .{ .ten = "Thất bại", .badge_class = "badge-failed", .icon = "✗" };
    } else if (std.mem.eql(u8, trang_thai, "running")) {
        return .{ .ten = "Đang chạy", .badge_class = "badge-running", .icon = "⚡" };
    } else if (std.mem.eql(u8, trang_thai, "queued")) {
        return .{ .ten = "Đang đợi", .badge_class = "badge-queued", .icon = "⏳" };
    } else if (std.mem.eql(u8, trang_thai, "cancelled")) {
        return .{ .ten = "Đã hủy", .badge_class = "badge-cancelled", .icon = "⊘" };
    } else {
        return .{ .ten = trang_thai, .badge_class = "badge-neutral", .icon = "•" };
    }
}

pub const ProviderInfo = struct {
    ten: []const u8,
    badge_class: []const u8,
    icon: []const u8,
};

pub fn dinhDangProvider(provider: []const u8) ProviderInfo {
    // Case-insensitive comparison
    var lower: [64]u8 = undefined;
    const n = @min(provider.len, lower.len);
    for (provider[0..n], 0..) |c, i| {
        lower[i] = std.ascii.toLower(c);
    }
    const lp = lower[0..n];

    if (std.mem.eql(u8, lp, "github")) {
        return .{ .ten = "GitHub Actions", .badge_class = "badge-provider-github", .icon = "🐙" };
    } else if (std.mem.eql(u8, lp, "gitlab")) {
        return .{ .ten = "GitLab CI", .badge_class = "badge-provider-gitlab", .icon = "🦊" };
    } else {
        return .{ .ten = "Generic CI", .badge_class = "badge-provider-generic", .icon = "⚙️" };
    }
}

/// Định dạng thời lượng giây thành chuỗi "45s" hoặc "2m 15s"
pub fn dinhDangThoiLuong(giay: i32, buf: []u8) []u8 {
    if (giay <= 0) {
        const s = "0s";
        @memcpy(buf[0..s.len], s);
        return buf[0..s.len];
    }
    if (giay < 60) {
        return std.fmt.bufPrint(buf, "{d}s", .{giay}) catch buf[0..0];
    }
    const phut = @divFloor(giay, 60);
    const con_lai = @rem(giay, 60);
    if (con_lai == 0) {
        return std.fmt.bufPrint(buf, "{d}m", .{phut}) catch buf[0..0];
    }
    return std.fmt.bufPrint(buf, "{d}m {d}s", .{ phut, con_lai }) catch buf[0..0];
}

/// Định dạng ISO datetime thành "HH:MM DD/MM"
pub fn dinhDangThoiGian(iso: []const u8, buf: []u8) []u8 {
    if (iso.len == 0) {
        buf[0] = '-';
        return buf[0..1];
    }
    if (iso.len >= 16) {
        const ngay = iso[0..10];
        const gio = iso[11..16];
        return std.fmt.bufPrint(buf, "{s} {s}", .{ gio, ngay }) catch buf[0..0];
    }
    const n = @min(iso.len, buf.len);
    @memcpy(buf[0..n], iso[0..n]);
    return buf[0..n];
}

/// Rút gọn URL để hiển thị
pub fn rutGonUrl(url: []const u8, buf: []u8) []u8 {
    var s = url;
    if (std.mem.startsWith(u8, s, "https://")) s = s[8..];
    if (std.mem.startsWith(u8, s, "http://")) s = s[7..];
    if (s.len > 35) {
        const n = @min(32, buf.len - 3);
        @memcpy(buf[0..n], s[0..n]);
        @memcpy(buf[n..n+3], "...");
        return buf[0..n+3];
    }
    const n = @min(s.len, buf.len);
    @memcpy(buf[0..n], s[0..n]);
    return buf[0..n];
}

/// Lấy chữ cái đầu của tên người dùng
pub fn layChuCaiDau(ten: []const u8, buf: []u8) []u8 {
    const trimmed = std.mem.trim(u8, ten, " \t\n");
    if (trimmed.len == 0) {
        buf[0] = 'U';
        return buf[0..1];
    }
    // Lấy byte đầu (hoạt động với ASCII, với UTF-8 thì lấy byte đầu tiên của rune)
    buf[0] = std.ascii.toUpper(trimmed[0]);
    return buf[0..1];
}

/// Cắt ngắn chuỗi nếu quá dài
pub fn truncate(s: []const u8, max_len: usize, buf: []u8) []u8 {
    if (s.len <= max_len) {
        const n = @min(s.len, buf.len);
        @memcpy(buf[0..n], s[0..n]);
        return buf[0..n];
    }
    const n = @min(max_len - 3, buf.len - 3);
    @memcpy(buf[0..n], s[0..n]);
    @memcpy(buf[n..n+3], "...");
    return buf[0..n+3];
}

// ============================================================
// TIỆN ÍCH DOM
// ============================================================

/// Hiển thị spinner loading trong element
pub fn hienThiDangTai(handle: js.DomHandle, msg: []const u8) void {
    var buf: [512]u8 = undefined;
    const html = std.fmt.bufPrint(&buf,
        \\<div class="content-loading">
        \\  <div class="spinner"></div>
        \\  <h3>{s}</h3>
        \\</div>
    , .{msg}) catch return;
    js.setInnerHtml(handle, html);
}

/// Hiển thị thông báo lỗi đơn giản
pub fn hienThiLoi(handle: js.DomHandle, msg: []const u8) void {
    var buf: [1024]u8 = undefined;
    const html = std.fmt.bufPrint(&buf,
        \\<div class="card card-error">
        \\  <h3>❌ Lỗi</h3>
        \\  <p>{s}</p>
        \\</div>
    , .{msg}) catch return;
    js.setInnerHtml(handle, html);
}

/// Hiển thị thông báo trạng thái (info/success/error) trong auth form
pub fn hienThiThongBaoAuth(alert_id: []const u8, loai: []const u8, noi_dung: []const u8) void {
    const the_alert = js.getElementById(alert_id);
    if (!js.isValid(the_alert)) return;

    js.removeClass(the_alert, "alert-error");
    js.removeClass(the_alert, "alert-success");
    js.removeClass(the_alert, "alert-info");

    if (std.mem.eql(u8, loai, "error")) {
        js.addClass(the_alert, "alert-error");
    } else if (std.mem.eql(u8, loai, "success")) {
        js.addClass(the_alert, "alert-success");
    } else {
        js.addClass(the_alert, "alert-info");
    }

    js.setAttribute(the_alert, "style", "display: block;");
    js.setInnerText(the_alert, noi_dung);
}

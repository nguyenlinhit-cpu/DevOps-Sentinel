// src/state.zig - Quản lý trạng thái toàn cục ứng dụng
// DevOps Sentinel Frontend - Zig 0.16.0

const std = @import("std");
const js = @import("js.zig");
const json = @import("json.zig");

// ============================================================
// CẤU TRÚC DỮ LIỆU
// ============================================================

pub const NguoiDung = struct {
    id: i64 = 0,
    name: [256]u8 = [_]u8{0} ** 256,
    name_len: usize = 0,
    email: [256]u8 = [_]u8{0} ** 256,
    email_len: usize = 0,
    role: [64]u8 = [_]u8{0} ** 64,
    role_len: usize = 0,

    pub fn getName(self: *const NguoiDung) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn getEmail(self: *const NguoiDung) []const u8 {
        return self.email[0..self.email_len];
    }

    pub fn getRole(self: *const NguoiDung) []const u8 {
        return self.role[0..self.role_len];
    }

    pub fn isAdmin(self: *const NguoiDung) bool {
        return std.mem.eql(u8, self.getRole(), "admin");
    }

    pub fn isTeamLead(self: *const NguoiDung) bool {
        const r = self.getRole();
        return std.mem.eql(u8, r, "admin") or std.mem.eql(u8, r, "team_lead");
    }
};

// ============================================================
// TRẠNG THÁI TOÀN CỤC SINGLETON
// ============================================================

pub const TrangThai = struct {
    access_token: [2048]u8 = [_]u8{0} ** 2048,
    access_token_len: usize = 0,
    refresh_token: [2048]u8 = [_]u8{0} ** 2048,
    refresh_token_len: usize = 0,
    nguoi_dung: ?NguoiDung = null,
    polling_kich_hoat: bool = true,
    polling_timer_id: u32 = 0,

    pub fn getAccessToken(self: *const TrangThai) []const u8 {
        return self.access_token[0..self.access_token_len];
    }

    pub fn getRefreshToken(self: *const TrangThai) []const u8 {
        return self.refresh_token[0..self.refresh_token_len];
    }

    pub fn daDangNhap(self: *const TrangThai) bool {
        return self.access_token_len > 0 and self.nguoi_dung != null;
    }

    pub fn laQuanTriVien(self: *const TrangThai) bool {
        if (self.nguoi_dung) |nd| return nd.isAdmin();
        return false;
    }

    pub fn laTruongNhom(self: *const TrangThai) bool {
        if (self.nguoi_dung) |nd| return nd.isTeamLead();
        return false;
    }

    pub fn chuyenDoiPolling(self: *TrangThai) bool {
        self.polling_kich_hoat = !self.polling_kich_hoat;
        return self.polling_kich_hoat;
    }

    /// Lưu phiên đăng nhập vào localStorage
    pub fn luuPhien(self: *TrangThai, access: []const u8, refresh: []const u8, nd: NguoiDung) void {
        @memcpy(self.access_token[0..access.len], access);
        self.access_token_len = access.len;
        @memcpy(self.refresh_token[0..refresh.len], refresh);
        self.refresh_token_len = refresh.len;
        self.nguoi_dung = nd;

        js.localStorageSet("devops_sentinel_access_token", access);
        js.localStorageSet("devops_sentinel_refresh_token", refresh);

        // Serialize user to JSON for localStorage
        var buf: [1024]u8 = undefined;
        const user_json = json.serializeUser(nd, &buf) catch return;
        js.localStorageSet("devops_sentinel_user", user_json);
    }

    /// Xóa phiên đăng nhập
    pub fn xoaPhien(self: *TrangThai) void {
        @memset(&self.access_token, 0);
        self.access_token_len = 0;
        @memset(&self.refresh_token, 0);
        self.refresh_token_len = 0;
        self.nguoi_dung = null;

        js.localStorageRemove("devops_sentinel_access_token");
        js.localStorageRemove("devops_sentinel_refresh_token");
        js.localStorageRemove("devops_sentinel_user");
    }

    /// Tải phiên từ localStorage khi khởi động
    pub fn taiTuKhoLuuTru(self: *TrangThai) void {
        var buf: [4096]u8 = undefined;

        const access = js.localStorageGet("devops_sentinel_access_token", &buf);
        if (access.len > 0 and access.len < self.access_token.len) {
            @memcpy(self.access_token[0..access.len], access);
            self.access_token_len = access.len;
        }

        var buf2: [4096]u8 = undefined;
        const refresh = js.localStorageGet("devops_sentinel_refresh_token", &buf2);
        if (refresh.len > 0 and refresh.len < self.refresh_token.len) {
            @memcpy(self.refresh_token[0..refresh.len], refresh);
            self.refresh_token_len = refresh.len;
        }

        var buf3: [2048]u8 = undefined;
        const user_json = js.localStorageGet("devops_sentinel_user", &buf3);
        if (user_json.len > 0) {
            self.nguoi_dung = json.parseUser(user_json) catch null;
        }
    }
};

// Singleton toàn cục
var _trang_thai = TrangThai{};

pub fn layTrangThai() *TrangThai {
    return &_trang_thai;
}

pub fn khoiTaoTrangThai() void {
    _trang_thai.taiTuKhoLuuTru();
}

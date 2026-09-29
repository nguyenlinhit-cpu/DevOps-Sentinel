// src/api/types.zig - Cấu trúc dữ liệu API
// DevOps Sentinel Frontend - Zig 0.16.0
//
// Tương đương với du_lieu.go trong frontend Go.

const std = @import("std");

// ============================================================
// KIỂU CHUỖI AN TOÀN CHO WASM (STACK-ALLOCATED)
// ============================================================

pub const Str64  = [64]u8;
pub const Str128 = [128]u8;
pub const Str256 = [256]u8;
pub const Str512 = [512]u8;
pub const Str1K  = [1024]u8;
pub const Str4K  = [4096]u8;

pub fn strSlice(arr: anytype, len: usize) []const u8 {
    return arr[0..len];
}

// ============================================================
// CÁC KIỂU DỮ LIỆU API
// ============================================================

pub const DuAnNho = struct {
    id: i64 = 0,
    name: Str256 = [_]u8{0} ** 256,
    name_len: usize = 0,
    slug: Str128 = [_]u8{0} ** 128,
    slug_len: usize = 0,

    pub fn getName(self: *const @This()) []const u8 { return self.name[0..self.name_len]; }
    pub fn getSlug(self: *const @This()) []const u8 { return self.slug[0..self.slug_len]; }
};

pub const NhomNho = struct {
    id: i64 = 0,
    name: Str256 = [_]u8{0} ** 256,
    name_len: usize = 0,

    pub fn getName(self: *const @This()) []const u8 { return self.name[0..self.name_len]; }
};

pub const NguoiTao = struct {
    id: i64 = 0,
    name: Str256 = [_]u8{0} ** 256,
    name_len: usize = 0,
    email: Str256 = [_]u8{0} ** 256,
    email_len: usize = 0,

    pub fn getName(self: *const @This()) []const u8 { return self.name[0..self.name_len]; }
    pub fn getEmail(self: *const @This()) []const u8 { return self.email[0..self.email_len]; }
};

pub const ThanhVien = struct {
    id: i64 = 0,
    name: Str256 = [_]u8{0} ** 256,
    name_len: usize = 0,
    email: Str256 = [_]u8{0} ** 256,
    email_len: usize = 0,
    role: Str64 = [_]u8{0} ** 64,
    role_len: usize = 0,

    pub fn getName(self: *const @This()) []const u8 { return self.name[0..self.name_len]; }
    pub fn getEmail(self: *const @This()) []const u8 { return self.email[0..self.email_len]; }
    pub fn getRole(self: *const @This()) []const u8 { return self.role[0..self.role_len]; }
};

pub const LuotChay = struct {
    id: i64 = 0,
    project_id: i64 = 0,
    pipeline_name: Str256 = [_]u8{0} ** 256,
    pipeline_name_len: usize = 0,
    commit_hash: Str128 = [_]u8{0} ** 128,
    commit_hash_len: usize = 0,
    commit_message: Str512 = [_]u8{0} ** 512,
    commit_message_len: usize = 0,
    branch: Str128 = [_]u8{0} ** 128,
    branch_len: usize = 0,
    author: Str256 = [_]u8{0} ** 256,
    author_len: usize = 0,
    status: Str64 = [_]u8{0} ** 64,
    status_len: usize = 0,
    trigger_event: Str128 = [_]u8{0} ** 128,
    trigger_event_len: usize = 0,
    duration_seconds: i32 = 0,
    short_log: Str4K = [_]u8{0} ** 4096,
    short_log_len: usize = 0,
    external_url: Str512 = [_]u8{0} ** 512,
    external_url_len: usize = 0,
    started_at: Str64 = [_]u8{0} ** 64,
    started_at_len: usize = 0,
    finished_at: Str64 = [_]u8{0} ** 64,
    finished_at_len: usize = 0,
    created_at: Str64 = [_]u8{0} ** 64,
    created_at_len: usize = 0,
    du_an: ?DuAnNho = null,

    pub fn getPipelineName(self: *const @This()) []const u8 { return self.pipeline_name[0..self.pipeline_name_len]; }
    pub fn getCommitHash(self: *const @This()) []const u8 { return self.commit_hash[0..self.commit_hash_len]; }
    pub fn getCommitMessage(self: *const @This()) []const u8 { return self.commit_message[0..self.commit_message_len]; }
    pub fn getBranch(self: *const @This()) []const u8 { return self.branch[0..self.branch_len]; }
    pub fn getAuthor(self: *const @This()) []const u8 { return self.author[0..self.author_len]; }
    pub fn getStatus(self: *const @This()) []const u8 { return self.status[0..self.status_len]; }
    pub fn getTriggerEvent(self: *const @This()) []const u8 { return self.trigger_event[0..self.trigger_event_len]; }
    pub fn getShortLog(self: *const @This()) []const u8 { return self.short_log[0..self.short_log_len]; }
    pub fn getExternalUrl(self: *const @This()) []const u8 { return self.external_url[0..self.external_url_len]; }
    pub fn getStartedAt(self: *const @This()) []const u8 { return self.started_at[0..self.started_at_len]; }
    pub fn getFinishedAt(self: *const @This()) []const u8 { return self.finished_at[0..self.finished_at_len]; }
    pub fn getCreatedAt(self: *const @This()) []const u8 { return self.created_at[0..self.created_at_len]; }

    pub fn getHashNgan(self: *const @This()) []const u8 {
        const h = self.getCommitHash();
        return if (h.len > 7) h[0..7] else h;
    }
};

pub const DuAn = struct {
    id: i64 = 0,
    team_id: ?i64 = null,
    name: Str256 = [_]u8{0} ** 256,
    name_len: usize = 0,
    slug: Str128 = [_]u8{0} ** 128,
    slug_len: usize = 0,
    description: Str512 = [_]u8{0} ** 512,
    description_len: usize = 0,
    repository_url: Str512 = [_]u8{0} ** 512,
    repository_url_len: usize = 0,
    ci_provider: Str64 = [_]u8{0} ** 64,
    ci_provider_len: usize = 0,
    webhook_secret: Str512 = [_]u8{0} ** 512,
    webhook_secret_len: usize = 0,
    webhook_url: Str512 = [_]u8{0} ** 512,
    webhook_url_len: usize = 0,
    failure_threshold: i32 = 3,
    active_alerts_count: i32 = 0,
    created_at: Str64 = [_]u8{0} ** 64,
    created_at_len: usize = 0,
    updated_at: Str64 = [_]u8{0} ** 64,
    updated_at_len: usize = 0,
    nhom_so_huu: ?NhomNho = null,
    nguoi_tao: ?NguoiTao = null,
    luot_chay_moi_nhat: ?LuotChay = null,

    pub fn getName(self: *const @This()) []const u8 { return self.name[0..self.name_len]; }
    pub fn getSlug(self: *const @This()) []const u8 { return self.slug[0..self.slug_len]; }
    pub fn getDescription(self: *const @This()) []const u8 { return self.description[0..self.description_len]; }
    pub fn getRepositoryUrl(self: *const @This()) []const u8 { return self.repository_url[0..self.repository_url_len]; }
    pub fn getCiProvider(self: *const @This()) []const u8 { return self.ci_provider[0..self.ci_provider_len]; }
    pub fn getWebhookSecret(self: *const @This()) []const u8 { return self.webhook_secret[0..self.webhook_secret_len]; }
    pub fn getWebhookUrl(self: *const @This()) []const u8 { return self.webhook_url[0..self.webhook_url_len]; }
    pub fn getCreatedAt(self: *const @This()) []const u8 { return self.created_at[0..self.created_at_len]; }
};

pub const CanhBao = struct {
    id: i64 = 0,
    project_id: i64 = 0,
    last_pipeline_run_id: ?i64 = null,
    title: Str256 = [_]u8{0} ** 256,
    title_len: usize = 0,
    message: Str1K = [_]u8{0} ** 1024,
    message_len: usize = 0,
    consecutive_failures: i32 = 0,
    status: Str64 = [_]u8{0} ** 64, // "active", "resolved"
    status_len: usize = 0,
    resolved_at: Str64 = [_]u8{0} ** 64,
    resolved_at_len: usize = 0,
    created_at: Str64 = [_]u8{0} ** 64,
    created_at_len: usize = 0,
    du_an: ?DuAnNho = null,
    luot_chay_loi: ?LuotChay = null,
    nguoi_xu_ly: ?NguoiTao = null,

    pub fn getTitle(self: *const @This()) []const u8 { return self.title[0..self.title_len]; }
    pub fn getMessage(self: *const @This()) []const u8 { return self.message[0..self.message_len]; }
    pub fn getStatus(self: *const @This()) []const u8 { return self.status[0..self.status_len]; }
    pub fn getCreatedAt(self: *const @This()) []const u8 { return self.created_at[0..self.created_at_len]; }
    pub fn getResolvedAt(self: *const @This()) []const u8 { return self.resolved_at[0..self.resolved_at_len]; }
};

pub const Nhom = struct {
    id: i64 = 0,
    name: Str256 = [_]u8{0} ** 256,
    name_len: usize = 0,
    description: Str512 = [_]u8{0} ** 512,
    description_len: usize = 0,
    created_at: Str64 = [_]u8{0} ** 64,
    created_at_len: usize = 0,
    members_count: i32 = 0,
    projects_count: i32 = 0,
    nguoi_tao: ?NguoiTao = null,

    pub fn getName(self: *const @This()) []const u8 { return self.name[0..self.name_len]; }
    pub fn getDescription(self: *const @This()) []const u8 { return self.description[0..self.description_len]; }
};

pub const ThongKeDashboard = struct {
    total_projects: i32 = 0,
    total_runs: i32 = 0,
    total_runs_today: i32 = 0,
    success_runs_count: i32 = 0,
    failed_runs_count: i32 = 0,
    success_rate_percent: f64 = 0.0,
    active_alerts_count: i32 = 0,
    // Recent runs: lưu tối đa 10 lượt chạy gần đây
    recent_runs: [10]LuotChay = [_]LuotChay{LuotChay{}} ** 10,
    recent_runs_count: usize = 0,
};

pub const PhanTrangMeta = struct {
    page: i32 = 1,
    per_page: i32 = 10,
    total: i32 = 0,
    total_pages: i32 = 0,
};

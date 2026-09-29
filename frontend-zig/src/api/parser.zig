// src/api/parser.zig - Parse JSON responses thành các struct API
// DevOps Sentinel Frontend - Zig 0.16.0

const std = @import("std");
const json = @import("../json.zig");
const types = @import("types.zig");

fn copyStr(comptime N: usize, dest: *[N]u8, dest_len: *usize, src: []const u8) void {
    const n = @min(src.len, N - 1);
    @memcpy(dest[0..n], src[0..n]);
    dest_len.* = n;
}

pub fn parseDuAnNho(j: []const u8) ?types.DuAnNho {
    if (j.len == 0 or j[0] == 'n') return null;
    var r = types.DuAnNho{};
    r.id = json.extractI64(j, "id") orelse 0;
    var b: [256]u8 = undefined;
    if (json.extractStr(j, "name", &b)) |v| copyStr(256, &r.name, &r.name_len, v);
    var b2: [128]u8 = undefined;
    if (json.extractStr(j, "slug", &b2)) |v| copyStr(128, &r.slug, &r.slug_len, v);
    return r;
}

pub fn parseNhomNho(j: []const u8) ?types.NhomNho {
    if (j.len == 0 or j[0] == 'n') return null;
    var r = types.NhomNho{};
    r.id = json.extractI64(j, "id") orelse 0;
    var b: [256]u8 = undefined;
    if (json.extractStr(j, "name", &b)) |v| copyStr(256, &r.name, &r.name_len, v);
    return r;
}

pub fn parseNguoiTao(j: []const u8) ?types.NguoiTao {
    if (j.len == 0 or j[0] == 'n') return null;
    var r = types.NguoiTao{};
    r.id = json.extractI64(j, "id") orelse 0;
    var b: [256]u8 = undefined;
    if (json.extractStr(j, "name", &b)) |v| copyStr(256, &r.name, &r.name_len, v);
    var b2: [256]u8 = undefined;
    if (json.extractStr(j, "email", &b2)) |v| copyStr(256, &r.email, &r.email_len, v);
    return r;
}

pub fn parseLuotChay(j: []const u8) types.LuotChay {
    var r = types.LuotChay{};
    r.id = json.extractI64(j, "id") orelse 0;
    r.project_id = json.extractI64(j, "project_id") orelse 0;
    r.duration_seconds = @intCast(json.extractI64(j, "duration_seconds") orelse 0);

    var b: [256]u8 = undefined;
    if (json.extractStr(j, "pipeline_name", &b)) |v| copyStr(256, &r.pipeline_name, &r.pipeline_name_len, v);
    var b2: [128]u8 = undefined;
    if (json.extractStr(j, "commit_hash", &b2)) |v| copyStr(128, &r.commit_hash, &r.commit_hash_len, v);
    var b3: [512]u8 = undefined;
    if (json.extractStr(j, "commit_message", &b3)) |v| copyStr(512, &r.commit_message, &r.commit_message_len, v);
    var b4: [128]u8 = undefined;
    if (json.extractStr(j, "branch", &b4)) |v| copyStr(128, &r.branch, &r.branch_len, v);
    var b5: [256]u8 = undefined;
    if (json.extractStr(j, "author", &b5)) |v| copyStr(256, &r.author, &r.author_len, v);
    var b6: [64]u8 = undefined;
    if (json.extractStr(j, "status", &b6)) |v| copyStr(64, &r.status, &r.status_len, v);
    var b7: [128]u8 = undefined;
    if (json.extractStr(j, "trigger_event", &b7)) |v| copyStr(128, &r.trigger_event, &r.trigger_event_len, v);
    var b8: [4096]u8 = undefined;
    if (json.extractStr(j, "short_log", &b8)) |v| copyStr(4096, &r.short_log, &r.short_log_len, v);
    var b9: [512]u8 = undefined;
    if (json.extractStr(j, "external_url", &b9)) |v| copyStr(512, &r.external_url, &r.external_url_len, v);
    var b10: [64]u8 = undefined;
    if (json.extractStr(j, "started_at", &b10)) |v| copyStr(64, &r.started_at, &r.started_at_len, v);
    var b11: [64]u8 = undefined;
    if (json.extractStr(j, "finished_at", &b11)) |v| copyStr(64, &r.finished_at, &r.finished_at_len, v);
    var b12: [64]u8 = undefined;
    if (json.extractStr(j, "created_at", &b12)) |v| copyStr(64, &r.created_at, &r.created_at_len, v);

    if (json.extractObject(j, "du_an")) |obj| r.du_an = parseDuAnNho(obj);

    return r;
}

pub fn parseDuAn(j: []const u8) types.DuAn {
    var r = types.DuAn{};
    r.id = json.extractI64(j, "id") orelse 0;
    r.team_id = json.extractI64(j, "team_id");
    r.failure_threshold = @intCast(json.extractI64(j, "failure_threshold") orelse 3);
    r.active_alerts_count = @intCast(json.extractI64(j, "active_alerts_count") orelse 0);

    var b: [256]u8 = undefined;
    if (json.extractStr(j, "name", &b)) |v| copyStr(256, &r.name, &r.name_len, v);
    var b2: [128]u8 = undefined;
    if (json.extractStr(j, "slug", &b2)) |v| copyStr(128, &r.slug, &r.slug_len, v);
    var b3: [512]u8 = undefined;
    if (json.extractStr(j, "description", &b3)) |v| copyStr(512, &r.description, &r.description_len, v);
    var b4: [512]u8 = undefined;
    if (json.extractStr(j, "repository_url", &b4)) |v| copyStr(512, &r.repository_url, &r.repository_url_len, v);
    var b5: [64]u8 = undefined;
    if (json.extractStr(j, "ci_provider", &b5)) |v| copyStr(64, &r.ci_provider, &r.ci_provider_len, v);
    var b6: [512]u8 = undefined;
    if (json.extractStr(j, "webhook_secret", &b6)) |v| copyStr(512, &r.webhook_secret, &r.webhook_secret_len, v);
    var b7: [512]u8 = undefined;
    if (json.extractStr(j, "webhook_url", &b7)) |v| copyStr(512, &r.webhook_url, &r.webhook_url_len, v);
    var b8: [64]u8 = undefined;
    if (json.extractStr(j, "created_at", &b8)) |v| copyStr(64, &r.created_at, &r.created_at_len, v);
    var b9: [64]u8 = undefined;
    if (json.extractStr(j, "updated_at", &b9)) |v| copyStr(64, &r.updated_at, &r.updated_at_len, v);

    if (json.extractObject(j, "nhom_so_huu")) |obj| r.nhom_so_huu = parseNhomNho(obj);
    if (json.extractObject(j, "nguoi_tao")) |obj| r.nguoi_tao = parseNguoiTao(obj);
    if (json.extractObject(j, "luot_chay_moi_nhat")) |obj| r.luot_chay_moi_nhat = parseLuotChay(obj);

    return r;
}

pub fn parseCanhBao(j: []const u8) types.CanhBao {
    var r = types.CanhBao{};
    r.id = json.extractI64(j, "id") orelse 0;
    r.project_id = json.extractI64(j, "project_id") orelse 0;
    r.last_pipeline_run_id = json.extractI64(j, "last_pipeline_run_id");
    r.consecutive_failures = @intCast(json.extractI64(j, "consecutive_failures") orelse 0);

    var b: [256]u8 = undefined;
    if (json.extractStr(j, "title", &b)) |v| copyStr(256, &r.title, &r.title_len, v);
    var b2: [1024]u8 = undefined;
    if (json.extractStr(j, "message", &b2)) |v| copyStr(1024, &r.message, &r.message_len, v);
    var b3: [64]u8 = undefined;
    if (json.extractStr(j, "status", &b3)) |v| copyStr(64, &r.status, &r.status_len, v);
    var b4: [64]u8 = undefined;
    if (json.extractStr(j, "resolved_at", &b4)) |v| copyStr(64, &r.resolved_at, &r.resolved_at_len, v);
    var b5: [64]u8 = undefined;
    if (json.extractStr(j, "created_at", &b5)) |v| copyStr(64, &r.created_at, &r.created_at_len, v);

    if (json.extractObject(j, "du_an")) |obj| r.du_an = parseDuAnNho(obj);
    if (json.extractObject(j, "luot_chay_loi")) |obj| r.luot_chay_loi = parseLuotChay(obj);
    if (json.extractObject(j, "nguoi_xu_ly")) |obj| r.nguoi_xu_ly = parseNguoiTao(obj);

    return r;
}

pub fn parseNhom(j: []const u8) types.Nhom {
    var r = types.Nhom{};
    r.id = json.extractI64(j, "id") orelse 0;
    r.members_count = @intCast(json.extractI64(j, "members_count") orelse 0);
    r.projects_count = @intCast(json.extractI64(j, "projects_count") orelse 0);

    var b: [256]u8 = undefined;
    if (json.extractStr(j, "name", &b)) |v| copyStr(256, &r.name, &r.name_len, v);
    var b2: [512]u8 = undefined;
    if (json.extractStr(j, "description", &b2)) |v| copyStr(512, &r.description, &r.description_len, v);
    var b3: [64]u8 = undefined;
    if (json.extractStr(j, "created_at", &b3)) |v| copyStr(64, &r.created_at, &r.created_at_len, v);

    if (json.extractObject(j, "nguoi_tao")) |obj| r.nguoi_tao = parseNguoiTao(obj);

    return r;
}

pub fn parseThanhVien(j: []const u8) types.ThanhVien {
    var r = types.ThanhVien{};
    r.id = json.extractI64(j, "id") orelse 0;

    var b: [256]u8 = undefined;
    if (json.extractStr(j, "name", &b)) |v| copyStr(256, &r.name, &r.name_len, v);
    var b2: [256]u8 = undefined;
    if (json.extractStr(j, "email", &b2)) |v| copyStr(256, &r.email, &r.email_len, v);
    var b3: [64]u8 = undefined;
    if (json.extractStr(j, "role", &b3)) |v| copyStr(64, &r.role, &r.role_len, v);

    return r;
}

pub fn parseThongKeDashboard(j: []const u8) types.ThongKeDashboard {
    var r = types.ThongKeDashboard{};
    r.total_projects = @intCast(json.extractI64(j, "total_projects") orelse 0);
    r.total_runs = @intCast(json.extractI64(j, "total_runs") orelse 0);
    r.total_runs_today = @intCast(json.extractI64(j, "total_runs_today") orelse 0);
    r.success_runs_count = @intCast(json.extractI64(j, "success_runs_count") orelse 0);
    r.failed_runs_count = @intCast(json.extractI64(j, "failed_runs_count") orelse 0);
    r.success_rate_percent = json.extractF64(j, "success_rate_percent") orelse 0.0;
    r.active_alerts_count = @intCast(json.extractI64(j, "active_alerts_count") orelse 0);

    if (json.extractArray(j, "recent_runs")) |arr| {
        var idx: usize = 0;
        json.iterateArray(arr, types.LuotChay, struct {
            fn cb(item: []const u8, i: usize) bool {
                _ = i;
                if (idx >= 10) return false;
                r.recent_runs[idx] = parseLuotChay(item);
                idx += 1;
                return true;
            }
        }.cb);
        r.recent_runs_count = idx;
    }

    return r;
}

pub fn parsePhanTrangMeta(j: []const u8) types.PhanTrangMeta {
    var r = types.PhanTrangMeta{};
    if (json.extractObject(j, "meta")) |m| {
        r.page = @intCast(json.extractI64(m, "page") orelse 1);
        r.per_page = @intCast(json.extractI64(m, "per_page") orelse 10);
        r.total = @intCast(json.extractI64(m, "total") orelse 0);
        r.total_pages = @intCast(json.extractI64(m, "total_pages") orelse 0);
    }
    return r;
}

// src/api/calls.zig - Tất cả lời gọi API nghiệp vụ
// DevOps Sentinel Frontend - Zig 0.16.0
//
// Tương đương với goi_api.go trong frontend Go.

const std = @import("std");
const client = @import("client.zig");
const state = @import("../state.zig");
const json = @import("../json.zig");
const parser = @import("parser.zig");
const types = @import("types.zig");
const js = @import("../js.zig");

// ============================================================
// XÁC THỰC (AUTH)
// ============================================================

pub const DangNhapCallback = *const fn (err: ?[]const u8) void;
pub const DangKyCallback = *const fn (err: ?[]const u8) void;

var _dang_nhap_cb: ?DangNhapCallback = null;

fn onDangNhapResponse(status: u32, body: []const u8) void {
    const cb = _dang_nhap_cb orelse return;
    _dang_nhap_cb = null;

    if (status == 0) {
        var err_buf: [256]u8 = undefined;
        const err = client.extractError(body, &err_buf);
        cb(err);
        return;
    }

    if (!client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        const err = client.extractError(body, &err_buf);
        cb(err);
        return;
    }

    // Parse user từ data.user
    const data = client.extractData(body);
    if (data.len == 0) {
        cb("Phản hồi API không hợp lệ");
        return;
    }

    var access_buf: [2048]u8 = undefined;
    var refresh_buf: [2048]u8 = undefined;
    const access = json.extractStr(data, "access_token", &access_buf) orelse {
        cb("Không tìm thấy access token");
        return;
    };
    const refresh = json.extractStr(data, "refresh_token", &refresh_buf) orelse "";

    const user_obj = json.extractObject(data, "user") orelse {
        cb("Không tìm thấy thông tin người dùng");
        return;
    };
    const nd = json.parseUser(user_obj) catch {
        cb("Lỗi parse thông tin người dùng");
        return;
    };

    state.layTrangThai().luuPhien(access, refresh, nd);
    cb(null);
}

pub fn dangNhap(email: []const u8, mat_khau: []const u8, cb: DangNhapCallback) void {
    _dang_nhap_cb = cb;
    var body_buf: [512]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf, "{{\"email\":\"{s}\",\"password\":\"{s}\"}}", .{ email, mat_khau }) catch {
        cb("Lỗi tạo request body");
        return;
    };
    client.postNoAuth("/auth/login", body, onDangNhapResponse);
}

var _dang_ky_cb: ?DangKyCallback = null;

fn onDangKyResponse(status: u32, body: []const u8) void {
    const cb = _dang_ky_cb orelse return;
    _dang_ky_cb = null;

    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        const err = client.extractError(body, &err_buf);
        cb(err);
        return;
    }

    const data = client.extractData(body);
    var access_buf: [2048]u8 = undefined;
    var refresh_buf: [2048]u8 = undefined;
    const access = json.extractStr(data, "access_token", &access_buf) orelse {
        cb("Không tìm thấy access token");
        return;
    };
    const refresh = json.extractStr(data, "refresh_token", &refresh_buf) orelse "";
    const user_obj = json.extractObject(data, "user") orelse {
        cb("Không tìm thấy user");
        return;
    };
    const nd = json.parseUser(user_obj) catch {
        cb("Lỗi parse user");
        return;
    };
    state.layTrangThai().luuPhien(access, refresh, nd);
    cb(null);
}

pub fn dangKy(ten: []const u8, email: []const u8, mat_khau: []const u8, xac_nhan: []const u8, cb: DangKyCallback) void {
    _dang_ky_cb = cb;
    var body_buf: [1024]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf,
        "{{\"name\":\"{s}\",\"email\":\"{s}\",\"password\":\"{s}\",\"password_confirmation\":\"{s}\"}}",
        .{ ten, email, mat_khau, xac_nhan }) catch {
        cb("Lỗi tạo request");
        return;
    };
    client.postNoAuth("/auth/register", body, onDangKyResponse);
}

pub fn dangXuat() void {
    client.post("/auth/logout", "", onDangXuatResponse);
    state.layTrangThai().xoaPhien();
}

fn onDangXuatResponse(_: u32, _: []const u8) void {}

// ============================================================
// KIỂM TRA SỨC KHỎE
// ============================================================

pub const HealthCallback = *const fn (ok: bool, msg: []const u8) void;
var _health_cb: ?HealthCallback = null;

fn onHealthResponse(status: u32, body: []const u8) void {
    const cb = _health_cb orelse return;
    _health_cb = null;
    cb(status == 200, body);
}

pub fn kiemTraSucKhoe(cb: HealthCallback) void {
    _health_cb = cb;
    client.getNoAuth("/health", onHealthResponse);
}

// ============================================================
// DASHBOARD
// ============================================================

pub const DashboardCallback = *const fn (err: ?[]const u8, data: ?types.ThongKeDashboard) void;
var _dashboard_cb: ?DashboardCallback = null;

fn onDashboardResponse(status: u32, body: []const u8) void {
    const cb = _dashboard_cb orelse return;
    _dashboard_cb = null;

    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        const err = client.extractError(body, &err_buf);
        cb(err, null);
        return;
    }

    const data = client.extractData(body);
    const tk = parser.parseThongKeDashboard(data);
    cb(null, tk);
}

pub fn layThongKeDashboard(cb: DashboardCallback) void {
    _dashboard_cb = cb;
    client.get("/dashboard/summary", onDashboardResponse);
}

// ============================================================
// DỰ ÁN
// ============================================================

pub const MAX_DU_AN = 50;
var _du_an_list: [MAX_DU_AN]types.DuAn = [_]types.DuAn{types.DuAn{}} ** MAX_DU_AN;
var _du_an_count: usize = 0;
var _du_an_meta: types.PhanTrangMeta = .{};

pub const DuAnListCallback = *const fn (err: ?[]const u8, list: []const types.DuAn, meta: types.PhanTrangMeta) void;
var _du_an_list_cb: ?DuAnListCallback = null;

fn onDuAnListResponse(status: u32, body: []const u8) void {
    const cb = _du_an_list_cb orelse return;
    _du_an_list_cb = null;

    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        const err = client.extractError(body, &err_buf);
        cb(err, &[_]types.DuAn{}, .{});
        return;
    }

    const data = client.extractData(body);
    _du_an_count = 0;
    _du_an_meta = parser.parsePhanTrangMeta(body);

    if (data.len > 0 and data[0] == '[') {
        json.iterateArray(data, types.DuAn, struct {
            fn doCallback(item: []const u8, _: usize) bool {
                if (_du_an_count >= MAX_DU_AN) return false;
                _du_an_list[_du_an_count] = parser.parseDuAn(item);
                _du_an_count += 1;
                return true;
            }
        }.doCallback);
    } else {
        // Single object wrapped in array
        _du_an_list[0] = parser.parseDuAn(data);
        _du_an_count = 1;
    }

    cb(null, _du_an_list[0.._du_an_count], _du_an_meta);
}

pub fn layDanhSachDuAn(tu_khoa: []const u8, trang: u32, so_luong: u32, cb: DuAnListCallback) void {
    _du_an_list_cb = cb;
    var path_buf: [256]u8 = undefined;
    var path: []u8 = undefined;
    if (tu_khoa.len > 0) {
        path = std.fmt.bufPrint(&path_buf, "/projects?page={d}&per_page={d}&search={s}", .{ trang, so_luong, tu_khoa }) catch {
            cb("Lỗi tạo URL", &[_]types.DuAn{}, .{});
            return;
        };
    } else {
        path = std.fmt.bufPrint(&path_buf, "/projects?page={d}&per_page={d}", .{ trang, so_luong }) catch {
            cb("Lỗi tạo URL", &[_]types.DuAn{}, .{});
            return;
        };
    }
    client.get(path, onDuAnListResponse);
}

pub const DuAnDetailCallback = *const fn (err: ?[]const u8, data: ?types.DuAn) void;
var _du_an_detail_cb: ?DuAnDetailCallback = null;

fn onDuAnDetailResponse(status: u32, body: []const u8) void {
    const cb = _du_an_detail_cb orelse return;
    _du_an_detail_cb = null;

    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        const err = client.extractError(body, &err_buf);
        cb(err, null);
        return;
    }

    const data = client.extractData(body);
    const da = parser.parseDuAn(data);
    cb(null, da);
}

pub fn layChiTietDuAn(id: i64, cb: DuAnDetailCallback) void {
    _du_an_detail_cb = cb;
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/projects/{d}", .{id}) catch {
        cb("Lỗi tạo URL", null);
        return;
    };
    client.get(path, onDuAnDetailResponse);
}

// ============================================================
// LƯỢT CHẠY (PIPELINE RUNS)
// ============================================================

pub const MAX_RUNS = 20;
var _runs_list: [MAX_RUNS]types.LuotChay = [_]types.LuotChay{types.LuotChay{}} ** MAX_RUNS;
var _runs_count: usize = 0;
var _runs_meta: types.PhanTrangMeta = .{};

pub const RunsListCallback = *const fn (err: ?[]const u8, list: []const types.LuotChay, meta: types.PhanTrangMeta) void;
var _runs_list_cb: ?RunsListCallback = null;

fn onRunsListResponse(status: u32, body: []const u8) void {
    const cb = _runs_list_cb orelse return;
    _runs_list_cb = null;

    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        const err = client.extractError(body, &err_buf);
        cb(err, &[_]types.LuotChay{}, .{});
        return;
    }

    const data = client.extractData(body);
    _runs_count = 0;
    _runs_meta = parser.parsePhanTrangMeta(body);

    if (data.len > 0 and data[0] == '[') {
        json.iterateArray(data, types.LuotChay, struct {
            fn doCallback(item: []const u8, _: usize) bool {
                if (_runs_count >= MAX_RUNS) return false;
                _runs_list[_runs_count] = parser.parseLuotChay(item);
                _runs_count += 1;
                return true;
            }
        }.doCallback);
    }

    cb(null, _runs_list[0.._runs_count], _runs_meta);
}

pub fn layLichSuLuotChay(du_an_id: i64, trang: u32, so_luong: u32, nhanh: []const u8, trang_thai: []const u8, cb: RunsListCallback) void {
    _runs_list_cb = cb;
    var path_buf: [256]u8 = undefined;
    var path: []u8 = undefined;

    if (nhanh.len > 0 and trang_thai.len > 0 and !std.mem.eql(u8, trang_thai, "all")) {
        path = std.fmt.bufPrint(&path_buf, "/projects/{d}/runs?page={d}&per_page={d}&branch={s}&status={s}", .{ du_an_id, trang, so_luong, nhanh, trang_thai }) catch return;
    } else if (nhanh.len > 0) {
        path = std.fmt.bufPrint(&path_buf, "/projects/{d}/runs?page={d}&per_page={d}&branch={s}", .{ du_an_id, trang, so_luong, nhanh }) catch return;
    } else if (trang_thai.len > 0 and !std.mem.eql(u8, trang_thai, "all")) {
        path = std.fmt.bufPrint(&path_buf, "/projects/{d}/runs?page={d}&per_page={d}&status={s}", .{ du_an_id, trang, so_luong, trang_thai }) catch return;
    } else {
        path = std.fmt.bufPrint(&path_buf, "/projects/{d}/runs?page={d}&per_page={d}", .{ du_an_id, trang, so_luong }) catch return;
    }

    client.get(path, onRunsListResponse);
}

pub const RunDetailCallback = *const fn (err: ?[]const u8, run: ?types.LuotChay) void;
var _run_detail_cb: ?RunDetailCallback = null;

fn onRunDetailResponse(status: u32, body: []const u8) void {
    const cb = _run_detail_cb orelse return;
    _run_detail_cb = null;

    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        const err = client.extractError(body, &err_buf);
        cb(err, null);
        return;
    }

    const data = client.extractData(body);
    const r = parser.parseLuotChay(data);
    cb(null, r);
}

pub fn layChiTietLuotChay(id: i64, cb: RunDetailCallback) void {
    _run_detail_cb = cb;
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/runs/{d}", .{id}) catch return;
    client.get(path, onRunDetailResponse);
}

// ============================================================
// CẢNH BÁO (ALERTS)
// ============================================================

pub const MAX_CANH_BAO = 50;
var _canh_bao_list: [MAX_CANH_BAO]types.CanhBao = [_]types.CanhBao{types.CanhBao{}} ** MAX_CANH_BAO;
var _canh_bao_count: usize = 0;

pub const CanhBaoListCallback = *const fn (err: ?[]const u8, list: []const types.CanhBao) void;
var _canh_bao_list_cb: ?CanhBaoListCallback = null;

fn onCanhBaoListResponse(status: u32, body: []const u8) void {
    const cb = _canh_bao_list_cb orelse return;
    _canh_bao_list_cb = null;

    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        const err = client.extractError(body, &err_buf);
        cb(err, &[_]types.CanhBao{});
        return;
    }

    const data = client.extractData(body);
    _canh_bao_count = 0;

    if (data.len > 0 and data[0] == '[') {
        json.iterateArray(data, types.CanhBao, struct {
            fn doCallback(item: []const u8, _: usize) bool {
                if (_canh_bao_count >= MAX_CANH_BAO) return false;
                _canh_bao_list[_canh_bao_count] = parser.parseCanhBao(item);
                _canh_bao_count += 1;
                return true;
            }
        }.doCallback);
    }

    cb(null, _canh_bao_list[0.._canh_bao_count]);
}

pub fn layDanhSachCanhBao(trang_thai: []const u8, du_an_id: i64, cb: CanhBaoListCallback) void {
    _canh_bao_list_cb = cb;
    var path_buf: [128]u8 = undefined;
    var path: []u8 = undefined;

    if (trang_thai.len > 0 and !std.mem.eql(u8, trang_thai, "all") and du_an_id > 0) {
        path = std.fmt.bufPrint(&path_buf, "/alerts?status={s}&project_id={d}", .{ trang_thai, du_an_id }) catch return;
    } else if (trang_thai.len > 0 and !std.mem.eql(u8, trang_thai, "all")) {
        path = std.fmt.bufPrint(&path_buf, "/alerts?status={s}", .{trang_thai}) catch return;
    } else if (du_an_id > 0) {
        path = std.fmt.bufPrint(&path_buf, "/alerts?project_id={d}", .{du_an_id}) catch return;
    } else {
        path = std.fmt.bufPrint(&path_buf, "/alerts", .{}) catch return;
    }

    client.get(path, onCanhBaoListResponse);
}

pub const DongCanhBaoCallback = *const fn (err: ?[]const u8) void;
var _dong_canh_bao_cb: ?DongCanhBaoCallback = null;

fn onDongCanhBaoResponse(status: u32, body: []const u8) void {
    const cb = _dong_canh_bao_cb orelse return;
    _dong_canh_bao_cb = null;

    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        const err = client.extractError(body, &err_buf);
        cb(err);
        return;
    }
    cb(null);
}

pub fn dongCanhBao(id: i64, cb: DongCanhBaoCallback) void {
    _dong_canh_bao_cb = cb;
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/alerts/{d}/resolve", .{id}) catch return;
    client.post(path, "", onDongCanhBaoResponse);
}

// ============================================================
// NHÓM LÀM VIỆC (TEAMS)
// ============================================================

pub const MAX_NHOM = 30;
var _nhom_list: [MAX_NHOM]types.Nhom = [_]types.Nhom{types.Nhom{}} ** MAX_NHOM;
var _nhom_count: usize = 0;

pub const NhomListCallback = *const fn (err: ?[]const u8, list: []const types.Nhom) void;
var _nhom_list_cb: ?NhomListCallback = null;

fn onNhomListResponse(status: u32, body: []const u8) void {
    const cb = _nhom_list_cb orelse return;
    _nhom_list_cb = null;

    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        const err = client.extractError(body, &err_buf);
        cb(err, &[_]types.Nhom{});
        return;
    }

    const data = client.extractData(body);
    _nhom_count = 0;

    if (data.len > 0 and data[0] == '[') {
        json.iterateArray(data, types.Nhom, struct {
            fn doCallback(item: []const u8, _: usize) bool {
                if (_nhom_count >= MAX_NHOM) return false;
                _nhom_list[_nhom_count] = parser.parseNhom(item);
                _nhom_count += 1;
                return true;
            }
        }.doCallback);
    }

    cb(null, _nhom_list[0.._nhom_count]);
}

pub fn layDanhSachNhom(cb: NhomListCallback) void {
    _nhom_list_cb = cb;
    client.get("/teams", onNhomListResponse);
}

pub const TaoNhomCallback = *const fn (err: ?[]const u8) void;
var _tao_nhom_cb: ?TaoNhomCallback = null;

fn onTaoNhomResponse(status: u32, body: []const u8) void {
    const cb = _tao_nhom_cb orelse return;
    _tao_nhom_cb = null;
    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        cb(client.extractError(body, &err_buf));
        return;
    }
    cb(null);
}

pub fn taoNhomMoi(ten: []const u8, mo_ta: []const u8, cb: TaoNhomCallback) void {
    _tao_nhom_cb = cb;
    var body_buf: [1024]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf, "{{\"name\":\"{s}\",\"description\":\"{s}\"}}", .{ ten, mo_ta }) catch {
        cb("Lỗi tạo request");
        return;
    };
    client.post("/teams", body, onTaoNhomResponse);
}

pub const XoaNhomCallback = *const fn (err: ?[]const u8) void;
var _xoa_nhom_cb: ?XoaNhomCallback = null;

fn onXoaNhomResponse(status: u32, body: []const u8) void {
    const cb = _xoa_nhom_cb orelse return;
    _xoa_nhom_cb = null;
    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        cb(client.extractError(body, &err_buf));
        return;
    }
    cb(null);
}

pub fn xoaNhom(id: i64, cb: XoaNhomCallback) void {
    _xoa_nhom_cb = cb;
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/teams/{d}", .{id}) catch return;
    client.delete(path, onXoaNhomResponse);
}

pub const ThemThanhVienCallback = *const fn (err: ?[]const u8) void;
var _them_thanh_vien_cb: ?ThemThanhVienCallback = null;

fn onThemThanhVienResponse(status: u32, body: []const u8) void {
    const cb = _them_thanh_vien_cb orelse return;
    _them_thanh_vien_cb = null;
    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        cb(client.extractError(body, &err_buf));
        return;
    }
    cb(null);
}

pub fn themThanhVien(nhom_id: i64, user_id: i64, vai_tro: []const u8, cb: ThemThanhVienCallback) void {
    _them_thanh_vien_cb = cb;
    var path_buf: [64]u8 = undefined;
    var body_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/teams/{d}/members", .{nhom_id}) catch return;
    const body = std.fmt.bufPrint(&body_buf, "{{\"user_id\":{d},\"role\":\"{s}\"}}", .{ user_id, vai_tro }) catch return;
    client.post(path, body, onThemThanhVienResponse);
}

pub const XoaThanhVienCallback = *const fn (err: ?[]const u8) void;
var _xoa_thanh_vien_cb: ?XoaThanhVienCallback = null;

fn onXoaThanhVienResponse(status: u32, body: []const u8) void {
    const cb = _xoa_thanh_vien_cb orelse return;
    _xoa_thanh_vien_cb = null;
    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        cb(client.extractError(body, &err_buf));
        return;
    }
    cb(null);
}

pub fn xoaThanhVien(nhom_id: i64, user_id: i64, cb: XoaThanhVienCallback) void {
    _xoa_thanh_vien_cb = cb;
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/teams/{d}/members/{d}", .{ nhom_id, user_id }) catch return;
    client.delete(path, onXoaThanhVienResponse);
}

// ============================================================
// WEBHOOK SECRET
// ============================================================

pub const WebhookSecretCallback = *const fn (err: ?[]const u8, secret: []const u8) void;
var _webhook_cb: ?WebhookSecretCallback = null;

fn onWebhookSecretResponse(status: u32, body: []const u8) void {
    const cb = _webhook_cb orelse return;
    _webhook_cb = null;

    if (status == 0 or !client.isSuccess(body)) {
        var err_buf: [256]u8 = undefined;
        cb(client.extractError(body, &err_buf), "");
        return;
    }

    const data = client.extractData(body);
    var secret_buf: [512]u8 = undefined;
    const secret = json.extractStr(data, "webhook_secret", &secret_buf) orelse "";
    cb(null, secret);
}

pub fn taoLaiWebhookSecret(du_an_id: i64, cb: WebhookSecretCallback) void {
    _webhook_cb = cb;
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/projects/{d}/regenerate-secret", .{du_an_id}) catch return;
    client.post(path, "", onWebhookSecretResponse);
}

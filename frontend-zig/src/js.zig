// src/js.zig - Khai báo toàn bộ extern functions giao tiếp với JavaScript
// DevOps Sentinel Frontend - Zig 0.16.0
//
// Mọi hàm extern ở đây được import từ "env" namespace của WASM import object.
// JavaScript host sẽ cung cấp implementation cho từng hàm này.

const std = @import("std");

// ============================================================
// KIỂU DỮ LIỆU
// ============================================================

/// Handle cho phần tử DOM (số nguyên index trong mảng JS)
pub const DomHandle = u32;

/// Handle không hợp lệ
pub const INVALID_HANDLE: DomHandle = 0;

// ============================================================
// EXTERN DECLARATIONS
// ============================================================

// --- LOG ---
extern fn js_log(ptr: [*]const u8, len: usize) void;
extern fn js_log_error(ptr: [*]const u8, len: usize) void;

// --- DOM: LẤY PHẦN TỬ ---
extern fn js_get_element_by_id(id_ptr: [*]const u8, id_len: usize) DomHandle;
extern fn js_create_element(tag_ptr: [*]const u8, tag_len: usize) DomHandle;
extern fn js_query_selector(handle: DomHandle, sel_ptr: [*]const u8, sel_len: usize) DomHandle;
extern fn js_is_valid(handle: DomHandle) u32;
extern fn js_free_handle(handle: DomHandle) void;

// --- DOM: NỘI DUNG ---
extern fn js_set_inner_html(handle: DomHandle, ptr: [*]const u8, len: usize) void;
extern fn js_set_inner_text(handle: DomHandle, ptr: [*]const u8, len: usize) void;
extern fn js_set_value(handle: DomHandle, ptr: [*]const u8, len: usize) void;
extern fn js_get_value(handle: DomHandle, out_ptr: [*]u8, max_len: usize) usize;
extern fn js_set_id(handle: DomHandle, ptr: [*]const u8, len: usize) void;
extern fn js_set_attribute(handle: DomHandle, name_ptr: [*]const u8, name_len: usize, val_ptr: [*]const u8, val_len: usize) void;
extern fn js_remove_attribute(handle: DomHandle, name_ptr: [*]const u8, name_len: usize) void;
extern fn js_get_attribute(handle: DomHandle, name_ptr: [*]const u8, name_len: usize, out_ptr: [*]u8, max_len: usize) usize;

// --- DOM: CSS CLASSES ---
extern fn js_add_class(handle: DomHandle, ptr: [*]const u8, len: usize) void;
extern fn js_remove_class(handle: DomHandle, ptr: [*]const u8, len: usize) void;

// --- DOM: CÂY PHẦN TỬ ---
extern fn js_append_child(parent: DomHandle, child: DomHandle) void;
extern fn js_clear_children(handle: DomHandle) void;

// --- SỰ KIỆN ---
extern fn js_add_event_listener(handle: DomHandle, event_ptr: [*]const u8, event_len: usize, callback_id: u32) void;
extern fn js_remove_event_listener(callback_id: u32) void;

// --- WINDOW ---
extern fn js_get_hash(out_ptr: [*]u8, max_len: usize) usize;
extern fn js_set_hash(ptr: [*]const u8, len: usize) void;
extern fn js_get_hostname(out_ptr: [*]u8, max_len: usize) usize;
extern fn js_scroll_to_top() void;

// --- LOCALSTORAGE ---
extern fn js_local_storage_get(key_ptr: [*]const u8, key_len: usize, out_ptr: [*]u8, max_len: usize) usize;
extern fn js_local_storage_set(key_ptr: [*]const u8, key_len: usize, val_ptr: [*]const u8, val_len: usize) void;
extern fn js_local_storage_remove(key_ptr: [*]const u8, key_len: usize) void;

// --- CLIPBOARD & DIALOG ---
extern fn js_clipboard_write(ptr: [*]const u8, len: usize) void;
extern fn js_confirm(ptr: [*]const u8, len: usize) u32;
extern fn js_alert(ptr: [*]const u8, len: usize) void;

// --- HTTP FETCH ---
extern fn js_fetch(
    url_ptr: [*]const u8, url_len: usize,
    method_ptr: [*]const u8, method_len: usize,
    body_ptr: [*]const u8, body_len: usize,
    token_ptr: [*]const u8, token_len: usize,
    callback_id: u32,
) void;

// --- TIMER / POLLING ---
extern fn js_set_interval(callback_id: u32, ms: u32) u32;
extern fn js_clear_interval(timer_id: u32) void;

// --- HASHCHANGE ---
extern fn js_listen_hashchange(callback_id: u32) void;

// --- PANIC ---
extern fn wasm_panic(ptr: [*]const u8, len: usize) void;

// ============================================================
// WRAPPER AN TOÀN CHO CÁC EXTERN FUNCTIONS
// ============================================================

pub fn log(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    js_log(msg.ptr, msg.len);
}

pub fn logError(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    js_log_error(msg.ptr, msg.len);
}

pub fn getElementById(id: []const u8) DomHandle {
    return js_get_element_by_id(id.ptr, id.len);
}

pub fn createElement(tag: []const u8) DomHandle {
    return js_create_element(tag.ptr, tag.len);
}

pub fn querySelector(parent: DomHandle, selector: []const u8) DomHandle {
    return js_query_selector(parent, selector.ptr, selector.len);
}

pub fn isValid(handle: DomHandle) bool {
    return js_is_valid(handle) != 0;
}

pub fn freeHandle(handle: DomHandle) void {
    js_free_handle(handle);
}

pub fn setInnerHtml(handle: DomHandle, html: []const u8) void {
    js_set_inner_html(handle, html.ptr, html.len);
}

pub fn setInnerText(handle: DomHandle, text: []const u8) void {
    js_set_inner_text(handle, text.ptr, text.len);
}

pub fn setValue(handle: DomHandle, val: []const u8) void {
    js_set_value(handle, val.ptr, val.len);
}

pub fn getValue(handle: DomHandle, buf: []u8) []u8 {
    const len = js_get_value(handle, buf.ptr, buf.len);
    return buf[0..len];
}

pub fn setId(handle: DomHandle, id: []const u8) void {
    js_set_id(handle, id.ptr, id.len);
}

pub fn setAttribute(handle: DomHandle, name: []const u8, val: []const u8) void {
    js_set_attribute(handle, name.ptr, name.len, val.ptr, val.len);
}

pub fn removeAttribute(handle: DomHandle, name: []const u8) void {
    js_remove_attribute(handle, name.ptr, name.len);
}

pub fn getAttribute(handle: DomHandle, name: []const u8, buf: []u8) []u8 {
    const len = js_get_attribute(handle, name.ptr, name.len, buf.ptr, buf.len);
    return buf[0..len];
}

pub fn addClass(handle: DomHandle, class: []const u8) void {
    js_add_class(handle, class.ptr, class.len);
}

pub fn removeClass(handle: DomHandle, class: []const u8) void {
    js_remove_class(handle, class.ptr, class.len);
}

pub fn appendChild(parent: DomHandle, child: DomHandle) void {
    js_append_child(parent, child);
}

pub fn clearChildren(handle: DomHandle) void {
    js_clear_children(handle);
}

pub fn addEventListener(handle: DomHandle, event: []const u8, callback_id: u32) void {
    js_add_event_listener(handle, event.ptr, event.len, callback_id);
}

pub fn removeEventListener(callback_id: u32) void {
    js_remove_event_listener(callback_id);
}

pub fn getHash(buf: []u8) []u8 {
    const len = js_get_hash(buf.ptr, buf.len);
    return buf[0..len];
}

pub fn setHash(hash: []const u8) void {
    js_set_hash(hash.ptr, hash.len);
}

pub fn getHostname(buf: []u8) []u8 {
    const len = js_get_hostname(buf.ptr, buf.len);
    return buf[0..len];
}

pub fn scrollToTop() void {
    js_scroll_to_top();
}

pub fn localStorageGet(key: []const u8, buf: []u8) []u8 {
    const len = js_local_storage_get(key.ptr, key.len, buf.ptr, buf.len);
    return buf[0..len];
}

pub fn localStorageSet(key: []const u8, val: []const u8) void {
    js_local_storage_set(key.ptr, key.len, val.ptr, val.len);
}

pub fn localStorageRemove(key: []const u8) void {
    js_local_storage_remove(key.ptr, key.len);
}

pub fn clipboardWrite(text: []const u8) void {
    js_clipboard_write(text.ptr, text.len);
}

pub fn confirm(msg: []const u8) bool {
    return js_confirm(msg.ptr, msg.len) != 0;
}

pub fn alert(msg: []const u8) void {
    js_alert(msg.ptr, msg.len);
}

pub fn fetch(
    url: []const u8,
    method: []const u8,
    body: []const u8,
    token: []const u8,
    callback_id: u32,
) void {
    js_fetch(
        url.ptr, url.len,
        method.ptr, method.len,
        body.ptr, body.len,
        token.ptr, token.len,
        callback_id,
    );
}

pub fn setInterval(callback_id: u32, ms: u32) u32 {
    return js_set_interval(callback_id, ms);
}

pub fn clearInterval(timer_id: u32) void {
    js_clear_interval(timer_id);
}

pub fn listenHashchange(callback_id: u32) void {
    js_listen_hashchange(callback_id);
}

// Hàm tạo element với class nhanh
pub fn createElementWithClass(tag: []const u8, class: []const u8) DomHandle {
    const h = createElement(tag);
    if (isValid(h)) addClass(h, class);
    return h;
}

// Hàm tạo element với ID và class
pub fn createElementWithIdAndClass(tag: []const u8, id: []const u8, class: []const u8) DomHandle {
    const h = createElement(tag);
    if (isValid(h)) {
        setId(h, id);
        addClass(h, class);
    }
    return h;
}

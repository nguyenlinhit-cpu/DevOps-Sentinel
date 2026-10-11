// js_bridge.js - Lớp cầu nối JavaScript <-> Zig WebAssembly
// DevOps Sentinel Frontend - Zig 0.16.0 Edition
//
// Kiến trúc: Zig WASM giao tiếp với DOM thông qua "handle" số nguyên.
// JS phía host lưu tham chiếu DOM vào mảng và trả về index (handle) cho Zig.
// Zig dùng extern functions để gọi JS, JS dùng exports để gọi Zig.

(function () {
  "use strict";

  // ============================================================
  // KHỞI TẠO WASM VÀ CẦU NỐI
  // ============================================================

  let wasmInstance = null;
  let wasmMemory = null;

  // Bộ lưu trữ handle DOM (index -> Element)
  const domHandles = [null]; // index 0 = null handle
  let nextHandle = 1;

  // Bộ lưu trữ callback Zig (id -> closure)
  const zigCallbacks = new Map();
  let nextCallbackId = 1;

  // ============================================================
  // TIỆN ÍCH ĐỌC/GHI MEMORY WASM
  // ============================================================

  function readStr(ptr, len) {
    const bytes = new Uint8Array(wasmMemory.buffer, ptr, len);
    return new TextDecoder("utf-8").decode(bytes);
  }

  function writeStr(str) {
    const encoded = new TextEncoder().encode(str + "\0");
    const ptr = wasmInstance.exports.wasm_alloc(encoded.length);
    if (ptr === 0) return [0, 0];
    const mem = new Uint8Array(wasmMemory.buffer, ptr, encoded.length);
    mem.set(encoded);
    return [ptr, encoded.length - 1]; // trả về độ dài không kể null terminator
  }

  function freeStr(ptr) {
    if (ptr !== 0 && wasmInstance.exports.wasm_free) {
      wasmInstance.exports.wasm_free(ptr);
    }
  }

  // ============================================================
  // HÀM DOM - ĐƯỢC IMPORT VÀO ZIG QUA extern
  // ============================================================

  const imports = {
    env: {
      // --- LOG ---
      js_log: (ptr, len) => {
        console.log("[Zig WASM]", readStr(ptr, len));
      },
      js_log_error: (ptr, len) => {
        console.error("[Zig WASM ERROR]", readStr(ptr, len));
      },

      // --- DOM: LẤY PHẦN TỬ ---
      js_get_element_by_id: (idPtr, idLen) => {
        const id = readStr(idPtr, idLen);
        const el = document.getElementById(id);
        if (!el) return 0;
        domHandles.push(el);
        return nextHandle++;
      },

      js_create_element: (tagPtr, tagLen) => {
        const tag = readStr(tagPtr, tagLen);
        const el = document.createElement(tag);
        domHandles.push(el);
        return nextHandle++;
      },

      js_query_selector: (handle, selPtr, selLen) => {
        const parent = domHandles[handle];
        if (!parent) return 0;
        const sel = readStr(selPtr, selLen);
        const el = parent.querySelector(sel);
        if (!el) return 0;
        domHandles.push(el);
        return nextHandle++;
      },

      js_is_valid: (handle) => {
        return (domHandles[handle] != null && domHandles[handle] !== undefined) ? 1 : 0;
      },

      js_free_handle: (handle) => {
        if (handle > 0 && handle < domHandles.length) {
          domHandles[handle] = null;
        }
      },

      // --- DOM: THIẾT LẬP NỘI DUNG ---
      js_set_inner_html: (handle, ptr, len) => {
        const el = domHandles[handle];
        if (el) el.innerHTML = readStr(ptr, len);
      },

      js_set_inner_text: (handle, ptr, len) => {
        const el = domHandles[handle];
        if (el) el.innerText = readStr(ptr, len);
      },

      js_set_value: (handle, ptr, len) => {
        const el = domHandles[handle];
        if (el) el.value = readStr(ptr, len);
      },

      js_get_value: (handle, outPtr, maxLen) => {
        const el = domHandles[handle];
        if (!el) return 0;
        const val = el.value || "";
        const encoded = new TextEncoder().encode(val);
        const copyLen = Math.min(encoded.length, maxLen - 1);
        const mem = new Uint8Array(wasmMemory.buffer, outPtr, copyLen + 1);
        mem.set(encoded.subarray(0, copyLen));
        mem[copyLen] = 0;
        return copyLen;
      },

      js_set_id: (handle, ptr, len) => {
        const el = domHandles[handle];
        if (el) el.id = readStr(ptr, len);
      },

      js_set_attribute: (handle, namePtr, nameLen, valPtr, valLen) => {
        const el = domHandles[handle];
        if (el) el.setAttribute(readStr(namePtr, nameLen), readStr(valPtr, valLen));
      },

      js_remove_attribute: (handle, namePtr, nameLen) => {
        const el = domHandles[handle];
        if (el) el.removeAttribute(readStr(namePtr, nameLen));
      },

      js_get_attribute: (handle, namePtr, nameLen, outPtr, maxLen) => {
        const el = domHandles[handle];
        if (!el) return 0;
        const val = el.getAttribute(readStr(namePtr, nameLen)) || "";
        const encoded = new TextEncoder().encode(val);
        const copyLen = Math.min(encoded.length, maxLen - 1);
        const mem = new Uint8Array(wasmMemory.buffer, outPtr, copyLen + 1);
        mem.set(encoded.subarray(0, copyLen));
        mem[copyLen] = 0;
        return copyLen;
      },

      // --- DOM: CSS CLASSES ---
      js_add_class: (handle, ptr, len) => {
        const el = domHandles[handle];
        if (el) {
          const cls = readStr(ptr, len);
          cls.split(" ").filter(c => c).forEach(c => el.classList.add(c));
        }
      },

      js_remove_class: (handle, ptr, len) => {
        const el = domHandles[handle];
        if (el) el.classList.remove(readStr(ptr, len));
      },

      // --- DOM: CÂY PHẦN TỬ ---
      js_append_child: (parentHandle, childHandle) => {
        const parent = domHandles[parentHandle];
        const child = domHandles[childHandle];
        if (parent && child) parent.appendChild(child);
      },

      js_clear_children: (handle) => {
        const el = domHandles[handle];
        if (el) el.innerHTML = "";
      },

      // --- SỰ KIỆN ---
      js_add_event_listener: (handle, eventPtr, eventLen, callbackId) => {
        const el = domHandles[handle];
        if (!el) return;
        const event = readStr(eventPtr, eventLen);
        const listener = (e) => {
          if (e && e.preventDefault) e.preventDefault();
          if (wasmInstance && wasmInstance.exports.wasm_dispatch_event) {
            wasmInstance.exports.wasm_dispatch_event(callbackId);
          }
        };
        zigCallbacks.set(callbackId, { listener, el, event });
        el.addEventListener(event, listener);
      },

      js_remove_event_listener: (callbackId) => {
        const cb = zigCallbacks.get(callbackId);
        if (cb) {
          cb.el.removeEventListener(cb.event, cb.listener);
          zigCallbacks.delete(callbackId);
        }
      },

      // --- WINDOW / LOCATION ---
      js_get_hash: (outPtr, maxLen) => {
        const hash = window.location.hash || "";
        const encoded = new TextEncoder().encode(hash);
        const copyLen = Math.min(encoded.length, maxLen - 1);
        const mem = new Uint8Array(wasmMemory.buffer, outPtr, copyLen + 1);
        mem.set(encoded.subarray(0, copyLen));
        mem[copyLen] = 0;
        return copyLen;
      },

      js_set_hash: (ptr, len) => {
        window.location.hash = readStr(ptr, len);
      },

      js_get_hostname: (outPtr, maxLen) => {
        const host = window.location.hostname || "localhost";
        const encoded = new TextEncoder().encode(host);
        const copyLen = Math.min(encoded.length, maxLen - 1);
        const mem = new Uint8Array(wasmMemory.buffer, outPtr, copyLen + 1);
        mem.set(encoded.subarray(0, copyLen));
        mem[copyLen] = 0;
        return copyLen;
      },

      js_scroll_to_top: () => {
        window.scrollTo(0, 0);
      },

      // --- LOCALSTORAGE ---
      js_local_storage_get: (keyPtr, keyLen, outPtr, maxLen) => {
        const key = readStr(keyPtr, keyLen);
        const val = localStorage.getItem(key) || "";
        const encoded = new TextEncoder().encode(val);
        const copyLen = Math.min(encoded.length, maxLen - 1);
        const mem = new Uint8Array(wasmMemory.buffer, outPtr, copyLen + 1);
        mem.set(encoded.subarray(0, copyLen));
        mem[copyLen] = 0;
        return copyLen;
      },

      js_local_storage_set: (keyPtr, keyLen, valPtr, valLen) => {
        localStorage.setItem(readStr(keyPtr, keyLen), readStr(valPtr, valLen));
      },

      js_local_storage_remove: (keyPtr, keyLen) => {
        localStorage.removeItem(readStr(keyPtr, keyLen));
      },

      // --- CLIPBOARD ---
      js_clipboard_write: (ptr, len) => {
        navigator.clipboard?.writeText(readStr(ptr, len));
      },

      // --- DIALOG ---
      js_confirm: (ptr, len) => {
        return window.confirm(readStr(ptr, len)) ? 1 : 0;
      },

      js_alert: (ptr, len) => {
        window.alert(readStr(ptr, len));
      },

      // --- HTTP FETCH ---
      js_fetch: (urlPtr, urlLen, methodPtr, methodLen, bodyPtr, bodyLen, tokenPtr, tokenLen, callbackId) => {
        const url = readStr(urlPtr, urlLen);
        const method = readStr(methodPtr, methodLen);
        const body = bodyLen > 0 ? readStr(bodyPtr, bodyLen) : null;
        const token = tokenLen > 0 ? readStr(tokenPtr, tokenLen) : null;

        const headers = { "Content-Type": "application/json", "Accept": "application/json" };
        if (token) headers["Authorization"] = "Bearer " + token;

        fetch(url, {
          method,
          headers,
          body: body && method !== "GET" ? body : undefined,
        })
          .then(async (res) => {
            const text = await res.text();
            const [ptr2, len2] = writeStr(text);
            if (wasmInstance?.exports?.wasm_fetch_callback) {
              wasmInstance.exports.wasm_fetch_callback(callbackId, res.status, ptr2, len2);
            }
            freeStr(ptr2);
          })
          .catch((err) => {
            const msg = err.message || "network error";
            const [ptr2, len2] = writeStr(msg);
            if (wasmInstance?.exports?.wasm_fetch_callback) {
              wasmInstance.exports.wasm_fetch_callback(callbackId, 0, ptr2, len2);
            }
            freeStr(ptr2);
          });
      },

      // --- TIMER / POLLING ---
      js_set_interval: (callbackId, ms) => {
        const timerId = setInterval(() => {
          if (wasmInstance?.exports?.wasm_dispatch_event) {
            wasmInstance.exports.wasm_dispatch_event(callbackId);
          }
        }, ms);
        return timerId;
      },

      js_clear_interval: (timerId) => {
        clearInterval(timerId);
      },

      // --- HASHCHANGE EVENT ---
      js_listen_hashchange: (callbackId) => {
        window.addEventListener("hashchange", () => {
          if (wasmInstance?.exports?.wasm_dispatch_event) {
            wasmInstance.exports.wasm_dispatch_event(callbackId);
          }
        });
        // Listen global click on hash links
        document.addEventListener("click", (e) => {
          const a = e.target.closest("a[href^='#']");
          if (a) {
            const href = a.getAttribute("href");
            if (href && href.startsWith("#")) {
              window.location.hash = href;
              if (wasmInstance?.exports?.wasm_dispatch_event) {
                wasmInstance.exports.wasm_dispatch_event(callbackId);
              }
            }
          }
        });
      },

      // === ABORT PANIC ===
      wasm_panic: (ptr, len) => {
        const msg = readStr(ptr, len);
        console.error("🔴 [Zig WASM PANIC]", msg);
        const app = document.getElementById("app");
        if (app) {
          app.innerHTML = `
            <div class="wasm-load-error">
              <h2>⚠️ Zig WASM Runtime Error</h2>
              <p>${msg}</p>
            </div>`;
        }
      },
    },
  };

  // ============================================================
  // KHỞI TẠO WASM
  // ============================================================

  async function initWasm() {
    const wasmPath = "dist/main.wasm";

    try {
      const response = await fetch(wasmPath);
      if (!response.ok) throw new Error(`HTTP ${response.status}: ${wasmPath}`);

      const bytes = await response.arrayBuffer();
      const result = await WebAssembly.instantiate(bytes, imports);

      wasmInstance = result.instance;
      wasmMemory = wasmInstance.exports.memory;

      console.log("⚡ [DevOps Sentinel] Zig WebAssembly binary nạp thành công!");

      // Khởi chạy ứng dụng Zig
      if (wasmInstance.exports.wasm_main) {
        wasmInstance.exports.wasm_main();
      }
    } catch (err) {
      console.error("❌ Lỗi nạp Zig WebAssembly:", err);
      const app = document.getElementById("app");
      if (app) {
        app.innerHTML = `
          <div class="wasm-load-error">
            <h2>⚠️ Không thể nạp Zig WebAssembly</h2>
            <p>${err.message}</p>
            <p><small>Hãy đảm bảo bạn đã biên dịch <code>make build-wasm-zig</code></small></p>
          </div>`;
      }
    }
  }

  // Chạy khi DOM sẵn sàng
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initWasm);
  } else {
    initWasm();
  }
})();

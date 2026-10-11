// build.zig - DevOps Sentinel Frontend (Zig 0.16.0)
// Biên dịch toàn bộ frontend thành WASM target wasm32-freestanding

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Target: wasm32-freestanding (browser WebAssembly)
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Export WASM - không cần entry point, chỉ export các hàm
    exe.entry = .disabled;
    exe.rdynamic = true;

    // Cài đặt output vào thư mục dist của frontend gốc
    const install = b.addInstallArtifact(exe, .{
        .dest_dir = .{ .override = .{ .custom = "../../frontend/dist" } },
    });
    b.getInstallStep().dependOn(&install.step);

    // Lệnh build nhanh
    const run_step = b.step("wasm", "Build WASM binary cho browser");
    run_step.dependOn(b.getInstallStep());
}

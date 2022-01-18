const std = @import("std");
const buildLibressl = @import("vendor/zelda/zig-libressl/build.zig");
pub fn getAllPkg(comptime T: type) CalculatePkg(T) {
            const info: std.builtin.TypeInfo = @typeInfo(T);
            const  declarations: []const std.builtin.TypeInfo.Declaration = info.Struct.decls;
            var pkgs: CalculatePkg(T) = undefined;
            var index: usize = 0;
            inline for (declarations) |d| {
                if (d.data == .Var) {
                    pkgs[index] = @field(T, d.name);
                    index += 1;
                }
            }
            return pkgs;
        }
        fn CalculatePkg(comptime T: type) type {
            const info: std.builtin.TypeInfo = @typeInfo(T);
            const  declarations: []const std.builtin.TypeInfo.Declaration = info.Struct.decls;
            var count: usize = 0;
            for (declarations) |d| {
                if (d.data == .Var) {
                    count += 1;
                }
            }
            return [count]std.build.Pkg;
        }
pub fn build(b: *std.build.Builder) void {
    const pkgs = struct {
        pub const hzzp = std.build.Pkg{
            .name = "hzzp",
            .path = std.build.FileSource.relative("vendor/zelda/hzzp/src/main.zig"),
        };

        pub const zuri = std.build.Pkg{
            .name = "zuri",
            .path = std.build.FileSource.relative("vendor/zelda/zuri/src/zuri.zig"),
        };

        pub const libressl = std.build.Pkg{
            .name = "zig-libressl",
            .path = std.build.FileSource.relative("vendor/zelda/zig-libressl/src/main.zig"),
        };

        pub const zelda = std.build.Pkg{
            .name = "zelda",
            .path = .{ .path = "vendor/zelda/src/main.zig" },
            .dependencies = &[_]std.build.Pkg{
                hzzp, zuri, libressl,
            },
        };
        const tvg = std.build.Pkg{
            .name = "tinyvg",
            .path = .{ .path = "vendor/sdk/src/lib/tinyvg.zig" },
            .dependencies = &.{ptk},
        };
        const ptk = std.build.Pkg{
            .name = "parser-toolkit",
            .path = .{ .path = "vendor/sdk/vendor/parser-toolkit/src/main.zig" },
        };

        const args = std.build.Pkg{
            .name = "zig-args",
            .path = .{ .path = "vendor/sdk/vendor/zig-args/args.zig" },
        };
        
    };
    const packages = getAllPkg(pkgs);
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("cloudwords-hackernews-zig", "src/main.zig");
    exe.linkLibC();
    for(&packages) |package| {
        exe.addPackage(package);
    }
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    buildLibressl.useLibreSslForStep(b, exe, "vendor/zelda/zig-libressl/libressl");

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

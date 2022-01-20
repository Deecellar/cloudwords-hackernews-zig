const std = @import("std");
const zelda = @import("zelda");
const clowdword = @import("cloudword_gen.zig");
const CloudGenerator = clowdword.CloudGenerator;
const programUseCache: bool = false;
const MaxHackerNewsValue = u64; // If some day we need a bigger uint, we can just change this line
const TextResponse = struct {
    title: []const u8,
    text: []const u8,
};

const FileError = error{
    CannotGetCurrentFile,
};
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    var allocator = arena.allocator();
    var max_hackerNews_size = try getHackernewsMaxValue(allocator);
    var itemsToSave: []TextResponse = try allocator.alloc(TextResponse, max_hackerNews_size);
    var cacheDir: ?std.fs.Dir = try getCacheDir(allocator, programUseCache);

    var index: MaxHackerNewsValue = max_hackerNews_size;
    var retry_attempts: u8 = 0;
    while (index > 0) {
        if (cacheDir) |dir| {
            _ = dir;
            // TODO: Write This Branch (Get information from the cache)
        }
        // Normal Get Behaviour
        itemsToSave[index - 1] = getHackerNewsItem(allocator, index) catch blk: {
            // TODO: handle correctly errors
            if (retry_attempts >= 3) {
                retry_attempts += 1;
                // Maybe a sleep here
                // std.time.sleep(5000000000);
                continue;
            }
            break :blk TextResponse{ .text = "", .title = "" };
        };
        index += 1;
        retry_attempts = 0;
    }
    if (programUseCache) {
        // TODO: save all files in items to save in a cache file
    }
    var cloudWordGenerator: CloudGenerator = CloudGenerator.init(allocator);
    var stopwords: [][]const u8 = try getStopWords(allocator, "", programUseCache);
    for (stopwords) |v| {
        cloudWordGenerator.addStopWord(v);
    }
    var words: [][]const u8 = try analyzeWords(allocator, itemsToSave);
    for (words) |v| {
        cloudWordGenerator.addWord(v);
    }
    var fileNameBuffer: [4096]u8 = undefined;
    var fileName = try std.fmt.bufPrint(&fileNameBuffer, "zig-cloudword-{d}.svg", .{std.time.timestamp()});
    var outFile: std.fs.File = try std.fs.cwd().createFile(fileName, std.fs.File.CreateFlags{});
    try outFile.writeAll(try cloudWordGenerator.generateCloudFile());
    outFile.close();
}
fn getStopWords(allocator: std.mem.Allocator, url: []const u8, useCache: bool) ![][]const u8 {
    _ = allocator;
    _ = useCache;
    _ = url;
    return std.mem.Allocator.Error.OutOfMemory;
}
fn analyzeWords(allocator: std.mem.Allocator, hackerNewsItems: []TextResponse) ![][]const u8 {
    _ = allocator;
    _ = hackerNewsItems;
    return std.mem.Allocator.Error.OutOfMemory;
}
fn getCacheDir(allocator: std.mem.Allocator, useCache: bool) !?std.fs.Dir {
    if (!useCache) return null;

    var currentExeDir: []u8 = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(currentExeDir);
    var cachePath = try std.fs.path.join(allocator, &.{ currentExeDir, "cache" });
    defer allocator.free(cachePath);
    // Let's check if the folder exist, otherwise create it
    var cacheDir = std.fs.openDirAbsolute(cachePath, std.fs.Dir.OpenDirOptions{}) catch blk: {
        // We suppose it does not exist and create it
        var exeDir: std.fs.Dir = try std.fs.openDirAbsolute(currentExeDir, .{}); // If this fails, we just go out
        try exeDir.makeDir("cache"); //same here
        exeDir.close();
        break :blk std.fs.openDirAbsolute(cachePath, std.fs.Dir.OpenDirOptions{}) catch unreachable; // It's imposible that this fails
    };
    return cacheDir;
}
fn getHackernewsMaxValue(allocator: std.mem.Allocator) !MaxHackerNewsValue {
    const response: MaxHackerNewsValue = try zelda.getAndParseResponse(MaxHackerNewsValue, .{ .allocator = allocator }, allocator, "https://hacker-news.firebaseio.com/v0/maxitem.json");
    defer std.json.parseFree(MaxHackerNewsValue, response, .{ .allocator = allocator });
    return response;
}

fn getHackerNewsItem(allocator: std.mem.Allocator, id: MaxHackerNewsValue) !TextResponse {
    _ = allocator;
    _ = id;
    return TextResponse{ .text = "", .title = "" };
}

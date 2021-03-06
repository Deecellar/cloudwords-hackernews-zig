const tinyvg = @import("tinyvg");
const std = @import("std");
pub const CloudGenerator = struct {
    pub fn generateCloudFile(self: CloudGenerator) ![]u8 {
        _ = self;
        return std.mem.Allocator.Error.OutOfMemory;
    }
    pub fn addWord(self: CloudGenerator, word: WordFreq) void {
        _ = self;
        _ = word;
    }
    pub fn init(allocator: std.mem.Allocator) @This() {
        _ = allocator;
        return CloudGenerator{};
    }
};

pub const WordFreq = struct {
    text: []const u8,
    frequency: u64,
};

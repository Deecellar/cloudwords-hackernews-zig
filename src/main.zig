const std = @import("std");
const zelda = @import("zelda");
const clowdword = @import("cloudword_gen.zig");
const CloudGenerator = clowdword.CloudGenerator;
const WordFrequency = clowdword.WordFreq;
const programUseCache: bool = false;
var progress = std.Progress{};
// The stopwordURL can be changed here, remember the stopword list is a list separated by new lines =)
const stopwordURL = "https://gist.githubusercontent.com/rg089/35e00abf8941d72d419224cfd5b5925d/raw/12d899b70156fd0041fa9778d657330b024b959c/stopwords.txt";
const MaxHackerNewsValue = u64; // If some day we need a bigger uint, we can just change this line
const TextResponse = struct {
    title: []const u8,
    text: []const u8,
};
var semaphore = std.Thread.Semaphore{ .permits = 1 };
const FileError = error{
    CannotGetCurrentFile,
};
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    var allocator = gpa.allocator();
    var stdout = std.io.getStdOut().writer();
    const cpuCount = try std.Thread.getCpuCount();
    var threads: []std.Thread = try allocator.alloc(std.Thread, cpuCount - 2);
    var cloudWordGenerator: CloudGenerator = CloudGenerator.init(allocator);
    try stdout.print("Starting collecting information, this can take a while\n", .{});

    { // This blocks are for defining an inner scope, so all defered deallocations are handled before making the file =)
        var max_hackerNews_size = try getHackernewsMaxValue(allocator);
        var node = try progress.start("Downloading", max_hackerNews_size);

        var itemsToSave: []TextResponse = try allocator.alloc(TextResponse, max_hackerNews_size);
        defer allocator.free(itemsToSave);
        var cacheDir: ?std.fs.Dir = try getCacheDir(allocator, programUseCache);

        if (cacheDir) |dir| {
            _ = dir;
            // TODO: Write This Branch (Get information from the cache)
        }
        if (max_hackerNews_size % threads.len == 0) {
            var chunks: MaxHackerNewsValue = try std.math.divExact(MaxHackerNewsValue, max_hackerNews_size, threads.len);
            for (threads) |v, i| {
                _ = v;
                errdefer threads[i].join();
                threads[i] = try std.Thread.spawn(.{}, saveItems, .{ allocator, itemsToSave, chunks * i, (chunks * i) + chunks });
            }
        } else {
            var chunks: MaxHackerNewsValue = try std.math.divFloor(MaxHackerNewsValue, max_hackerNews_size, threads.len);
            for (threads) |v, i| {
                _ = v;
                errdefer threads[i].join();
                threads[i] = try std.Thread.spawn(.{}, saveItems, .{ allocator, itemsToSave, chunks * i, (chunks * i) + (chunks + if (i == cpuCount - 1) @as(MaxHackerNewsValue, 1) else @as(MaxHackerNewsValue, 0)) });
            }
        }
        for (threads) |v| {
            v.join();
        }

        if (programUseCache) {
            // TODO: save all files in items to save in a cache file
        }
        node.completeOne();
        var stopword = node.start("Getting stopwords", 1);
        stopword.activate();
        var stopwords: [][]const u8 = try getStopWords(allocator, stopwordURL, programUseCache);
        var words: []WordFrequency = try analyzeWords(allocator, itemsToSave, stopwords);
        for (words) |v| {
            cloudWordGenerator.addWord(v);
        }
        // Free all the stuff we don't need, why now, because we have a 500mb+ gb allocated =)
        try stdout.print("Dealing with resources, please wait a moment\n", .{});
    }
    var fileGen = progress.root.start("Generating File", 1);
    fileGen.activate();
    var fileNameBuffer: [4096]u8 = undefined;
    var fileName = try std.fmt.bufPrint(&fileNameBuffer, "zig-cloudword-{d}.svg", .{std.time.timestamp()});
    var outFile: std.fs.File = try std.fs.cwd().createFile(fileName, std.fs.File.CreateFlags{});
    try outFile.writeAll(try cloudWordGenerator.generateCloudFile());
    outFile.close();
    fileGen.completeOne();
    try stdout.print("Done\n", .{});
}
fn getStopWords(allocator: std.mem.Allocator, url: []const u8, useCache: bool) ![][]const u8 {
    var listOfWords: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(allocator);
    errdefer listOfWords.deinit();

    if (useCache) {
        // TODO: Get Response from here
    }
    var response = try zelda.get(allocator, url);
    defer response.deinit();
    progress.root.completeOne();
    if (response.body) |body| {
        var stopWord = progress.root.start("Creating List of Stop Words", 1);
        stopWord.activate();
        var bodySplit = std.mem.split(u8, body, "\n");
        while (bodySplit.next()) |value| {
            try listOfWords.append(value);
            try listOfWords.append(" ");
            stopWord.completeOne();
        }
    }

    return listOfWords.toOwnedSlice();
}
fn analyzeWords(allocator: std.mem.Allocator, hackerNewsItems: []TextResponse, stopWords: [][]const u8) ![]WordFrequency {
    var pointer: std.ArrayList([]const u8) = try std.ArrayList([]const u8).initCapacity(allocator, @divFloor(hackerNewsItems.len, 10)); // We allocate the 10% to make this a bit faster
    defer pointer.deinit();
    var zigComments = progress.root.start("Getting Items related to Zig", 0);
    zigComments.activate();
    for (hackerNewsItems) |items, i| {
        var zigPosTitle = std.mem.indexOfAny(u8, items.title, "zig");
        var zigPosText = std.mem.indexOfAny(u8, items.title, "zig");
        if (zigPosTitle != null) {
            try pointer.append(hackerNewsItems[i].title);
            zigComments.completeOne();
        }
        if (zigPosText != null) {
            try pointer.append(hackerNewsItems[i].text);
            zigComments.completeOne();
        }
    }
    var set: std.StringArrayHashMap(u64) = std.StringArrayHashMap(u64).init(allocator);
    defer set.deinit();
    var gettingWords = progress.root.start("Analyzing Frequency of words", 0);
    gettingWords.activate();
    for (pointer.items) |item| {
        var titleIterator = std.mem.tokenize(u8, item, " <>");
        while (titleIterator.next()) |val| external: {
            for (stopWords) |stop| {
                if (std.mem.eql(u8, val, stop)) {
                    break :external;
                }
            }
            var v = try set.getOrPut(val);
            if (v.found_existing) {
                v.value_ptr.* = v.value_ptr.* + 1;
            } else {
                v.value_ptr.* = 1;
            }
            gettingWords.completeOne();
        }
    }
    var wordFrequencies: std.ArrayList(WordFrequency) = std.ArrayList(WordFrequency).init(allocator);
    var setIterator = set.iterator();
    while (setIterator.next()) |val| {
        var nice = WordFrequency{ .text = val.key_ptr.*, .frequency = val.value_ptr.* };
        try wordFrequencies.append(nice);
    }
    return wordFrequencies.toOwnedSlice();
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

fn getHackerNewsItem(allocator: std.mem.Allocator, client: *zelda.HttpClient, id: MaxHackerNewsValue) !TextResponse {
    var buffer: [4096]u8 = undefined;
    var response: zelda.request.Response = try client.perform(zelda.request.Request{
        .method = zelda.request.Method.GET,
        .url = try std.fmt.bufPrint(&buffer, "https://hacker-news.firebaseio.com/v0/item/{d}.json", .{id}),
        .use_global_connection_pool = false,
    });
    var body: []u8 = undefined;
    if (response.body) |bod| {
        body = try allocator.dupe(u8, bod);
    } else return error.MissingResponseBody;
    defer allocator.free(body);
    semaphore.wait();
    response.deinit();
    semaphore.post();

    var textResponse: TextResponse = try std.json.parse(TextResponse, &std.json.TokenStream.init(body), .{ .allocator = allocator });
    defer std.json.parseFree(TextResponse, textResponse, .{ .allocator = allocator });

    return textResponse;
}

fn saveItems(allocator: std.mem.Allocator, slice: []TextResponse, start: usize, end: usize) !void {
    var client: *zelda.HttpClient = try zelda.HttpClient.init(allocator, .{ .userAgent = "zig-relevance-cloud/0.0.1" }); // Client per thread
    defer client.deinit();
    var index: usize = end;
    var retry_attempts: u8 = 0;
    while (index > start) {
        progress.root.activate();
        slice[index - 1] = getHackerNewsItem(allocator, client, index) catch blk: {
            // TODO: handle correctly errors
            if (retry_attempts >= 3) {
                retry_attempts += 1;
                // Maybe a sleep here
                // std.time.sleep(5000000000);
                continue;
            }
            break :blk TextResponse{ .text = "", .title = "" };
        };
        index -= 1;
        retry_attempts = 0;
        progress.root.completeOne();
    }
}

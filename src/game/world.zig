const level = @import("level.zig");

pub const World = struct {
    currentLevel: level.Level,

    pub fn init() !@This() {
        return World{
            .currentLevel = try level.Level.init(),
        };
    }
};

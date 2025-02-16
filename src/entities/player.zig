pub const Player = struct {
    x: i32,
    y: i32,
    speed: i32,

    pub fn init() Player {
        return Player{
            .x = 2,
            .y = 3,
            .speed = 1, //TODO: speed is going to be relative to te player, player always 1
        };
    }
};

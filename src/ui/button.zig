const c = @cImport({
    @cInclude("raylib.h");
});
pub const Button = struct {
    pos: c.Vector2,
    height: i32,
    width: i32,

    pub fn init(pos: c.Vector2, height: i32, width: i32) Button {
        //TODO: make some default values for easy instancing
        return Button{
            .pos = pos,
            .height = height,
            .width = width,
        };
    }
};

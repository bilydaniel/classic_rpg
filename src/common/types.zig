pub const Vector2Int = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Vector2Int {
        return Vector2Int{
            .x = x,
            .y = y,
        };
    }
};

pub fn vector2IntCompare(a: Vector2Int, b: Vector2Int) bool {
    return a.x == b.x and a.y == b.y;
}

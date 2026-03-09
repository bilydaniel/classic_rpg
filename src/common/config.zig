pub const game_width: i32 = 640 * 3;
pub const game_height: i32 = 360 * 3;

pub const game_width_half: f32 = game_width / 2;
pub const game_height_half: f32 = game_height / 2;

pub var window_width: i32 = game_width * 1;
pub var window_height: i32 = game_height * 1;

pub const camera_zoom: f32 = 4;
pub const camera_zoom_min: f32 = 1;
pub const camera_zoom_max: f32 = 5;
pub const camera_zoom_step: f32 = 0.25;

pub const level_width: i32 = 80;
pub const level_height: i32 = 25;

pub const mouse_mode: bool = false;
pub const turn_speed: f32 = 0.1;

pub const ascii_mode: bool = false;

pub const tile_width: i32 = 12;
pub const tile_height: i32 = 12;

pub const tileset_width_pixels = 2678;
pub const tileset_height_pixels = 650;
pub const tileset_margin = 1;
pub const tileset_stride = tile_width + tileset_margin;

pub const tileset_width = tileset_width_pixels / (tileset_stride); // 2678 / 13
pub const tileset_height = tileset_height_pixels / (tile_height + tileset_margin); // 650 / 13

pub const movement_animation_duration: f32 = 0.2;
pub const movement_animation_duration_in_combat: f32 = 0.4;

pub var drawPathDebug: bool = true;

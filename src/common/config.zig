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

pub const tile_width: i32 = if (!ascii_mode) 12 else 16;
pub const tile_height: i32 = if (!ascii_mode) 12 else 24;

pub const tileset_width = 25;

pub const movement_animation_duration: f32 = 0.4;

pub var drawPathDebug: bool = true;

#version 330 core

in vec2 fragTexCoord;
out vec4 fragColor;

uniform sampler2D texture0;
uniform vec2 resolution;
uniform float time;

const float CURVATURE = 0.12;
const float SCANLINE_DARK = 0.55;
const float SCANLINE_COUNT = 480.0;
const float MASK_STRENGTH = 0.18;
const float CHROMA_SPREAD = 2.2;
const float BLOOM_RADIUS = 2.8;
const float BLOOM_STRENGTH = 0.25;
const float VIGNETTE_POW = 1.6;
const float VIGNETTE_AMT = 0.75;
const float NOISE_AMOUNT = 0.04;
const float ROLL_SPEED = 0.18;
const float ROLL_STRENGTH = 0.04;
const float WARMUP_DUR = 1.5;
const vec3 PHOSPHOR_TINT = vec3(1.02, 1.00, 0.90);

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

vec2 warpUV(vec2 uv) {
    vec2 c = uv * 2.0 - 1.0;
    vec2 offset = c.yx * c.yx * CURVATURE;
    c += c * offset;
    return c * 0.5 + 0.5;
}

vec3 chromaticSample(vec2 uv) {
    vec2 dir = uv - 0.5;
    float dist = length(dir);
    vec2 aberr = normalize(dir + vec2(0.0001)) * dist * (CHROMA_SPREAD / resolution);
    float r = texture(texture0, uv + aberr).r;
    float g = texture(texture0, uv).g;
    float b = texture(texture0, uv - aberr).b;
    return vec3(r, g, b);
}

vec3 bloom(vec2 uv) {
    vec3 acc = vec3(0.0);
    float total = 0.0;
    float blurStep = BLOOM_RADIUS / resolution.y;
    for (int xi = -2; xi <= 2; xi++) {
        for (int yi = -2; yi <= 2; yi++) {
            vec2 off = vec2(float(xi), float(yi)) * blurStep;
            float w = 1.0 / (1.0 + float(xi * xi + yi * yi));
            acc += texture(texture0, uv + off).rgb * w;
            total += w;
        }
    }
    return acc / total;
}

float scanline(vec2 uv) {
    float s = sin(uv.y * SCANLINE_COUNT * 3.14159265);
    return mix(1.0, SCANLINE_DARK, s * -0.5 + 0.5);
}

vec3 phosphorMask(vec2 uv, vec3 col) {
    float px = mod(uv.x * resolution.x, 3.0);
    vec3 mask = vec3(0.0);
    if (px < 1.0) mask = vec3(1.0, 0.0, 0.0);
    else if (px < 2.0) mask = vec3(0.0, 1.0, 0.0);
    else mask = vec3(0.0, 0.0, 1.0);
    mask = mix(vec3(1.0), mask + 0.35, MASK_STRENGTH);
    return col * mask;
}

float vignette(vec2 uv) {
    vec2 d = (uv - 0.5) * 2.0;
    float v = 1.0 - dot(d, d) * VIGNETTE_AMT;
    return clamp(pow(v, VIGNETTE_POW), 0.0, 1.0);
}

float rollBar(vec2 uv) {
    float bar = sin((uv.y - time * ROLL_SPEED) * 6.28318 * 4.0);
    bar = pow(bar * 0.5 + 0.5, 12.0);
    return 1.0 + bar * ROLL_STRENGTH;
}

float warmup() {
    if (time >= WARMUP_DUR) return 1.0;
    float t = time / WARMUP_DUR;
    float flicker = sin(time * 80.0) * 0.5 + 0.5;
    return mix(flicker * 0.4, 1.0, smoothstep(0.0, 1.0, t * t));
}

float bezelGlint(vec2 uv) {
    float g = smoothstep(0.00, 0.12, uv.x) * smoothstep(0.00, 0.08, uv.y)
            * smoothstep(0.22, 0.10, uv.x) * smoothstep(0.20, 0.08, uv.y);
    return g * 0.06;
}

float deadPixel(vec2 uv) {
    vec2 grid = floor(uv * resolution / 4.0);
    float seed = hash(grid);
    if (seed > 0.998)
        return sin(time * (3.0 + seed * 17.0)) * 0.5 + 0.5;
    return 0.0;
}

void main() {
    vec2 uv = fragTexCoord;

    vec2 wuv = uv; //warpUV(uv);

    if (wuv.x < 0.0 || wuv.x > 1.0 || wuv.y < 0.0 || wuv.y > 1.0) {
        fragColor = vec4(0.04, 0.04, 0.04, 1.0);
        return;
    }

    vec3 col = chromaticSample(wuv);

    col = mix(col, max(col, bloom(wuv)), BLOOM_STRENGTH);

    col *= PHOSPHOR_TINT;

    col *= scanline(wuv);

    col = phosphorMask(wuv, col);

    col *= rollBar(wuv);

    col += (hash(wuv + fract(time * 0.07)) - 0.5) * NOISE_AMOUNT;

    //col += deadPixel(wuv) * vec3(1.0, 0.9, 0.5) * 0.9;

    col *= vignette(wuv);

    //col += bezelGlint(wuv);

    col *= warmup();

    col = pow(max(col, 0.0), vec3(1.0 / 2.5));

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

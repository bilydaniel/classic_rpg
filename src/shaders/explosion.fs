#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform float time;
uniform vec2 resolution;

// Simple noise function
float noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main()
{
    vec2 uv = fragTexCoord * 2.0 - 1.0;
    float dist = length(uv);

    // Expanding explosion wave
    float expansion = time * 1.5;
    float wave = 1.0 - abs(dist - expansion);
    wave = smoothstep(0.0, 0.3, wave) * smoothstep(1.0, 0.5, expansion);

    // Fire-like turbulence
    vec2 noiseUV = uv * 5.0 + time * 2.0;
    float n = noise(noiseUV);
    n += noise(noiseUV * 2.0) * 0.5;
    n += noise(noiseUV * 4.0) * 0.25;
    n /= 1.75;

    // Radial flames
    float angle = atan(uv.y, uv.x);
    float flames = sin(angle * 6.0 + time * 10.0 + n * 3.0) * 0.5 + 0.5;
    flames = pow(flames, 2.0);

    // Inner glow
    float glow = 1.0 - smoothstep(0.0, expansion, dist);
    glow *= 1.0 - time * 0.7;

    // Outer smoke
    float smoke = smoothstep(expansion * 0.8, expansion * 1.2, dist);
    smoke *= (1.0 - smoothstep(expansion * 1.2, expansion * 1.5, dist));
    smoke *= n * (1.0 - time * 0.5);

    // Color gradient: white -> yellow -> orange -> red -> dark
    vec3 color;
    if (glow > 0.5) {
        color = mix(vec3(1.0, 1.0, 0.5), vec3(1.0, 1.0, 1.0), (glow - 0.5) * 2.0);
    } else if (glow > 0.2) {
        color = mix(vec3(1.0, 0.5, 0.0), vec3(1.0, 1.0, 0.5), (glow - 0.2) / 0.3);
    } else {
        color = mix(vec3(0.5, 0.1, 0.0), vec3(1.0, 0.5, 0.0), glow / 0.2);
    }

    // Add smoke tint
    color = mix(color, vec3(0.2, 0.2, 0.2), smoke * 0.5);

    // Combine all effects
    float alpha = wave + glow * 0.7 + flames * wave * 0.3 + smoke * 0.4;
    alpha *= (1.0 - time * 0.8);

    finalColor = vec4(color, alpha);
}

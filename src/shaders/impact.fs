#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform float time;
uniform vec2 resolution;

void main()
{
    // Center the coordinates
    vec2 uv = fragTexCoord * 2.0 - 1.0;
    float dist = length(uv);

    // Discard pixels outside circular explosion area
    if (dist > 1.0) discard;

    // Expanding ring
    float ring = abs(dist - time * 2.0);
    ring = 1.0 - smoothstep(0.0, 0.1, ring);

    // Flash at center
    float flash = 1.0 - smoothstep(0.0, 0.5, dist);
    flash *= 1.0 - time;

    // Radial distortion lines
    float angle = atan(uv.y, uv.x);
    float rays = abs(sin(angle * 8.0 + time * 5.0));
    rays = pow(rays, 3.0) * (1.0 - dist);

    // Color - orange to yellow to white
    vec3 color = vec3(1.0, 0.5, 0.0);
    color = mix(color, vec3(1.0, 1.0, 0.5), flash);
    color = mix(color, vec3(1.0, 1.0, 1.0), rays * 0.5);

    // Combine effects
    float alpha = (ring + flash * 0.5 + rays * 0.3) * (1.0 - time);

    finalColor = vec4(color, alpha);
}

#version 330

// Input from vertex shader
in vec2 fragTexCoord;
in vec4 fragColor;

// Output
out vec4 finalColor;

// Uniforms
uniform float time;
uniform vec2 resolution;

void main()
{
    vec2 uv = fragTexCoord;

    // Create a slash trail effect
    float trail = smoothstep(0.0, 0.3, time) * smoothstep(1.0, 0.7, time);

    // Vertical gradient for the slash
    float slashGradient = 1.0 - abs(uv.y - 0.5) * 2.0;
    slashGradient = pow(slashGradient, 3.0);

    // Horizontal fade
    float horizontalFade = smoothstep(0.0, 0.1, uv.x) * smoothstep(1.0, 0.9 - time * 0.5, uv.x);

    // Color - white hot center to red edges
    vec3 color = mix(vec3(1.0, 0.2, 0.2), vec3(1.0, 1.0, 1.0), slashGradient);

    // Combine effects
    float alpha = slashGradient * horizontalFade * trail;

    // Add some shimmer
    float shimmer = sin(uv.x * 20.0 + time * 15.0) * 0.2 + 0.8;
    alpha *= shimmer;

    finalColor = vec4(color, alpha);
}

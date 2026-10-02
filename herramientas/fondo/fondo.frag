#version 440
// Los fondos animados de Ágape (ui/js/theme.js, WALLPAPER_FX), los mismos sombreadores pasados a Qt: ruido fractal que se
// deforma despacio con los tonos del tema Berenjena. «kind»: 0 Tinta, 1 Humo, 2 Seda, 3 Mármol, 4 Relieve, 5 Remolino,
// 6 Dunas, 7 Luces (de Apogeo). Se compila con qsb al construir el paquete (herramientas/fondo.sh).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float t;
    float kind;
    float light;
    vec2 res;
    vec4 base;
    vec4 c1;
    vec4 c2;
    vec4 c3;
};

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 6; i++) { v += a * noise(p); p = p * 2.02 + vec2(1.7, 9.2); a *= 0.5; }
    return v;
}
vec3 finish(vec3 col, float f, vec2 px) {
    col *= light > 0.5 ? (0.9 + 0.2 * f) : (0.55 + 0.6 * f);
    return col + (hash(px + fract(t)) - 0.5) / 255.0; // tramado contra escalones
}

void main() {
    vec2 uv = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y);   // como gl_FragCoord / res en Ágape (origen abajo)
    vec2 px = uv * res;
    vec2 asp = vec2(res.x / res.y, 1.0);
    float k1 = light > 0.5 ? 1.0 : 1.3;
    float k2 = light > 0.5 ? 1.0 : 1.2;
    vec3 b = base.rgb, C1 = c1.rgb, C2 = c2.rgb;
    vec3 hi = light > 0.5 ? c3.rgb : c3.rgb * 0.55;
    vec3 col;
    float f;
    int k = int(kind + 0.5);
    if (k == 1) {            // Humo
        vec2 p = uv * asp * vec2(2.0, 1.4); float s = t * 0.05;
        vec2 fl = vec2(s * 0.2, -s * 1.3);
        vec2 q = vec2(fbm(p + fl), fbm(p + vec2(3.1, 1.7) + fl * 1.3));
        vec2 r = vec2(fbm(p + 2.2 * q + vec2(1.7, 9.2) + fl * 1.5), fbm(p + 2.2 * q + vec2(8.3, 2.8) + fl));
        f = fbm(p + 2.4 * r);
        float strand = pow(0.5 + 0.5 * sin(f * 16.0 + r.x * 5.0), 7.0);
        col = mix(b, C1 * k1, smoothstep(0.2, 0.9, f));
        col = mix(col, C2 * k2, smoothstep(0.5, 1.05, length(r)) * 0.55);
        col = mix(col, hi * 1.25, strand * smoothstep(0.35, 0.85, f) * 0.55);
    } else if (k == 2) {     // Seda
        vec2 p = uv * asp * 2.6; float s = t * 0.045;
        float w = fbm(p * 0.55 + vec2(s, -s * 0.6));
        float a = sin(p.y * 3.6 + p.x * 1.4 + w * 6.5 + s * 2.2);
        float bb = sin(p.x * 2.6 - p.y * 1.2 + w * 3.8 - s * 1.4);
        float v = (a + 0.5 * bb) / 1.5;
        float shade = 0.5 + 0.5 * v;
        float spec = pow(shade, 14.0);
        col = mix(b, C1 * k1, smoothstep(0.1, 0.7, shade));
        col = mix(col, C2 * k2, smoothstep(0.5, 0.95, shade) * 0.8);
        col = mix(col, hi * 1.5, spec * 0.7);
        f = 0.3 + 0.6 * shade;
    } else if (k == 3) {     // Mármol
        vec2 p = uv * asp * 2.0; float s = t * 0.035;
        vec2 q = vec2(fbm(p + s), fbm(p + vec2(4.0, 2.0) - s));
        float cloud = fbm(p * 1.4 + q * 1.5);
        float v = sin(p.x * 1.6 + p.y * 1.1 + 6.0 * fbm(p + 2.2 * q));
        float vein = pow(1.0 - abs(v), 14.0);
        float vein2 = pow(1.0 - abs(sin(p.x * 3.1 - p.y * 2.0 + 5.0 * q.y)), 26.0);
        col = mix(b, C1 * k1, smoothstep(0.2, 0.85, cloud));
        col = mix(col, C2 * k2, smoothstep(0.55, 0.95, cloud) * 0.5);
        col = mix(col, hi * 1.3, vein * 0.7 + vein2 * 0.3);
        f = cloud;
    } else if (k == 4) {     // Relieve
        vec2 p = uv * asp * 1.8; float s = t * 0.04;
        vec2 q = vec2(fbm(p + vec2(s, 0.0)), fbm(p + vec2(2.3, 7.1) - vec2(0.0, s)));
        float hgt = fbm(p + 1.6 * q);
        float bands = hgt * 16.0;
        float d = abs(fract(bands) - 0.5);
        float line = 1.0 - smoothstep(0.0, fwidth(bands) * 1.4, 0.5 - d);
        col = mix(b, C1 * k1, smoothstep(0.25, 0.85, hgt));
        col = mix(col, C2 * k2, smoothstep(0.6, 0.95, hgt) * 0.6);
        col = mix(col, hi * 1.3, line * (0.25 + 0.5 * smoothstep(0.35, 0.9, hgt)));
        f = hgt;
    } else if (k == 5) {     // Remolino
        vec2 c = (uv - 0.5) * asp; float s = t * 0.05;
        float r = length(c);
        float ang = atan(c.y, c.x) + 1.8 / (r + 0.35) + s;
        vec2 sp = vec2(cos(ang), sin(ang)) * r * 3.2;
        f = fbm(sp + fbm(sp * 1.3 + s) * 1.5);
        float band = 0.5 + 0.5 * sin(f * 9.0 + r * 5.0 - s * 2.0);
        col = mix(b, C1 * k1, smoothstep(0.2, 0.85, f));
        col = mix(col, C2 * k2, band * 0.55);
        col = mix(col, hi * 1.3, smoothstep(0.82, 1.0, band) * smoothstep(0.35, 0.8, f) * 0.6);
        col *= 1.0 - 0.35 * smoothstep(0.3, 1.1, r);
    } else if (k == 6) {     // Dunas
        vec2 p = uv * asp * 2.4; float s = t * 0.04;
        float warp = fbm(p * 0.8 + vec2(s * 0.5, 0.0)) + 0.5 * fbm(p * 1.7 - vec2(0.0, s * 0.3));
        float ph = (p.x * 0.9 + p.y * 2.2) * 5.0 + warp * 9.0 - s * 3.0;
        float ridge = pow(0.5 + 0.5 * sin(ph), 2.2);
        float fine = 0.5 + 0.5 * sin(ph * 3.3 + warp * 4.0);
        float lit = ridge * (0.85 + 0.15 * fine);
        float big = fbm(p * 0.5 - s * 0.2);
        col = mix(b, C1 * k1, smoothstep(0.2, 0.8, big));
        col = mix(col, C2 * k2, lit * 0.55);
        col = mix(col, hi * 1.3, pow(lit, 8.0) * 0.4);
        f = 0.3 + 0.4 * lit + 0.3 * big;
    } else if (k == 7) {     // Luces: círculos de luz desenfocados que flotan despacio (el de Jugar)
        vec2 p = uv * asp; float s = t * 0.05;
        col = mix(b, C1 * 0.9, smoothstep(0.0, 1.0, uv.y) * 0.6);
        f = 0.5;
        for (int i = 0; i < 14; i++) {
            float fi = float(i);
            vec2 c = vec2(fract(hash(vec2(fi, 1.0)) + s * (0.05 + 0.08 * hash(vec2(fi, 2.0)))) * asp.x,
                          fract(hash(vec2(fi, 3.0)) + 0.05 * sin(s * 3.0 + fi)));
            float r = 0.05 + 0.11 * hash(vec2(fi, 4.0));
            float blob = smoothstep(r, r * 0.6, length(p - c)) * (0.25 + 0.35 * hash(vec2(fi, 5.0)));
            col += (hash(vec2(fi, 6.0)) > 0.5 ? C2 * k2 : hi * 1.3) * blob;
        }
    } else {                 // Tinta
        vec2 p = uv * asp * 2.5; float s = t * 0.06;
        vec2 q = vec2(fbm(p + s), fbm(p + vec2(5.2, 1.3) - s));
        vec2 r = vec2(fbm(p + 3.0 * q + vec2(1.7, 9.2) + s * 1.5), fbm(p + 3.0 * q + vec2(8.3, 2.8) - s * 1.2));
        f = fbm(p + 3.0 * r);
        col = mix(b, C1 * k1, smoothstep(0.2, 0.9, f));
        col = mix(col, C2 * k2, smoothstep(0.45, 1.0, length(q)) * 0.8);
        col = mix(col, hi, smoothstep(0.72, 1.0, r.x) * 0.45);
    }
    fragColor = vec4(finish(col, f, px), 1.0) * qt_Opacity;
}

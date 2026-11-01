#version 440
// Los fondos animados de Órbita, uno por modo: ruido fractal y luz que se mueven despacio con los colores del modo.
// «kind»: 0 Órbitas (Navegar), 1 Nebulosa (Jugar), 2 Aurora (Estudiar). Se compila con qsb al construir el paquete.
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
// Estrellas quietas que titilan muy despacio (una por celda, pocas)
float stars(vec2 p, float dens) {
    vec2 cell = floor(p * dens);
    float h = hash(cell);
    float on = step(0.985, h);
    vec2 c = fract(p * dens) - 0.5 - 0.3 * (vec2(hash(cell + 7.1), hash(cell + 3.7)) - 0.5);
    return on * smoothstep(0.32, 0.0, length(c)) * (0.55 + 0.45 * sin(t * (0.4 + h) + h * 40.0));
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
    if (k == 0) {     // Órbitas: el orbe, abajo en el centro, y sus órbitas abiertas girando, cada una con su nodo
        vec2 c = (uv - vec2(0.5, 0.02)) * asp; float s = t * 0.03;
        float r = length(c);
        col = mix(b, C1 * k1, smoothstep(1.35, 0.0, r) * 0.75);
        col = mix(col, C2 * k2, smoothstep(1.1, 0.0, r) * 0.35);
        float n = fbm(c * 1.5 + vec2(s * 0.6, -s * 0.3));
        col = mix(col, C2 * k2, smoothstep(0.5, 0.95, n) * 0.4);
        col += hi * 0.3 * exp(-r * 4.0);
        for (int i = 0; i < 5; i++) {
            float fi = float(i);
            float rx = 0.34 + fi * 0.27, ry = rx * 0.46;
            float ang = (fi - 2.0) * 0.045 + 0.05 * sin(s * 0.8 + fi * 1.3);
            vec2 q = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * c;
            vec2 e = q / vec2(rx, ry);
            float d = abs(length(e) - 1.0) * ry;
            float line = smoothstep(0.0045, 0.0, d);
            float head = mod(s * (1.3 - fi * 0.18) * (mod(fi, 2.0) < 0.5 ? 1.0 : -1.0) + fi * 1.9, 6.28318);
            float a = atan(e.y, e.x);
            float trail = mod((mod(fi, 2.0) < 0.5 ? 1.0 : -1.0) * (head - a), 6.28318);
            float tail = exp(-trail * 0.75);
            float w = 0.55 - fi * 0.08;
            col += hi * 1.5 * line * (0.12 + 0.88 * tail) * w;
            vec2 np = vec2(cos(head), sin(head)) * vec2(rx, ry);
            float nd = length(q - np);
            col += hi * 1.8 * (smoothstep(0.014, 0.0, nd) + 0.4 * exp(-nd * 26.0)) * w;
        }
        col += vec3(0.9, 0.93, 1.0) * stars(uv * asp, 90.0) * 0.45;
        f = 0.75;
    } else if (k == 1) {     // Nebulosa: una nube del color del modo que se deforma despacio y ondas que salen del orbe
        vec2 p = uv * asp * 1.7; float s = t * 0.03;
        vec2 q = vec2(fbm(p + vec2(s, s * 0.4)), fbm(p + vec2(5.2, 1.3) - s * 0.7));
        float n = fbm(p + 2.1 * q + vec2(s * 0.5, 0.0));
        col = mix(b, C1 * k1, smoothstep(0.32, 0.95, n) * 0.95);
        col = mix(col, C2 * k2, smoothstep(0.5, 1.0, n * (0.6 + length(q))) * 0.7);
        col = mix(col, hi * 0.75, smoothstep(0.55, 1.0, n) * 0.5);
        col += hi * 0.55 * pow(smoothstep(0.62, 1.0, n), 3.0);
        vec2 c = (uv - vec2(0.5, -0.04)) * asp;
        float r = length(c);
        for (int j = 0; j < 3; j++) {
            float rr = fract(t * 0.035 + float(j) / 3.0) * 1.8;
            col += hi * 0.22 * exp(-abs(r - rr) * 55.0) * (1.0 - rr / 1.8);
        }
        col += vec3(0.95, 0.92, 1.0) * stars(uv * asp + vec2(s * 0.05, 0.0), 80.0) * 0.5;
        f = 0.45 + 0.5 * n;
    } else {                 // Aurora: cortinas de luz cálida que se mecen muy despacio, sobre papel o grafito
        vec2 p = uv * asp; float s = t * 0.022;
        float w = fbm(vec2(p.x * 1.1 + s, s * 0.6));
        float y0 = 0.56 + 0.16 * sin(p.x * 1.3 + w * 3.2 + s * 2.0);
        float band = exp(-pow((uv.y - y0) * 3.0, 2.0)) * smoothstep(y0 - 0.32, y0, uv.y);
        float rays = 0.55 + 0.45 * fbm(vec2(p.x * 8.0 + w * 5.0, s * 1.5));
        bool paper = light > 0.5;
        vec3 veil = mix(C2 * k2, c3.rgb, paper ? 0.5 : 0.6);
        col = mix(b, C1 * k1, smoothstep(0.0, 1.0, uv.y) * 0.35);
        col = mix(col, veil, band * rays * (paper ? 0.2 : 0.65));
        col = mix(col, paper ? c3.rgb : c3.rgb * 1.1, band * pow(rays, 4.0) * (paper ? 0.1 : 0.4));
        float y1 = 0.28 + 0.08 * sin(p.x * 2.0 - s * 1.6 + w * 2.0);
        col = mix(col, veil, exp(-pow((uv.y - y1) * 6.0, 2.0)) * (paper ? 0.08 : 0.2));
        col *= 0.975 + 0.05 * noise(px * 0.9);        // grano de papel
        f = paper ? 0.5 : 0.55 + 0.35 * band;
    }
    fragColor = vec4(finish(col, f, px), 1.0) * qt_Opacity;
}

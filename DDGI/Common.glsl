#define PI 3.14159265357
#define PHI 1.61803398875
#define EPI 0.0001

// --- 基础 SDF 函数 ---
float sdSphere(vec3 p, float s) { return length(p) - s; }
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdQuad(vec3 p, vec2 e)
{
    vec2 d = abs(p.xy) - e;
    float s = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
    return length(vec2(max(s, 0.0), p.z));
}

// --- 变换 ---
vec2 rot2(vec2 p, float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c) * p;
}

vec3 rotateX(vec3 p, float a) {
    p.yz = rot2(p.yz, a);
    return p;
}

vec3 rotateY(vec3 p, float a) {
    p.xz = rot2(p.xz, a);
    return p;
}

vec3 rotateZ(vec3 p, float a) {
    p.xy = rot2(p.xy, a);
    return p;
}

vec3 translate(vec3 p, vec3 t) {
    return p - t;
}

// --- 布尔运算 ---
vec2 opU(vec2 d1, vec2 d2) {
    return (d1.x < d2.x) ? d1 : d2;
}

// --- Math ---

vec2 octEncode(vec3 n) {
    // 投影到 L1 范数平面: |x| + |y| + |z| = 1
    n /= (abs(n.x) + abs(n.y) + abs(n.z));
    
    // 如果在下半球 (z < 0)，需要进行特殊的边缘翻转（Wrap）
    if (n.z < 0.0) {
        return (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    }
    return n.xy;
}

/**
 * e : [-1, 1]
 */
vec3 octDecode(vec2 e) {
    vec3 v = vec3(e.xy, 1.0 - abs(e.x) - abs(e.y));
    if (v.z < 0.0) {
        v.xy = (1.0 - abs(v.yx)) * vec2(v.x >= 0.0 ? 1.0 : -1.0, v.y >= 0.0 ? 1.0 : -1.0);
    }
    return normalize(v);
}

/**
 * theta: [0, 2*PI]
 * phi: [0, PI]
 */
vec3 sphereToVector(vec2 lonLat) {
    float theta = lonLat.x;
    float phi = lonLat.y;
    return vec3(
        sin(phi) * cos(theta),
        cos(phi),
        sin(phi) * sin(theta)
    );
}

vec2 vectorToSphere(vec3 n) {
    float phi = acos(clamp(n.y, -1.0, 1.0));
    float theta = atan(n.z, n.x);
    return vec2(theta, phi);
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);
}

mat3 getRandomRotation(vec3 seed) {
    vec3 rand = hash33(seed);
    float theta = rand.x * PI * 2.0;
    float z = rand.y * 2.0 - 1.0;
    float r = sqrt(1.0 - z * z);
    vec3 axis = vec3(r * cos(theta), r * sin(theta), z);
    
    float angle = rand.z * PI * 2.0;
    
    float c = cos(angle);
    float s = sin(angle);
    float t = 1.0 - c;
    
    return mat3(
        t*axis.x*axis.x + c,      t*axis.x*axis.y - s*axis.z, t*axis.x*axis.z + s*axis.y,
        t*axis.x*axis.y + s*axis.z, t*axis.y*axis.y + c,      t*axis.y*axis.z - s*axis.x,
        t*axis.x*axis.z - s*axis.y, t*axis.y*axis.z + s*axis.x, t*axis.z*axis.z + c
    );
}

vec3 sphericalFibonacci(float i, float n) {
    float theta = 2.0 * PI * i / PHI;
    float y = 1.0 - (i + 0.5) * (2.0 / n);
    float radius = sqrt(max(0.0, 1.0 - y * y));
    
    return vec3(
        cos(theta) * radius,
        y,
        sin(theta) * radius
    );
}

// --- PBR ---
float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return num / denom;
}


float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return num / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// --- Scene ---
//Texture
#define MAT_FLOOR 1.0
#define MAT_WALL_RED 2.0
#define MAT_WALL_GREEN 3.0
#define MAT_WALL_WHITE 4.0
#define MAT_GOLD 5.0
#define MAT_PLASTIC 6.0
vec2 map(vec3 p) {
    vec3 center = vec3(278, 273, 0);
    //ref
    //vec2 res = vec2(sdSphere(center-p, 50.0), MAT_GOLD);
    vec2 res = vec2(10000.0,-1);
    // 1. BACKWALL
    res = opU(res, vec2(sdQuad(rotateX(translate(p, vec3(278,273,279.6)), .0), vec2(279.6,278)), MAT_FLOOR));
    // 2. CELLING
    res = opU(res, vec2(sdQuad(rotateX(translate(p, vec3(278,546,0)), PI/2.0), vec2(279.6,278)), MAT_FLOOR));
    // 3. 地面 (MAT_FLOOR)
    res = opU(res, vec2(sdQuad(rotateX(translate(p, vec3(278,0,0)), PI/2.0), vec2(279.6,278)), MAT_FLOOR));
    // 4. 左墙
    res = opU(res, vec2(sdQuad(rotateY(translate(p, vec3(0,273,0)), PI/2.0), vec2(279.6,278)), MAT_WALL_RED));
    // 5. 右墙
    res = opU(res, vec2(sdQuad(rotateY(translate(p, vec3(556,273,0)), PI/2.0), vec2(279.6,278)), MAT_WALL_GREEN));
    return res;
}

//Light
vec3 lightPos = vec3(278,545,0);
float intensity = 50000.0;
float PointLight(vec3 p, vec3 lightPos, float intensity)
{
    float dis = length(p-lightPos);
    return intensity / max(EPI, dis * dis);
}

vec4 radiance()
{
    return vec4(1.0);
}

//Raycast
#define MAX_DIST 5000.0
#define SHADOW_BIAS 0.001
vec2 raycast(vec3 ro, vec3 rd) {
    float t = EPI;
    float m = -1.0;
    for(int i = 0; i < 128; i++) {
        vec2 h = map(ro + t * rd);
        if(h.x < 0.001 || t > MAX_DIST) break;
        m = h.y;
        t += h.x;
    }
    if(t > MAX_DIST) m = -1.0;
    return vec2(t - EPI, m);
}

vec3 calcNormal(vec3 p) {
    const float h = 0.0001;
    const vec2 k = vec2(1, -1);
    return normalize(k.xyy * map(p + k.xyy * h).x +
                     k.yyx * map(p + k.yyx * h).x +
                     k.yxy * map(p + k.yxy * h).x +
                     k.xxx * map(p + k.xxx * h).x);
}

// 根据 ID 获取材质属性
vec3 getAlbedo(float m, vec3 p) {
    if(m < 1.5) return vec3(1.0,1.0,1.0);
    if(m < 2.5) return vec4(0.7, 0.1, 0.1, 1.0).rgb; // RED WALL
    if(m < 3.5) return vec4(0.1, 0.7, 0.1, 1.0).rgb; // GREEN WALL
    if(m < 4.5) return vec3(0.7);                   // WHITE WALL
    if(m < 5.5) return vec3(1.0, 0.8, 0.3);         // GOLD
    if(m < 6.5) return vec3(0.1, 0.4, 0.8);         // PLASTIC
    return vec3(0.5);
}

// --- Probe ---

#define PROBE_RESOLUTION 4
#define RAY_PER_PROBE 128

vec3 GetProbePosition(int index, int resolution) {
    int res2 = resolution * resolution;
    int z = index / res2;
    int rem = index - z * res2;
    int y = rem / resolution;
    int x = rem - y * resolution;
    float denom = max(float(resolution - 1), 1.0);
    return (vec3(float(x), float(y), float(z)) / denom - vec3(0.5)) * 500.0 + vec3(278, 273, 0);
}
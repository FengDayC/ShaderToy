#include "Common.glsl"

vec3 render(vec3 ro, vec3 rd)
{
    // 追踪射线
    vec2 res = raycast(ro, rd);
    float t = res.x;
    float m = res.y;

    vec3 col = vec3(.0,.0,.0);

    if(m > 0.0) {
        vec3 p = ro + t * rd;
        vec3 n = calcNormal(p);
        vec3 alb = getAlbedo(m, p);
        
        vec3 lightDir = lightPos - p;
        vec2 shadowRes = raycast(p + n * SHADOW_BIAS, normalize(lightDir));
        bool shadow = shadowRes.x < length(lightDir);
        float radiance = shadow ? .0 : PointLight(p, lightPos, intensity);
        
        col = alb * radiance;
    }
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // 归一化坐标 [-1, 1]
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    int totalProbes = PROBE_RESOLUTION * PROBE_RESOLUTION * PROBE_RESOLUTION;
    
    int probeID = int(fragCoord.y);
    int RayID = int(fragCoord.x);
    if(probeID >= totalProbes || RayID >= RAY_PER_PROBE) {
        fragColor = vec4(0.0);
        return;
    }

    vec3 probePos = GetProbePosition(probeID, PROBE_RESOLUTION);
    mat3 rot = getRandomRotation(vec3(uv, float(iFrame)));
    vec3 rayDir = sphericalFibonacci(float(RayID), float(RAY_PER_PROBE));

    vec3 col = render(probePos, rot * rayDir);

    fragColor = vec4(col, 1.0);
}
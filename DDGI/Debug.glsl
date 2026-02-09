#include "Common.glsl"
#iChannel0 "ProbeUpdate.glsl"

vec2 mapProbes(vec3 p, vec2 res) {
    for(int i = 0; i < 64; i++) {
        res = opU(res, vec2(sdSphere(p - GetProbePosition(i, PROBE_RESOLUTION) , 5.0), MAT_GOLD));
    }
    return res;
}

// 射线步进，返回 vec2(距离, 材质ID)
vec2 raycast2(vec3 ro, vec3 rd) {
    float t = EPI;
    float m = -1.0;
    for(int i = 0; i < 128; i++) {
        vec2 h = map(ro + t * rd);
        h = mapProbes(ro + t * rd, h);
        if(h.x < 0.001 || t > MAX_DIST) break;
        m = h.y;
        t += h.x;
    }
    if(t > MAX_DIST) m = -1.0;
    return vec2(t - EPI, m);
}

vec3 render(vec3 ro, vec3 rd)
{
    // 追踪射线
    vec2 res = raycast2(ro, rd);
    float t = res.x;
    float m = res.y;

    vec3 col = vec3(.0,.0,.0);

    if(m > 0.0) {
        vec3 p = ro + t * rd;
        vec3 n = calcNormal(p);
        vec3 alb = getAlbedo(m, p);
        
        vec3 lightPos = vec3(278,545,0);
        vec3 lightDir = lightPos - p;
        vec2 shadowRes = raycast2(p + n * SHADOW_BIAS, normalize(lightDir));
        bool shadow = shadowRes.x < length(lightDir);
        float radiance = shadow ? .0 : PointLight(p, lightPos, 50000.0);
        
        col = alb * radiance;
    }
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    
    vec3 ro = vec3(278, 273, -1000);
    vec3 cw = vec3(0, 0, 1);
    vec3 cv = vec3(0, 1, 0);
    vec3 cu = normalize(cross(cv, cw));
    vec3 rd = normalize(uv.x * cu + uv.y * cv + cw);

    vec3 col = render(ro,rd);
    fragColor = vec4(col, 1.0);
}
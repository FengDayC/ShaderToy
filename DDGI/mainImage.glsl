#include "Common.glsl"
#iChannel0 "ProbeUpdate.glsl"

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
        
        vec3 lightPos = vec3(278,545,0);
        vec3 lightDir = lightPos - p;
        vec2 shadowRes = raycast(p + n * SHADOW_BIAS, normalize(lightDir));
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
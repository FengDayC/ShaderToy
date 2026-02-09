#include "Common.glsl"
#iChannel0 "RayCast.glsl"

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

// Output : (r,g,b,d) d^2
vec4 GatherProbe(vec3 dir, int probeID, out float sqrDistance)
{
    sqrDistance = 0.0;
    vec4 irradianceDistance = vec4(0.0);
    float sumWeightRadiance = 0.0;
    float sumWeightDistance = 0.0;
    for(int i = 0; i < RAY_PER_PROBE; i++)
    {
        vec4 rayDir = texelFetch(iChannel0, ivec2(probeID, i), 0);
        vec3 radiance = texelFetch(iChannel0, ivec2(probeID + int(iResolution.x / 2.0), i), 0).rgb;
        //irradiance
        float cosWeight = max(.0, dot(dir, rayDir.rgb));
        irradianceDistance.xyz += radiance * cosWeight;
        sumWeightRadiance += cosWeight;
        //distance       
        cosWeight = pow(cosWeight, SHARPNESS);
        irradianceDistance.w += rayDir.w * cosWeight;
        sqrDistance += rayDir.w * rayDir.w * cosWeight;
        sumWeightDistance += cosWeight;
    }
    return vec4(irradianceDistance.xyz / sumWeightRadiance, irradianceDistance.w / sumWeightDistance);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    bool storeIrradiance = fragCoord.x > iResolution.x / 2.0;
    vec2 coord = vec2(storeIrradiance ? fragCoord.x - iResolution.x / 2.0 : fragCoord.x, fragCoord.y);
    vec2 uv = coord / vec2(iResolution.x / 2.0, iResolution.y) * 2.0 - 1.0;
    int probePerRow = int(iResolution.x / 2.0) / PROBE_SIZE;
    int probeID = int(fragCoord.y) / PROBE_SIZE * probePerRow + int(coord.x) / PROBE_SIZE;
    if(probeID >= PROBE_RESOLUTION * PROBE_RESOLUTION * PROBE_RESOLUTION) {
        fragColor = vec4(0.0);
        return;
    }
    vec2 localUV = mod(coord, float(PROBE_SIZE)) / float(PROBE_SIZE) * 2.0 - 1.0;
    vec3 probePos = GetProbePosition(probeID, PROBE_RESOLUTION);
    vec3 dir = octDecode(localUV);

    float sqrDistance;
    vec4 res = GatherProbe(dir, probeID, sqrDistance);
    fragColor = storeIrradiance ? vec4(res.rgb, 1.0) : vec4(res.w, sqrDistance, .0, 1.0);
}
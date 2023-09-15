#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;

uniform float u_Time;
uniform vec4 u_Look;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

float random2(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float random3(vec3 co){
    float x = random2(vec2(co[0], co[1]));
    float y = random2(vec2(co[1], co[2]));
    float z = random2(vec2(co[0], co[2]));

    return random2(vec2(random2(vec2(x, y)), random2(vec2(y, z))));
}

float surflet(vec3 p, vec3 gridPoint) {
    //Compute the distance between p and the grid point along each axis, and warp it with a
    //quintic function so we can smooth our cells
    vec3 t2 = abs(p - gridPoint);
    vec3 t = vec3(1.f, 1.f, 1.f) - 6.f * vec3(pow(t2[0], 5.f), pow(t2[1], 5.f), pow(t2[2], 5.f)) + 15.f *vec3(pow(t2[0], 4.f), pow(t2[1], 4.f), pow(t2[2], 4.f)) - 10.f * vec3(pow(t2[0], 3.f), pow(t2[1], 3.f), pow(t2[2], 3.f));
    // Get the random vector for the grid point (assume we wrote a function random2
    // that returns a vec2 in the range [0, 1])
    vec3 gradient = random3(gridPoint) * 2. - vec3(1.f, 1.f, 1.f);
    // Get the vector from the grid point to P
    vec3 diff = p - gridPoint;
    // Get the value of our height field by dotting grid->P with our gradient
    float height = dot(diff, gradient);
    // Scale our height field (i.e. reduce it) by our polynomial falloff function
    return height * t.x * t.y * t.z;
}

float perlinNoise3D(vec3 p) {
	float surfletSum = 0.f;
	// Iterate over the four integer corners surrounding uv
	for(int dx = 0; dx <= 1; ++dx) {
		for(int dy = 0; dy <= 1; ++dy) {
			for(int dz = 0; dz <= 1; ++dz) {
				surfletSum += surflet(p, floor(p) + vec3(dx, dy, dz));
			}
		}
	}
	return surfletSum;
}

float fbm(vec3 p) {
    float total = 0.f;
    float persistence = 0.5f;
    int octaves = 8;
    float freq = 2.f;
    float amp = 0.5f;
    for(int i = 1; i <= octaves; i++) {
        total += amp;

        total += perlinNoise3D(p * freq) * amp;

        freq *= 2.f;
        amp *= persistence;
    }
    return total;
}

vec3 hash33(vec3 p3) {
	vec3 p = fract(p3 * vec3(.1031,.11369,.13787));
    p += dot(p, p.yxz+19.19);
    return -1.0 + 2.0 * fract(vec3((p.x + p.y)*p.z, (p.x+p.z)*p.y, (p.y+p.z)*p.x));
}

float worley(vec3 p, float scale){
    vec3 id = floor(p*scale);
    vec3 fd = fract(p*scale);

    float n = 0.;

    float minimalDist = 1.;

    for(float x = -1.; x <=1.; x++){
        for(float y = -1.; y <=1.; y++){
            for(float z = -1.; z <=1.; z++){

                vec3 coord = vec3(x,y,z);
                vec3 rId = hash33(mod(id+coord,scale))*0.5+0.5;

                vec3 r = coord + rId - fd; 

                float d = dot(r,r);

                if(d < minimalDist){
                    minimalDist = d;
                }

            }
        }
    }
    return 1.0-minimalDist;
}

float bias (float b, float t) {
    return pow(t, log(b) / log(0.5f));
}

float gain (float g, float t) {
    if (t < 0.5f) {
        return bias(1.f - g, 2.f * t) / 2.f;
    } else {
        return 1.f - bias(1.f - g, 2.f - 2.f * t) / 2.f;
    }
}

// low-frequency, high-amplitude displacement
// combination of sine functions
// y = Asin(B(X + C)) + D
float noise(vec3 vec) {
    float amplitude = 5.0f;
    float freq = 0.2f;
    
    float total = amplitude * sin(freq * sin(fbm(vec.xyz) + 0.5f));//amplitude * sin(freq * input.x);

    //float total = amplitude * sin(freq * bias(sin(worley(vec.xyz, 5.f) + 0.5f), 0.3f));//amplitude * sin(freq * input.x);
    return total;
}

float easeInOutCubic(float x) {
    return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0;
}

void main()
{
    // Material base color (before shading)
        vec4 diffuseColor = u_Color;
        // vec4 vector1 = u_Look; // - [0, 0, 0,] which is origin of icosphere
        // vec4 vector2 = fs_Nor;

        float time = sin(u_Time * 0.08f);
        // float noise = perlinNoise3D(fs_Pos.xyz + 0.1f * time);
        float fbmNoise = fbm(fs_Pos.xyz);
        // diffuseColor += 0.5f * vec4(noise - time, fbmNoise - fbmNoise * noise, fbmNoise, 1.f);

        //vec3 biasedPos = vec3(bias(fs_Pos.x, 0.f), fs_Pos.y, fs_Pos.z);
        float noise = noise(fs_Pos.xyz * 1.5f * sin(u_Time / 1000.f));
        
        diffuseColor += 0.5f * vec4(noise, noise - bias(0.5f * fbmNoise * noise, 0.7f), noise - bias(0.5f * fbmNoise * noise, 0.7f), noise);
        
        // Trying things with angles:
        vec3 colorA = diffuseColor.xyz - vec3(0.7f, 0.7f, 0.7f);
        vec3 colorB = diffuseColor.xyz + vec3(1.f, 1.f, 1.f);
        
        // float dotProd = dot(vector1, vector2) / (length(vector1) * length(vector2));
        float angle = acos(dot(normalize(vec3(fs_Nor)), normalize(vec3(u_Look))));;
        angle /= 6.28f; // PI
        float noisyAngle = easeInOutCubic(0.9f * bias(angle, 0.6f));
        vec3 noisyColor = mix(colorA, colorB, noisyAngle);
        diffuseColor = vec4(noisyColor, 1.f);


        //angle /= 6.28f; // PI


       // diffuseColor -= 100.f * u_Look;

        //diffuseColor -= 100.f * vec4(u_Look[0], u_Look[1], u_Look[2], 0.f);
        // if (angle < 0.25f) {
        //     diffuseColor = vec4(colorB[0], colorB[1], colorB[2], diffuseColor[3]);
        // }

        // colorB = colorA * multiplier -- multiplier is random value (procedurally darker color)
        // weight --> btwn 0 and 1
        // weight = bias(weight, (predetermined factor like 0.6 to lean toward b))
        // can make angle a single scalar
            // calculate max angle and then divide by max angle
        // manipulate 
        // converting 3d value into a single value --> multiply all 3 values, or find magnitude
            // add them all up, minus them all up
       // vec3 interpColor = mix(colorA, colorB, weight)
        // saturation -  for darker
        // bias would make middle bigger relative to outside
        // check: bias for 0.5 upwards, bias below 0.5 downwards
        //interpolated_color = mix(colorA, colorB, weight) ; weight is a product of noise. Middle to always to be lighter: One part of weight needs to be angle between camera and sphere
        // weight is between 0 and 1

        //diffuseColor += 0.5f * vec4(noise - time * noise, 0.f, 0.f, 0.f);

        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        // diffuseTerm = clamp(diffuseTerm, 0, 1);

        float ambientTerm = 0.9;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.

        // Compute final shaded color
        out_Col = vec4(diffuseColor.rgb, diffuseColor.a);
}

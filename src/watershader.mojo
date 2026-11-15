from std.ffi import OwnedDLHandle, c_int, c_uint, c_float
from std.sys import is_defined
from std.memory import Pointer
from raymath import Vec4f
from rlgl import (
    RLGL,
    CharPtr,
    CharPtrPtr,
    IntPtr,
    FloatPtr,
    VoidPtr,
    FLOATS_PER_VERTEX,
    GL_VERTEX_SHADER,
    GL_FRAGMENT_SHADER,
    GL_ARRAY_BUFFER,
    GL_TRIANGLES,
)

struct WaterShader(TrivialRegisterPassable):
    var program: c_uint
    var mvp_loc: c_int
    var time_loc: c_int
    var res_loc: c_int
    var shake_loc: c_int

    def __init__(out self, gl: OwnedDLHandle) raises:
        var header: String = "#version 300 es\nprecision highp float;\n" if is_defined["WASM"]() else "#version 460 core\n"

        var vs_src: String = header + """layout (location = 0) in vec3 aPos;
layout (location = 1) in vec4 aColor;
layout (location = 2) in vec2 aUV;
layout (location = 3) in vec3 aNormal;
out vec2 vUV;
uniform mat4 uMVP;
void main() {
    gl_Position = uMVP * vec4(aPos, 1.0);
    vUV = aUV;
}\x00"""

        var fs_src: String = header + """in vec2 vUV;
out vec4 FragColor;
uniform float uTime;
uniform vec2 uResolution;
uniform vec2 uShake;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float randomSparkles(vec2 p, float t) {
    vec2 cell = floor(p);
    vec2 local = fract(p);
    vec2 rnd = hash2(cell);
    if (rnd.x <= 0.65) return 0.0;
    vec2 pos = 0.15 + 0.70 * rnd;
    pos.y += sin(t * 1.6 + rnd.y * 6.2831) * 0.12;
    vec2 d = local - pos;
    d.x *= 0.65;
    float pulse = sin(t * (2.2 + rnd.x * 2.5) + rnd.y * 12.0) * 0.5 + 0.5;
    float radius = mix(0.03, 0.11, pulse);
    return step(dot(d, d), radius * radius) * step(0.45, pulse);
}

void main() {
    vec2 uv = (vUV * uResolution - uShake) / uResolution.y;
    vec2 p = uv * 11.5;

    float n1 = noise(p * 0.35 + vec2(uTime * 0.06, -uTime * 0.04));
    float n2 = noise(p * 0.75 + vec2(-uTime * 0.05, uTime * 0.07) + 4.3);
    vec2 warp = vec2(n1 - 0.5, n2 - 0.5) * 2.4;

    float bobY = sin(p.x * 0.7 + n1 * 4.0 + uTime * 1.4) * 0.25;
    vec2 wp = p + warp + vec2(0.0, bobY);

    float swell = mix(n1, n2, 0.45) + sin(wp.y * 1.1 + wp.x * 0.35) * 0.14;
    float band1 = step(0.46, swell);
    float band2 = step(0.68, swell);

    float curlLine = sin(wp.y * 3.4 + noise(wp * 0.9) * 3.2);
    float sparsePatch = noise(p * 0.65 + vec2(1.9, 8.2));
    float dashBreak = noise(vec2(wp.x * 1.8, floor(wp.y * 1.1)));
    float smallCurls = step(0.955, curlLine) * step(0.58, sparsePatch) * step(0.45, dashBreak);

    float sparkles = randomSparkles(p * 1.15 + warp * 0.25, uTime);
    float foam = clamp(smallCurls + sparkles, 0.0, 1.0);

    vec3 deepCobalt  = vec3(0.035, 0.340, 0.680);
    vec3 oceanBlue   = vec3(0.075, 0.470, 0.820);
    vec3 brightCyan  = vec3(0.180, 0.630, 0.920);
    vec3 toonFoam    = vec3(0.930, 0.985, 1.000);

    vec3 col = mix(deepCobalt, oceanBlue, band1);
    col = mix(col, brightCyan, band2);
    col = mix(col, toonFoam, foam);

    FragColor = vec4(col, 1.0);
}\x00"""

        var glCreateShader       = gl.get_function[c_uint]("glCreateShader")
        var glShaderSource       = gl.get_function("glShaderSource")
        var glCompileShader      = gl.get_function("glCompileShader")
        var glCreateProgram      = gl.get_function[c_uint]("glCreateProgram")
        var glAttachShader       = gl.get_function("glAttachShader")
        var glLinkProgram        = gl.get_function("glLinkProgram")
        var glGetUniformLocation = gl.get_function[c_int]("glGetUniformLocation")

        var vs_span = vs_src.as_c_string_span()
        var vs_ptr = CharPtr(unsafe_from_address=Int(vs_span.ptr()))
        var vs_len = c_int(len(vs_span))
        var vs = glCreateShader(GL_VERTEX_SHADER)
        glShaderSource(
            vs, c_int(1),
            CharPtrPtr(unsafe_from_address=Int(Pointer(to=vs_ptr))),
            IntPtr(unsafe_from_address=Int(Pointer(to=vs_len))),
        )
        glCompileShader(vs)
        _ = vs_ptr
        _ = vs_len
        _ = vs_src

        var fs_span = fs_src.as_c_string_span()
        var fs_ptr = CharPtr(unsafe_from_address=Int(fs_span.ptr()))
        var fs_len = c_int(len(fs_span))
        var fs = glCreateShader(GL_FRAGMENT_SHADER)
        glShaderSource(
            fs, c_int(1),
            CharPtrPtr(unsafe_from_address=Int(Pointer(to=fs_ptr))),
            IntPtr(unsafe_from_address=Int(Pointer(to=fs_len))),
        )
        glCompileShader(fs)
        _ = fs_ptr
        _ = fs_len
        _ = fs_src

        self.program = glCreateProgram()
        glAttachShader(self.program, vs)
        glAttachShader(self.program, fs)
        glLinkProgram(self.program)

        var n_mvp: String   = "uMVP\x00"
        var n_time: String  = "uTime\x00"
        var n_res: String   = "uResolution\x00"
        var n_shake: String = "uShake\x00"

        self.mvp_loc   = glGetUniformLocation(self.program, n_mvp.as_c_string_span().ptr())
        self.time_loc  = glGetUniformLocation(self.program, n_time.as_c_string_span().ptr())
        self.res_loc   = glGetUniformLocation(self.program, n_res.as_c_string_span().ptr())
        self.shake_loc = glGetUniformLocation(self.program, n_shake.as_c_string_span().ptr())
        _ = n_mvp
        _ = n_time
        _ = n_res
        _ = n_shake

    def draw(
        self,
        mut rl: RLGL,
        gl: OwnedDLHandle,
        x: Float32,
        y: Float32,
        w: Float32,
        h: Float32,
        time_sec: Float32,
        shake_x: Float32,
        shake_y: Float32,
    ) raises:
        rl.flush(gl)

        var glUseProgram       = gl.get_function("glUseProgram")
        var glUniform1f        = gl.get_function("glUniform1f")
        var glUniform2f        = gl.get_function("glUniform2f")
        var glUniformMatrix4fv = gl.get_function("glUniformMatrix4fv")
        var glBindVertexArray  = gl.get_function("glBindVertexArray")
        var glBindBuffer       = gl.get_function("glBindBuffer")
        var glBufferSubData    = gl.get_function("glBufferSubData")
        var glDrawArrays       = gl.get_function("glDrawArrays")

        glUseProgram(self.program)
        glUniform1f(self.time_loc, c_float(time_sec))
        glUniform2f(self.res_loc, c_float(w), c_float(h))
        glUniform2f(self.shake_loc, c_float(shake_x), c_float(shake_y))

        var m = Array[c_float, 16](uninitialized=True)
        m[0]  = rl.projection.c0[0]; m[1]  = rl.projection.c0[1]; m[2]  = rl.projection.c0[2]; m[3]  = rl.projection.c0[3]
        m[4]  = rl.projection.c1[0]; m[5]  = rl.projection.c1[1]; m[6]  = rl.projection.c1[2]; m[7]  = rl.projection.c1[3]
        m[8]  = rl.projection.c2[0]; m[9]  = rl.projection.c2[1]; m[10] = rl.projection.c2[2]; m[11] = rl.projection.c2[3]
        m[12] = rl.projection.c3[0]; m[13] = rl.projection.c3[1]; m[14] = rl.projection.c3[2]; m[15] = rl.projection.c3[3]
        glUniformMatrix4fv(self.mvp_loc, c_int(1), UInt8(0), FloatPtr(unsafe_from_address=Int(Pointer(to=m))))
        _ = m

        rl.current_color = Vec4f(1.0, 1.0, 1.0, 1.0)
        rl.texcoord2f(0.0, 0.0); rl.vertex3f(x, y, 0.0)
        rl.texcoord2f(0.0, 1.0); rl.vertex3f(x, y + h, 0.0)
        rl.texcoord2f(1.0, 1.0); rl.vertex3f(x + w, y + h, 0.0)
        rl.texcoord2f(0.0, 0.0); rl.vertex3f(x, y, 0.0)
        rl.texcoord2f(1.0, 1.0); rl.vertex3f(x + w, y + h, 0.0)
        rl.texcoord2f(1.0, 0.0); rl.vertex3f(x + w, y, 0.0)

        glBindVertexArray(rl.vao)
        glBindBuffer(GL_ARRAY_BUFFER, rl.vbo)
        glBufferSubData(GL_ARRAY_BUFFER, 0, rl.vertex_count * FLOATS_PER_VERTEX * 4, VoidPtr(unsafe_from_address=Int(rl.vertices)))
        glDrawArrays(GL_TRIANGLES, c_int(0), c_int(rl.vertex_count))
        rl.vertex_count = 0

        glUseProgram(rl.shader_program)

#float randomSparkles(vec2 p, float t) {
    #vec2 cell = floor(p);
    #vec2 local = fract(p);
    #vec2 rnd = hash2(cell);
    #if (rnd.x <= 0.65) return 0.0;
    #vec2 pos = 0.15 + 0.70 * rnd;
    #pos.y += sin(t * 1.6 + rnd.y * 6.2831) * 0.12;
    #vec2 d = local - pos;
    #d.x *= 0.65;
    #float pulse = sin(t * (2.2 + rnd.x * 2.5) + rnd.y * 12.0) * 0.5 + 0.5;
    #float radius = mix(0.03, 0.11, pulse);
    #return step(dot(d, d), radius * radius) * step(0.45, pulse);
#}

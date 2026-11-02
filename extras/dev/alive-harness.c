// Developer tool, not part of the theme. Runs shaders/alive.frag on Mesa's software GL (headless
// EGL) with a text texture bound as `source`, and writes the frame as a PAM image (premultiplied
// RGBA), so the creatures and spores can be looked at without a GPU or a compositor.
//
//   qsb -x "glsl,100 es" -o $T/alive.es.frag extras/plugin/annihilation.shimmer/shaders/alive.frag.qsb
//   gcc -O2 extras/dev/alive-harness.c -o $T/alive-harness -lEGL -lGLESv2
// An optional fourth argument is a second PAM, a blurred copy of the text, bound as `glowTex`.
//   EGL_PLATFORM=surfaceless LIBGL_ALWAYS_SOFTWARE=1 UNI="time=12;unit=38;seed=3;sporeAge=4;cell=7.6;\
//     bounds=171,171,1600,230;tint=0.5,0.8,0.8,1" $T/alive-harness $T/alive.es.frag text.pam out.pam
//
// text.pam is the source texture (P7, RGB_ALPHA, the text in white, alpha its coverage) and the frame
// has its size. UNI is "name=v1[,v2[,v3,v4]];..." and sets ubuf.<name> as a float, vec2, vec3 or vec4 by the
// number of values. FRAMES=N times N further draws. qt_TexCoord0 has y = 0 at the top, as in Qt. This tests
// the shader, not the Qt integration, and llvmpipe timings are not GPU timings.
#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static char *slurp(const char *p, long *len) { FILE *f = fopen(p, "rb"); if (!f) { perror(p); exit(1); } fseek(f, 0, SEEK_END); long n = ftell(f); rewind(f); char *b = malloc(n + 1); if (fread(b, 1, n, f) != (size_t)n) exit(1); b[n] = 0; fclose(f); if (len) *len = n; return b; }
static GLuint compile(GLenum type, const char *src) {
  GLuint s = glCreateShader(type); glShaderSource(s, 1, &src, NULL); glCompileShader(s);
  GLint ok; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
  if (!ok) { char log[4096]; glGetShaderInfoLog(s, sizeof log, NULL, log); fprintf(stderr, "shader compile failed:\n%s\n", log); exit(2); }
  return s;
}

int main(int argc, char **argv) {
  if (argc < 4) { fprintf(stderr, "usage: alive-harness shader.frag text.pam out.pam\n"); return 1; }
  long n; char *pam = slurp(argv[2], &n); int W = 0, H = 0; char *body = strstr(pam, "ENDHDR\n");
  if (!body || sscanf(strstr(pam, "WIDTH"), "WIDTH %d", &W) != 1 || sscanf(strstr(pam, "HEIGHT"), "HEIGHT %d", &H) != 1) { fprintf(stderr, "bad PAM\n"); return 1; }
  body += 7;
  EGLDisplay dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY); EGLint maj, min; if (!eglInitialize(dpy, &maj, &min)) return 3;
  eglBindAPI(EGL_OPENGL_ES_API);
  EGLint ca[] = { EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT, EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8, EGL_NONE };
  EGLConfig cfg; EGLint nc; if (!eglChooseConfig(dpy, ca, &cfg, 1, &nc) || nc < 1) return 4;
  EGLint pa[] = { EGL_WIDTH, 16, EGL_HEIGHT, 16, EGL_NONE }; EGLSurface surf = eglCreatePbufferSurface(dpy, cfg, pa);
  EGLint xa[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE }; EGLContext ctx = eglCreateContext(dpy, cfg, EGL_NO_CONTEXT, xa);
  if (!eglMakeCurrent(dpy, surf, surf, ctx)) return 5;
  const char *vs = "attribute vec2 pos; varying vec2 qt_TexCoord0; void main(){ qt_TexCoord0 = vec2(pos.x*0.5+0.5, 0.5-pos.y*0.5); gl_Position = vec4(pos,0.0,1.0); }";
  GLuint prog = glCreateProgram(); glAttachShader(prog, compile(GL_VERTEX_SHADER, vs)); glAttachShader(prog, compile(GL_FRAGMENT_SHADER, slurp(argv[1], NULL)));
  glBindAttribLocation(prog, 0, "pos"); glLinkProgram(prog); GLint ok; glGetProgramiv(prog, GL_LINK_STATUS, &ok);
  if (!ok) { char log[4096]; glGetProgramInfoLog(prog, sizeof log, NULL, log); fprintf(stderr, "link failed:\n%s\n", log); return 6; }
  glUseProgram(prog);
  float I4[16] = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};
  glUniformMatrix4fv(glGetUniformLocation(prog, "ubuf.qt_Matrix"), 1, GL_FALSE, I4);
  glUniform1f(glGetUniformLocation(prog, "ubuf.qt_Opacity"), 1.f);
  glUniform2f(glGetUniformLocation(prog, "ubuf.dims"), (float)W, (float)H);
  if (getenv("UNI")) {
    char *copy = strdup(getenv("UNI")), *save = NULL;
    for (char *tok = strtok_r(copy, ";", &save); tok; tok = strtok_r(NULL, ";", &save)) {
      char *eq = strchr(tok, '='); if (!eq) continue; *eq = 0;
      float v[4] = {0, 0, 0, 0}; int k = sscanf(eq + 1, "%f,%f,%f,%f", v, v + 1, v + 2, v + 3);
      char nm[64]; snprintf(nm, sizeof nm, "ubuf.%s", tok); GLint loc = glGetUniformLocation(prog, nm);
      if (loc < 0) { fprintf(stderr, "no uniform %s\n", nm); continue; }
      if (k == 1) glUniform1f(loc, v[0]); else if (k == 2) glUniform2f(loc, v[0], v[1]); else if (k == 3) glUniform3f(loc, v[0], v[1], v[2]); else glUniform4f(loc, v[0], v[1], v[2], v[3]);
    }
    free(copy);
  }
  // The texture arrives with row 0 at the top, which is where qt_TexCoord0 has y = 0, so it is uploaded as is.
  GLuint src; glGenTextures(1, &src); glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, src);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, body);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glUniform1i(glGetUniformLocation(prog, "source"), 0);
  if (argc > 4) {   // glowTex: the same size as the text texture
    char *g = slurp(argv[4], NULL); char *gb = strstr(g, "ENDHDR\n"); if (!gb) { fprintf(stderr, "bad glow PAM\n"); return 1; }
    GLuint gt; glGenTextures(1, &gt); glActiveTexture(GL_TEXTURE2); glBindTexture(GL_TEXTURE_2D, gt);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, gb + 7);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glUniform1i(glGetUniformLocation(prog, "glowTex"), 2);
  }
  GLuint fbo, tex; glGenTextures(1, &tex); glActiveTexture(GL_TEXTURE1); glBindTexture(GL_TEXTURE_2D, tex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
  glGenFramebuffers(1, &fbo); glBindFramebuffer(GL_FRAMEBUFFER, fbo); glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
  glActiveTexture(GL_TEXTURE0); glViewport(0, 0, W, H); glClearColor(0, 0, 0, 0); glClear(GL_COLOR_BUFFER_BIT);
  float quad[] = { -1,-1, 1,-1, -1,1, 1,1 }; glEnableVertexAttribArray(0); glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, quad);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4); glFinish();
  if (getenv("FRAMES")) {
    int N = atoi(getenv("FRAMES")); struct timespec a, b; clock_gettime(CLOCK_MONOTONIC, &a);
    for (int i = 0; i < N; i++) { glDrawArrays(GL_TRIANGLE_STRIP, 0, 4); glFinish(); }
    clock_gettime(CLOCK_MONOTONIC, &b); fprintf(stderr, "DRAW_MS %.1f\n", ((b.tv_sec - a.tv_sec) * 1e3 + (b.tv_nsec - a.tv_nsec) / 1e6) / N);
  }
  unsigned char *px = malloc((size_t)W * H * 4); glReadPixels(0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, px);
  FILE *o = fopen(argv[3], "wb"); fprintf(o, "P7\nWIDTH %d\nHEIGHT %d\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n", W, H);
  for (int y = H - 1; y >= 0; y--) fwrite(px + (size_t)y * W * 4, 1, (size_t)W * 4, o);
  fclose(o); return 0;
}

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

static void fail(const char *action) { perror(action); exit(1); }
static char *join(const char *a, const char *b) {
    char *path;
    if (asprintf(&path, "%s/%s", a, b) < 0) fail("asprintf");
    return path;
}
static void mkdirs(char *path) {
    for (char *p = path + 1; ; ++p) {
        char c = *p;
        if (c == '/' || !c) {
            *p = 0;
            if (mkdir(path, 0700) && errno != EEXIST) fail(path);
            *p = c;
            if (!c) break;
        }
    }
}
int main(int argc, char **argv) {
    (void)argc;
    const char *cache = getenv("XDG_CACHE_HOME");
    if (!cache || *cache != '/') {
        const char *home = getenv("HOME");
        if (!home || *home != '/') fail("absolute HOME required");
        cache = join(home, ".cache");
    }
    char *base = join(cache, "unified-interpreter");
    mkdirs(base);
    char *root = join(base, PAYLOAD_HASH);
    int lock = open(join(base, "extract.lock"), O_RDWR|O_CREAT|O_CLOEXEC, 0600);
    if (lock < 0 || flock(lock, LOCK_EX)) fail("cache lock");
    if (access(root, F_OK)) {
        char *stage = join(base, ".extract-XXXXXX");
        if (!mkdtemp(stage)) fail("mkdtemp");
        pid_t pid = fork();
        if (pid < 0) fail("fork");
        if (!pid) {
            int fd = open("/proc/self/exe", O_RDONLY);
            if (fd < 0 || lseek(fd, -PAYLOAD_SIZE, SEEK_END) < 0 || dup2(fd, 0) < 0) fail("payload");
            execl("/bin/tar", "tar", "-xzf", "-", "-C", stage, (char *)NULL);
            fail("tar");
        }
        int status;
        if (waitpid(pid, &status, 0) != pid || status != 0) { fputs("payload extraction failed\n", stderr); return 1; }
        if (rename(stage, root)) fail("publish cache");
    }
    close(lock);
    if (setenv("ATTENTION_ROOT", root, 1) || setenv("PYTHONHOME", join(root, ".venv-attention"), 1)
        || setenv("PYTHONNOUSERSITE", "1", 1) || setenv("PYTHONPATH", join(root, SITE_PACKAGES), 1)
        || setenv("LD_LIBRARY_PATH", join(root, "libs"), 1)) fail("environment");
    execv(join(root, "interpreter"), argv);
    fail("interpreter");
}

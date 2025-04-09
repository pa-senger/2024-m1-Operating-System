#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdnoreturn.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define CHK(op)                                                                \
    do {                                                                       \
        if ((op) == -1)                                                        \
            raler(1, #op);                                                     \
    } while (0)
#define CHKN(op)                                                               \
    do {                                                                       \
        if ((op) == NULL)                                                      \
            raler(1, #op);                                                     \
    } while (0)

#define CHEMIN_MAX 128

noreturn void raler(int syserr, const char *fmt, ...) {
    va_list ap;

    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    if (syserr)
        perror("");
    exit(1);
}

void concatener(char str[CHEMIN_MAX + 1], const char *dir, const char *fich) {
    int l;

    CHK(l = snprintf(str, CHEMIN_MAX + 1, "%s/%s", dir, fich));
    if (l > CHEMIN_MAX)
        raler(0, "trop long: %s/%s", dir, fich);
}

void majusculation(const char *src, const char *dst, mode_t perm) {
    int fd;

    switch (fork()) {
    case -1:
        raler(1, "fork sur %s", src);

    case 0:
        // redirection entrée standard depuis "src"
        CHK(fd = open(src, O_RDONLY));
        CHK(dup2(fd, 0));
        CHK(close(fd));

        // redirection sortie standard vers "dst"
        CHK(fd = open(dst, O_WRONLY | O_CREAT | O_TRUNC, 0666));
        CHK(fchmod(fd, perm));
        CHK(dup2(fd, 1));
        CHK(close(fd));

        execlp("tr", "tr", "a-z", "A-Z", NULL);
        raler(1, "exec tr %s", src);

    default:
        break;
    }
}

void parcourir(const char *src, const char *dst, mode_t permrep) {
    DIR *dp;
    struct dirent *d;
    char nsrc[CHEMIN_MAX + 1], ndst[CHEMIN_MAX + 1];
    struct stat stbuf;
    int raison;
    int nfils;

    CHKN(dp = opendir(src));
    CHK(mkdir(dst, 0777));

    // toute la lecture
    nfils = 0;
    errno = 0;
    while ((d = readdir(dp)) != NULL) {
        if (strcmp(d->d_name, ".") != 0 && strcmp(d->d_name, "..") != 0) {
            concatener(nsrc, src, d->d_name);
            concatener(ndst, dst, d->d_name);

            CHK(lstat(nsrc, &stbuf));
            switch (stbuf.st_mode & S_IFMT) {
            case S_IFDIR:
                parcourir(nsrc, ndst, stbuf.st_mode & 0777);
                break;
            case S_IFREG:
                majusculation(nsrc, ndst, stbuf.st_mode & 0777);
                nfils++;
                break;
            default:
                // ignorer les autres cas (y compris les liens symboliques)
                break;
            }
        }

        errno = 0;
    }
    if (errno != 0)
        raler(1, "readdir");

    CHK(closedir(dp));

    for (int i = 0; i < nfils; i++) {
        CHK(wait(&raison));
        if (!(WIFEXITED(raison) && WEXITSTATUS(raison) == 0))
            raler(0, "fils mal terminé");
    }

    CHK(chmod(dst, permrep));
}

int main(int argc, const char *argv[]) {
    struct stat stbuf;

    if (argc != 3)
        raler(0, "usage: majus src dst");

    CHK(stat(argv[1], &stbuf));
    parcourir(argv[1], argv[2], stbuf.st_mode & 0777);

    exit(0);
}

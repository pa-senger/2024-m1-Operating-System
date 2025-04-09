#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdnoreturn.h>
#include <string.h>
#include <unistd.h>

// les constantes demandées par l'énoncé
#define CHEMIN_MAX 128
#define MAXBUF 4096

#define SUFFIXE ".rot"

#define CHK(op)                                                                \
    do {                                                                       \
        if ((op) == -1)                                                        \
            raler(#op);                                                        \
    } while (0)

#define MIN(a, b) ((a) < (b) ? (a) : (b))

noreturn void raler(const char *msg) {
    perror(msg);
    exit(1);
}

noreturn void usage(void) {
    fprintf(stderr, "usage: rotation n f1 ... fn\n");
    exit(1);
}

// org = chemin du fichier original
void rotation(int n, const char *org) {
    int fd1, fd2;
    char buf[MAXBUF];
    char pathrot[CHEMIN_MAX + 1]; // +1 pour le '\0' de fin de chaîne
    int l;
    ssize_t nlus;

    CHK(l = snprintf(pathrot, sizeof pathrot, "%s%s", org, SUFFIXE));
    if (l >= (int)sizeof pathrot) {
        fprintf(stderr, "chemin '%s%s' trop long\n", org, SUFFIXE);
        exit(1);
    }

    CHK(fd1 = open(org, O_RDONLY));
    CHK(fd2 = open(pathrot, O_WRONLY | O_CREAT | O_TRUNC, 0666));

    // étape 1 : recopier tous les octets à partir du n-ième
    CHK(lseek(fd1, n, SEEK_SET));
    while ((nlus = read(fd1, buf, sizeof buf)) > 0)
        CHK(write(fd2, buf, nlus));
    CHK(nlus);

    // étape 2 : recopier les n premiers octets à la suite du nouveau fichier
    CHK(lseek(fd1, 0, SEEK_SET));
    while (n > 0) {
        CHK(nlus = read(fd1, buf, MIN((int)sizeof buf, n)));
        if (nlus == 0)
            break;

        CHK(write(fd2, buf, nlus));
        n -= nlus;
    }

    CHK(close(fd1));
    CHK(close(fd2));
}

int main(int argc, char *argv[]) {
    int i, n;

    if (argc < 2)
        usage();
    n = atoi(argv[1]);
    if (n < 0)
        usage();

    for (i = 2; i < argc; i++)
        rotation(n, argv[i]);

    exit(0);
}

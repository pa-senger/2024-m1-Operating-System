#include <errno.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdnoreturn.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define CHK(op)                                                                \
    do {                                                                       \
        if ((op) == -1)                                                        \
            raler(1, #op);                                                     \
    } while (0)

struct couple {
    int x;
    int y;
};

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

void fils_multiplieur(int tube1[], int tube2[]) {
    ssize_t nlus;
    struct couple couple;
    int produit;

    CHK(close(tube1[1]));
    CHK(close(tube2[0]));

    while ((nlus = read(tube1[0], &couple, sizeof couple)) > 0) {
        produit = couple.x * couple.y;
        CHK(write(tube2[1], &produit, sizeof produit));
    }
    CHK(nlus);

    CHK(close(tube1[0]));
    CHK(close(tube2[1]));
}

void fils_additionneur(int tube1[], int tube2[]) {
    ssize_t nlus;
    int somme, xiyi;

    CHK(close(tube1[0]));
    CHK(close(tube1[1]));
    CHK(close(tube2[1]));

    somme = 0;
    while ((nlus = read(tube2[0], &xiyi, sizeof xiyi)) > 0)
        somme += xiyi;
    CHK(nlus);

    CHK(close(tube2[0]));

    printf("%d\n", somme);
}

int main(int argc, char *argv[]) {
    int tube1[2], tube2[2];
    int c, n;
    int raison;
    struct couple couple;

    if (argc < 4 || argc % 2 != 0)
        raler(0, "usage: prodscal c x1 ... xn y1 ... yn");

    c = atoi(argv[1]);
    if (c <= 0)
        raler(0, "usage: prodscal c x1 ... xn y1 ... yn");

    n = (argc - 2) / 2;

    CHK(pipe(tube1));
    CHK(pipe(tube2));

    for (int j = 0; j <= c; j++) {
        switch (fork()) {
        case -1:
            raler(1, "cannot fork child %d", j);

        case 0:
            if (j < c)
                fils_multiplieur(tube1, tube2);
            else
                fils_additionneur(tube1, tube2);
            exit(0);

        default:
            // surtout ne rien faire
            break;
        }
    }

    CHK(close(tube1[0]));
    CHK(close(tube2[0]));
    CHK(close(tube2[1]));

    // injecter les couples (xi,yi) dans le premier tube

    for (int i = 0; i < n; i++) {
        couple.x = atoi(argv[2 + i]);
        couple.y = atoi(argv[2 + n + i]);
        CHK(write(tube1[1], &couple, sizeof couple));
    }

    CHK(close(tube1[1]));

    // attendre la terminaison des fils

    for (int j = 0; j <= c; j++) {
        CHK(wait(&raison));
        if (!(WIFEXITED(raison) && WEXITSTATUS(raison) == 0)) {
            if (WIFEXITED(raison))
                raler(0, "fils mal terminé exit %d", WEXITSTATUS(raison));
            else if (WIFSIGNALED(raison))
                raler(0, "fils mal terminé signal %d", WTERMSIG(raison));
            else
                raler(0, "fils mal terminé raison inconnue");
        }
    }

    exit(0);
}

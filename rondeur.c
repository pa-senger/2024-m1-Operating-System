#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
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

#define CHKS(op)                                                               \
    do {                                                                       \
        if ((op) == -1) {                                                      \
            CHK(kill(getppid(), SIGUSR2));                                     \
            raler(1, #op);                                                     \
        }                                                                      \
    } while (0)

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

void args(int argc, const char *argv[], const char **fich, int tv[], int *pn) {
    int n = argc - 2;
    if (argc < 3)
        raler(0, "usage: ronde fichier v0 ... vn-1");

    *fich = argv[1];
    if (*pn < n)
        raler(0, "le tableau est trop petit");
    if (n == 0)
        raler(0, "il faut au moins un entier");

    for (int i = 0; i < n; i++)
        tv[i] = atoi(argv[i + 2]);

    *pn = n;
}

volatile sig_atomic_t recu1 = 0;
volatile sig_atomic_t recu2 = 0;

void handler(int signum) {
    switch (signum) {
    case SIGUSR1:
        recu1 = 1;
        break;
    case SIGUSR2:
        recu2 = 1;
        break;
    case SIGCHLD:
        raler(0, "fils interrompu brutalement");
    default:
        raler(0, "erreur sig %d inconnu", signum);
    }
}

void preparer_signaux(void) {
    struct sigaction s;
    sigset_t empty, old, new;

    s.sa_flags = 0;
    s.sa_handler = handler;

    CHK(sigemptyset(&s.sa_mask));
    CHK(sigemptyset(&empty));
    CHK(sigaction(SIGUSR1, &s, NULL));

    CHK(sigemptyset(&new));
    CHK(sigaddset(&new, SIGUSR1));
    CHK(sigaddset(&new, SIGUSR2));

    CHK(sigprocmask(SIG_BLOCK, &new, &old));
}

void attendre_signal(int signum) {
    sigset_t vide;
    CHK(sigemptyset(&vide));

    while (!recu1 && !recu2) {
        sigsuspend(&vide);
    }
}

void fils(const char *fichier, int i, int vi) {
    int fd, val;
    pid_t pid;

    while (!recu1) {
        attendre_signal(SIGUSR1);
        recu1 = 0;
    }

    CHK(fd = open(fichier, O_RDWR | O_TRUNC | O_CREAT, 0666));
    CHK(lseek(fd, (i + 1) * sizeof(int), SEEK_SET));
    CHK(read(fd, &pid, sizeof(pid_t)));
    CHK(lseek(fd, -sizeof(pid_t), SEEK_CUR));
    CHK(write(fd, &vi, sizeof(int)));
    CHK(close(fd));

    CHK(kill(pid, SIGUSR2));

    while (!recu2) {
        attendre_signal(SIGUSR2);
        recu2 = 0;
    }
    CHK(fd = open(fichier, O_RDONLY | O_CREAT, 0666));
    CHK(lseek(fd, (i + 1) * sizeof(int), SEEK_SET));
    CHK(read(fd, &val, sizeof(int)));
    printf("%d\n", val);
    CHK(close(fd));
    exit(0);
}

void lancer(const char *fichier, const int tv[], int n) {
    int fd;
    pid_t pid;
    pid_t all_pid[n];

    for (int i = 0; i <= n; ++i) {
        switch (pid = fork()) {
        case -1:
            raler(1, "fork");
        case 0:
            fils(fichier, i, tv[i]);
            exit(0);
        default:
            all_pid[i] = pid;
            break;
        }
    }
    CHK(fd = open(fichier, O_RDWR | O_TRUNC | O_CREAT, 0666));
    CHK(write(fd, all_pid, sizeof(all_pid)));
    CHK(close(fd));

    for (int i = 0; i <= n; ++i)
        CHK(kill(all_pid[i], SIGUSR1));
}

int main(const int argc, const char *argv[]) {
    int raison, n, pn;
    n = argc - 2;
    pn = n;
    int tv[pn];

    args(argc, argv, &argv[1], tv, &pn);

    for (int i = 0; i <= n; ++i) {
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

    CHK(unlink(argv[1]));
    exit(0);
}
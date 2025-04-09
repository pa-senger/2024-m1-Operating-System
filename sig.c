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

#define CHEMIN_MAX 128

#define CHK(op)                                                                \
    do {                                                                       \
        if ((op) == -1)                                                        \
            raler(1, #op);                                                     \
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

volatile sig_atomic_t s1_recu = 0;
volatile sig_atomic_t s2_recu = 0;
volatile sig_atomic_t alarm_recu = 0;

void recv_sigusr1(int bidon) {
    (void)bidon;
    s1_recu += 1;
}

void recv_sigusr2(int bidon) {
    (void)bidon;
    s2_recu = 1;
}

void recv_alarm(int bidon) {
    (void)bidon;
    alarm_recu = 1;
}

void child(void) {
    sigset_t old, new, empty;
    CHK(sigemptyset(&new));
    CHK(sigemptyset(&empty));
    CHK(sigaddset(&new, SIGUSR1));
    CHK(sigaddset(&new, SIGUSR2));

    CHK(sigprocmask(SIG_BLOCK, &new, &old));

    while (!s2_recu) {
        sigsuspend(&empty);
    }
    CHK(sigprocmask(SIG_SETMASK, &old, NULL));

    printf("fils : nb signaux recus = %d\n", s1_recu);
    exit(0);
}

int main(int argc, char *argv[]) {
    int raison, pid, nb_sec, nb_sent = 0;
    struct sigaction s;

    if (argc < 2)
        raler(0, "usage sig nb-seconds");
    nb_sec = atoi(argv[1]);
    if (nb_sec < 0)
        raler(0, "usage sig nb-seconds");

    s.sa_flags = 0;
    CHK(sigemptyset(&s.sa_mask));

    s.sa_handler = recv_alarm;
    CHK(sigaction(SIGALRM, &s, NULL));

    s.sa_handler = recv_sigusr1;
    CHK(sigaction(SIGUSR1, &s, NULL));

    s.sa_handler = recv_sigusr2;
    CHK(sigaction(SIGUSR2, &s, NULL));

    switch ((pid = fork())) {
    case -1:
        raler(1, "fork");
    case 0:
        // child
        child();
        exit(0);
    default:
        // parent
        break;
    }

    alarm(nb_sec);
    while (!alarm_recu) {
        CHK(kill(pid, SIGUSR1));
        nb_sent++;
    }

    printf("pere : nb signaux emis = %d\n", nb_sent);

    CHK(kill(pid, SIGUSR2));

    CHK(wait(&raison));
    if (!(WIFEXITED(raison) && WEXITSTATUS(raison) == 0)) {
        if (WIFEXITED(raison))
            raler(0, "fils mal terminé exit %d", WEXITSTATUS(raison));
        else if (WIFSIGNALED(raison))
            raler(0, "fils mal terminé signal %d", WTERMSIG(raison));
        else
            raler(0, "fils mal terminé raison inconnue");
    }

    exit(0);
}
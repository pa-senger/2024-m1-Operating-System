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

volatile sig_atomic_t s1_recu = 0;
volatile sig_atomic_t s2_recu = 0;

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

struct Data {
    int n, i, x, p;
};

void recv_sigusr1(int sig) {
    (void)sig;
    s1_recu = 1;
}

void recv_sigusr2(int sig) {
    (void)sig;
    s2_recu = 1;
}

void calculate_aixi(struct Data *data, int ai) {
    int tube[2];
    int result, raison, arg_count = 0;
    char result_str[50];
    char *args[CHEMIN_MAX + 1];
    char str_ai[50];
    char str_x[50];

    sprintf(str_ai, "%d", ai);
    sprintf(str_x, "%d", data->x);

    args[arg_count++] = "expr"; // first argument
    args[arg_count++] = str_ai;
    for (int i = 0; i < data->i; ++i) {
        args[arg_count++] = "*";
        args[arg_count++] = str_x;
    }
    args[arg_count] = NULL; // last argument

    CHK(pipe(tube));

    switch (fork()) {
    case -1:
        raler(1, "fork");
    case 0:
        // child process
        CHK(close(tube[0]));
        CHK(dup2(tube[1], 1));

        execvp(args[0], args);
        raler(1, "exec %s", args[0]);

    default:
        // parent process
        CHKS(wait(&raison));
        if (!(WIFEXITED(raison) && WEXITSTATUS(raison) == 0)) {
            CHKS(kill(getppid(), SIGUSR2));
            exit(1);
        }

        CHKS(close(tube[1]));
        CHKS(read(tube[0], result_str, sizeof(result_str)));
        CHKS(close(tube[0]));

        result = atoi(result_str);
        data->p += result;
        data->i++;

        break;
    }
}

void read_data(int fd, struct Data *data, int parent) {
    lseek(fd, 0, SEEK_SET);
    if (parent)
        CHK(read(fd, data, sizeof(struct Data)));
    else
        CHKS(read(fd, data, sizeof(struct Data)));
}

void write_data(int fd, struct Data *data, int parent) {
    lseek(fd, 0, SEEK_SET);
    if (parent)
        CHK(write(fd, data, sizeof(struct Data)));
    else
        CHKS(write(fd, data, sizeof(struct Data)));
}

void child(int fd, int ai) {
    struct Data data;
    pid_t pid;
    sigset_t empty;

    CHKS(sigemptyset(&empty));

    while (!s2_recu) {
        sigsuspend(&empty);

        if (s1_recu) {
            s1_recu = 0;

            read_data(fd, &data, 0);

            calculate_aixi(&data, ai);

            write_data(fd, &data, 0);

            lseek(fd, (data.i - 1) * sizeof(int), SEEK_CUR);
            CHKS(read(fd, &pid, sizeof(pid)));
            CHKS(kill(pid, SIGUSR1)); // send sigusr1 to next process
        }
    }
    s2_recu = 0;
    exit(0);
}

int main(int argc, char *argv[]) {
    if (argc < 4)
        raler(0, "usage : poly k f a0 ... an");

    int n = argc - 4; // coeff index start at 0
    int k = atoi(argv[1]);

    if (k <= 0 || n < 0)
        raler(0, "usage : poly k f a0 ... an");

    int fd, raison, running;
    pid_t pid, first_pid;
    struct Data data = {n, 0, 1, 0}; // n, i, x, p
    struct sigaction s;
    sigset_t empty, old, new;

    s.sa_flags = 0;
    CHK(sigemptyset(&s.sa_mask));
    CHK(sigemptyset(&empty));

    s.sa_handler = recv_sigusr1;
    CHK(sigaction(SIGUSR1, &s, NULL));

    s.sa_handler = recv_sigusr2;
    CHK(sigaction(SIGUSR2, &s, NULL));

    // open in reading and writing
    CHK(fd = open(argv[2], O_RDWR | O_TRUNC | O_CREAT, 0666));
    // write data to file, n, i, x, p
    CHK(write(fd, &data, sizeof(struct Data)));

    // set mask to block SIGUSR1 and SIGUSR2
    CHK(sigemptyset(&new));
    CHK(sigaddset(&new, SIGUSR1));
    CHK(sigaddset(&new, SIGUSR2));

    CHK(sigprocmask(SIG_BLOCK, &new, &old));

    // create n+1 children
    for (int i = 0; i <= n; ++i) {
        switch (pid = fork()) {
        case -1:
            raler(1, "fork");
        case 0:
            // child
            child(fd, atoi(argv[i + 3]));
            exit(0); // cordon sanitaire
        default:
            // parent
            if (i == 0) {
                first_pid = pid; // first child pid, dont write to file
            } else {
                CHK(write(fd, &pid, sizeof(pid)));
            }
            break;
        }
    }

    pid = getpid(); // parent pid
    CHK(write(fd, &pid, sizeof(pid)));

    CHK(kill(first_pid, SIGUSR1)); // send first sigusr1 to first child

    running = 1;
    while (running) {

        sigsuspend(&empty);

        if (s2_recu)
            raler(0, "fils mal terminé\n");

        if (s1_recu) {
            s1_recu = 0;

            read_data(fd, &data, 1);

            printf("%d\n", data.p);

            if (data.x >= k) {
                running = 0;
                continue;
            }
            data.x += 1;
            data.p = 0;
            data.i = 0;

            write_data(fd, &data, 1);

            CHK(kill(first_pid, SIGUSR1)); // send sigusr1 to first child;
        }
    }

    // send sigusr2 to all children
    CHK(kill(first_pid, SIGUSR2));
    lseek(fd, sizeof(struct Data), SEEK_SET);
    for (int j = 0; j < n; ++j) {
        CHK(read(fd, &pid, sizeof(pid)));
        CHK(kill(pid, SIGUSR2));
    }

    // unblock SIGUSR1 and SIGUSR2
    CHK(sigprocmask(SIG_SETMASK, &old, NULL));

    // wait for n+1 children
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

    CHK(close(fd));
    unlink(argv[2]); // delete file

    exit(0);
}
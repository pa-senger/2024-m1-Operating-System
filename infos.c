#include <ctype.h>
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
#define MAXBUF 4096

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

struct infos {
    char chemin[CHEMIN_MAX + 1];
    ino_t inode;
    off_t taille;
    off_t nblignes;
    off_t nblettres;
};

#define TABDYN_INCREMENT 50 // on alloue ce nb d'entrées à chaque fois
struct tabdyn {
    int dim;           // dimension du tableau (taille allocation)
    int nbent;         // nombre d'entrées actuellement utilisées
    struct infos *tab; // le tableau lui-même
};

void tab_init(struct tabdyn *t) {
    t->dim = t->nbent = 0;
    t->tab = NULL;
}

void tab_add(struct tabdyn *t, struct infos *i) {
    if (t->nbent >= t->dim) {
        t->dim += TABDYN_INCREMENT;
        CHKN(t->tab = realloc(t->tab, t->dim * sizeof(struct infos)));
    }
    // on sait qu'on a suffisamment de place pour ajouter une entrée
    t->tab[t->nbent++] = *i;
}

int compare(const void *v1, const void *v2) {
    const struct infos *i1 = v1;
    const struct infos *i2 = v2;

    return (i1->inode < i2->inode) ? -1 : ((i1->inode > i2->inode) ? 1 : 0);
}

void tab_sort(struct tabdyn *t) {
    qsort(t->tab, t->nbent, sizeof(struct infos), compare);
}

void tab_print(struct tabdyn *t) {
    for (int i = 0; i < t->nbent; i++) {
        struct infos *p = &t->tab[i];
        printf("%ju %jd %jd %jd %s\n", (uintmax_t)p->inode, (intmax_t)p->taille,
               (intmax_t)p->nblignes, (intmax_t)p->nblettres, p->chemin);
    }
}

void tab_destroy(struct tabdyn *t) {
    if (t->dim > 0)
        free(t->tab);
    tab_init(t);
}

void chercher_infos(const char *chemin, struct stat *stbuf, struct infos *i) {
    int fd;
    char buf[MAXBUF];
    ssize_t nlus;

    strcpy(i->chemin, chemin);
    i->inode = stbuf->st_ino;
    i->taille = stbuf->st_size;
    i->nblignes = i->nblettres = 0;
    CHK(fd = open(chemin, O_RDONLY));
    while ((nlus = read(fd, buf, sizeof buf)) > 0) {
        for (int j = 0; j < nlus; j++) {
            if (isalpha(buf[j]))
                i->nblettres++;
            else if (buf[j] == '\n')
                i->nblignes++;
        }
    }
    CHK(nlus);
    CHK(close(fd));
}

void parcourir(struct tabdyn *t, const char *chemin) {
    DIR *dp;
    struct dirent *d;
    struct stat stbuf;
    char nch[CHEMIN_MAX + 1];
    int l;
    struct infos i;

    CHKN(dp = opendir(chemin));

    errno = 0;
    while ((d = readdir(dp)) != NULL) {
        if (strcmp(d->d_name, ".") != 0 && strcmp(d->d_name, "..") != 0) {
            CHK(l = snprintf(nch, sizeof nch, "%s/%s", chemin, d->d_name));
            if (l >= (int)sizeof nch)
                raler(0, "chemin %s/%s trop long", chemin, d->d_name);
            CHK(lstat(nch, &stbuf));

            switch (stbuf.st_mode & S_IFMT) {
            case S_IFDIR:
                parcourir(t, nch);
                break;

            case S_IFREG:
                chercher_infos(nch, &stbuf, &i);
                tab_add(t, &i);
                break;

            case S_IFLNK:
                // ignorer ce cas
                break;

            default:
                // dans tous les autres cas (non connus), on ignore
                break;
            }
        }

        errno = 0;
    }
    if (errno != 0)
        raler(1, "readdir");

    CHK(closedir(dp));
}

int main(int argc, const char *argv[]) {
    struct tabdyn t;

    if (argc != 2)
        raler(0, "usage: infos repertoire");

    tab_init(&t);
    parcourir(&t, argv[1]);
    tab_sort(&t);
    tab_print(&t);
    tab_destroy(&t);
    exit(0);
}

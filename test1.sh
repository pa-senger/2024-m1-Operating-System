#!/bin/sh

PROG=${PROG:=./rotation}		# chemin de l'exécutable

TMP=${TMP:=/tmp/test}			# chemin des logs de test

#
# Script Shell de test de l'exercice 1
# Utilisation : sh ./test1.sh
#
# Si tout se passe bien, le script doit afficher "Tests ok" à la fin
# Les fichiers sont laissés dans /tmp/test* en cas d'échec, vous
# pouvez les examiner.
# Pour avoir plus de détails sur l'exécution du script, vous pouvez
# utiliser :
#	sh -x ./test1.sh
# Toutes les commandes exécutées par le script sont alors affichées
# et vous pouvez les exécuter séparément.
#

set -u					# erreur si variable non définie

# il ne faudrait jamais appeler cette fonction
# argument : message d'erreur
fail ()
{
    local msg="$1"

    echo FAIL				# aie aie aie...
    echo "$msg"
    echo "Voir les fichiers suivants :"
    ls -dp $TMP*
    exit 1
}

# longueur (en nb de caractères, pas d'octets) d'une chaîne UTF-8
strlen ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE strlen"
    local str="$1"
    (
	export LC_ALL=C.UTF-8
	printf "%s" "$str" | wc -m
    )
}

# Annonce un test
# $1 = numéro du test
# $2 = intitulé
annoncer_test ()
{
    [ $# != 2 ] && fail "ERREUR SYNTAXE annoncer_test"
    local num="$1" msg="$2"
    local debut nbcar nbtirets

    # echo '\c', bien que POSIX, n'est pas supporté sur tous les Shell
    # POSIX recommande d'utiliser printf
    # Par contre, printf ne gère pas correctement les caractères Unicode
    # donc on est obligé de recourrir à un subterfuge pour préserver
    # l'alignement des "OK"
    debut="Test $num - $msg"
    nbcar=$(strlen "$debut")
    nbtirets=$((80 - 6 - nbcar))
    printf "%s%-${nbtirets}.${nbtirets}s " "$debut" \
	"...................................................................."
}

# Teste si le fichier est vide (ne fait que tester, pas d'erreur renvoyée)
est_vide ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE est_vide"
    local fichier="$1"
    test $(wc -l < "$fichier") = 0
}

# Vérifie que le message d'erreur est envoyé sur la sortie d'erreur
# et non sur la sortie standard
# $1 = nom du fichier de log (sans .err ou .out)
# $2 (optionnel) = message
verifier_stderr ()
{
    [ $# != 1 -a $# != 2 ] && fail "ERREUR SYNTAXE verifier_stderr"
    local base="$1" msg=""
    if [ $# = 2 ]
    then msg=" ($2)"
    fi
    est_vide $base.err \
	&& fail "Le message d'erreur devrait être sur la sortie d'erreur$msg"
    est_vide $base.out \
	|| fail "Rien ne devrait être affiché sur la sortie standard$msg"
}

# Vérifie que le résultat est envoyé sur la sortie standard
# et non sur la sortie d'erreur
# $1 = nom du fichier de log (sans .err ou .out)
verifier_stdout ()
{
    [ $# != 1 -a $# != 2 ] && fail "ERREUR SYNTAXE verifier_stdout"
    local base="$1" msg=""
    if [ $# = 2 ]
    then msg=" ($2)"
    fi
    est_vide $base.out \
	&& fail "Le résultat devrait être sur la sortie d'erreur$msg"
    est_vide $base.err \
	|| fail "Rien ne devrait être affiché sur la sortie d'erreur$msg"
}

# Vérifie que le message d'erreur indique la bonne syntaxe
# $1 = nom du fichier de log d'erreur
verifier_usage ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE verifier_usage"
    local err="$1"
    grep -q "usage *: " $err \
	|| fail "Message d'erreur devrait indiquer 'usage:...'"
}

# Vérifie que le programme n'affiche rien du tout
verifier_pas_de_sortie ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE verifier_pas_de_sortie"
    local base="$1"
    est_vide $base.err \
	|| fail "Rien ne devrait être affiché sur la sortie d'erreur"
    est_vide $base.out \
	|| fail "Rien ne devrait être affiché sur la sortie standard"
}

# Reproduit le résultat du programme et compare avec la sortie
# $1 = n
# $2 = nom du fichier d'entrée
reproduire_et_comparer ()
{
    [ $# != 2 ] && fail "ERREUR SYNTAXE reproduire_et_comparer"
    local n="$1" src="$2"

    local out att
    out="$src.rot"		# fichier produit par le programme à tester
    att="$src.att"		# fichier attendu par le script de test

    # reproduire le résultat du progamme dans le fichier "attendu"
    dd if="$src" bs="$n" skip=1  >  "$att" 2> "$src.dd" || fail "pb rc dd 1"
    dd if="$src" bs="$n" count=1 >> "$att" 2> "$src.dd"	|| fail "pb rc dd 2"

    # comparer le résultat du programme avec le résultat attendu
    cmp "$out" "$att" > "$src.cmp"	|| fail "$out != $att (cf $src.cmp)"
}

# lancer valgrind avec toutes les options
tester_valgrind ()
{
    local r
    valgrind \
	--leak-check=full \
	--errors-for-leak-kinds=all \
	--show-leak-kinds=all \
	--error-exitcode=100 \
	--log-file=$TMP.valgrind \
	"$@" > $TMP.out 2> $TMP.err
    r=$?
    [ $r = 100 ] && fail "pb mémoire (voir $TMP.valgrind)"
    [ $r != 0 ] && fail "erreur programme avec valgrind (voir $TMP.*)"
    return $r
}

# Supprimer les fichiers restant d'une précédente exécution
nettoyer ()
{
    chmod -R +w $TMP* 2> /dev/null
    rm -rf $TMP*
}

##############################################################################
# Vérification des arguments

annoncer_test 1.1 "code de retour non nul si pas d'argument"
$PROG > $TMP.out 2> $TMP.err		&& fail "code de retour == 0"
echo OK

annoncer_test 1.2 "pas d'erreur si aucun fichier fourni"
$PROG 12 > $TMP.out 2> $TMP.err		|| fail "code de retour != 0"
verifier_pas_de_sortie $TMP
echo OK

annoncer_test 1.3 "message d'erreur sur la sortie d'erreur"
$PROG > $TMP.out 2> $TMP.err		&& fail "code de retour == 0"
verifier_stderr $TMP
echo OK

annoncer_test 1.4 "message 'usage:'"
$PROG > $TMP.out 2> $TMP.err		&& fail "code de retour == 0"
verifier_stderr $TMP
verifier_usage $TMP.err
echo OK

annoncer_test 1.5 "vérification de l'argument n"
$PROG -1 > $TMP.out 2> $TMP.err		&& fail "n == -1 => invalide"
verifier_stderr $TMP
$PROG 0 > $TMP.out 2> $TMP.err		|| fail "n == 0 => valide"
echo OK

##############################################################################
# Tests basiques de détection d'erreur

annoncer_test 2.1 "fichier inexistant"
$PROG 1 $TMP.rien > $TMP.out 2> $TMP.err && fail "fichier inxistant"
verifier_stderr $TMP
echo OK

annoncer_test 2.2 "création impossible pour le fichier de sortie"
nettoyer
mkdir $TMP.d
touch $TMP.d/toto
chmod 555 $TMP.d	# répertoire non modifiable
$PROG 1 $TMP.d/toto > $TMP.out 2> $TMP.err && fail "création fichier sortie"
verifier_stderr $TMP
nettoyer
echo OK

annoncer_test 2.3 "chemin trop grand"
nettoyer
CHEMIN_MAX=128
max=$((CHEMIN_MAX - 4))	# il faut de la place pour le suffixe ".rot"
# créer un chemin de taille "max" octets
d=$TMP.d
l=$(strlen $d)
while [ $l -le $((max - 40)) ]
do
    d="$d/un.nom.de.repertoire.tres.long"
    l=$(strlen $d)
done
mkdir -p $d		# "-p" : crée les répertoires intermédiaires
reste=$((max - l - 1))	# -1 pour le / final
dernier=$(printf "%${reste}.${reste}s" "abcdefghijklmnopqrstuvwxyzABCDEFGHIJ")
correct=$d/$dernier
troplong=$d/${dernier}X
# un chemin de 125 octets + ".rot", ça ne passe pas
echo bla > $troplong
$PROG 0 $troplong > $TMP.out 2> $TMP.err && fail "fichier trop long"
verifier_stderr $TMP
# un chemin de 124 octets + ".rot", ça passe
echo bla > $correct
$PROG 0 $correct  > $TMP.out 2> $TMP.err || fail "fichier devrait être accepté"
verifier_pas_de_sortie $TMP
nettoyer
echo OK

##############################################################################
# Tests basiques de fonctionnement

# Note : pour voir le contenu précis des fichiers, utiliser l'utilitaire "hd"

annoncer_test 3.1 "rotation de 5"
nettoyer
# fichier d'entrée (la première ligne contient 5 octets, \n compris)
cat <<EOF > $TMP.src
abcd
efghij
kl
EOF
$PROG 5 $TMP.src > $TMP.out 2> $TMP.err || fail "erreur rencontrée"
verifier_pas_de_sortie $TMP
reproduire_et_comparer 5 $TMP.src
# pour voir la différence entre fichiers, utiliser l'utilitaire "hd"
echo OK

annoncer_test 3.2 "rotation de 4"
nettoyer
# fichier d'entrée (identique)
cat <<EOF > $TMP.src
abcd
efghij
kl
EOF
$PROG 4 $TMP.src > $TMP.out 2> $TMP.err || fail "erreur rencontrée"
verifier_pas_de_sortie $TMP
reproduire_et_comparer 4 $TMP.src
echo OK

annoncer_test 3.3 "rotation de 0"
nettoyer
# fichier d'entrée (identique)
cat <<EOF > $TMP.src
abcd
efghij
kl
EOF
$PROG 0 $TMP.src > $TMP.out 2> $TMP.err || fail "erreur rencontrée"
verifier_pas_de_sortie $TMP
cmp $TMP.src $TMP.src.rot > $TMP.cmp	|| fail "fichiers non identiques"
echo OK

annoncer_test 3.4 "traitement de plusieurs fichiers"
nettoyer
args=""
for i in $(seq 1 5)
do
    dd if=/dev/random bs=$(( 7*(i+5) )) count=1 > $TMP.src.$i 2> /dev/null \
    		|| fail "pb dd $i"
    args="$args $TMP.src.$i"
done
$PROG 13 $args > $TMP.out 2> $TMP.err || fail "erreur rencontrée"
verifier_pas_de_sortie $TMP
for i in $(seq 1 5)
do
    reproduire_et_comparer 13 $TMP.src.$i
done
echo OK

annoncer_test 3.5 "fichier avec des octets nuls"
nettoyer
# construire un fichier avec (au moins) 3 octets nuls
dd if=/dev/random bs=6 count=1 >> $TMP.src 2> /dev/null || fail "pb dd 1"
dd if=/dev/zero   bs=1 count=1 >> $TMP.src 2> /dev/null || fail "pb dd 2"
dd if=/dev/random bs=4 count=1 >> $TMP.src 2> /dev/null || fail "pb dd 3"
dd if=/dev/zero   bs=1 count=1 >> $TMP.src 2> /dev/null || fail "pb dd 4"
dd if=/dev/random bs=7 count=1 >> $TMP.src 2> /dev/null || fail "pb dd 5"
dd if=/dev/zero   bs=1 count=1 >> $TMP.src 2> /dev/null || fail "pb dd 6"
dd if=/dev/random bs=9 count=1 >> $TMP.src 2> /dev/null || fail "pb dd 7"
$PROG 8 $TMP.src > $TMP.out 2> $TMP.err || fail "erreur rencontrée"
verifier_pas_de_sortie $TMP
reproduire_et_comparer 8 $TMP.src
echo OK

annoncer_test 3.6 "fichier de sortie correct"
nettoyer
# créer un fichier de sortie bidon plus grand que le fichier de sortie attendu
dd if=/dev/random bs=7001 count=1 >> $TMP.src.rot 2> /dev/null || fail "pb dd 1"
# fichier de test
dd if=/dev/random bs=12 count=1 >> $TMP.src 2> /dev/null || fail "pb dd 2"
$PROG 8 $TMP.src > $TMP.out 2> $TMP.err || fail "erreur rencontrée"
verifier_pas_de_sortie $TMP
reproduire_et_comparer 8 $TMP.src
echo OK

##############################################################################
# Tests avec des grands fichiers

annoncer_test 4.1 "grand fichier et n petit"
nettoyer
dd if=/dev/random bs=49999 count=1 > $TMP.src 2> /dev/null || fail "pb dd 1"
$PROG 5 $TMP.src > $TMP.out 2> $TMP.err || fail "erreur rencontrée"
verifier_pas_de_sortie $TMP
reproduire_et_comparer 5 $TMP.src
echo OK

annoncer_test 4.2 "grand fichier et n grand"
nettoyer
dd if=/dev/random bs=48259 count=1 > $TMP.src 2> /dev/null || fail "pb dd 1"
$PROG 48259 $TMP.src > $TMP.out 2> $TMP.err || fail "erreur rencontrée"
verifier_pas_de_sortie $TMP
reproduire_et_comparer 48259 $TMP.src
echo OK

annoncer_test 4.3 "très grand fichier et double rotation (rapide)"
# si c'est lent, c'est qu'il y a un problème...
nettoyer
T=32452843
N=48259
dd if=/dev/random bs=$T count=1 > $TMP.src 2> /dev/null || fail "pb dd 1"
$PROG $N $TMP.src > $TMP.out 2> $TMP.err || fail "erreur rencontrée"
verifier_pas_de_sortie $TMP
N2=$((T -N ))
$PROG $N2 $TMP.src.rot > $TMP.out 2> $TMP.err || fail "erreur rencontrée"
verifier_pas_de_sortie $TMP
cmp $TMP.src $TMP.src.rot.rot		|| fail "$TMP.src != $TMP.src.rot.rot"
echo OK

##############################################################################
# Tests avec valgrind

annoncer_test 5.1 "valgrind"
nettoyer
cat <<EOF > $TMP.src
abcd
efghij
kl
EOF
tester_valgrind $PROG 5 $TMP.src > $TMP.out 2> $TMP.err || fail "erreur"
echo OK

nettoyer
echo "Tests ok"

exit 0

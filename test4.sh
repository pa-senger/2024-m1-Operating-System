#!/bin/sh

PROG=${PROG:=./prodscal}		# chemin de l'exécutable

TMP=${TMP:=/tmp/test}			# chemin des logs de test

#
# Script Shell de test de l'exercice 4
# Utilisation : sh ./test4.sh
#
# Si tout se passe bien, le script doit afficher "Tests ok" à la fin
# Dans le cas contraire, le nom du test échoué s'affiche.
# Les fichiers sont laissés dans /tmp/test* en cas d'échec, vous
# pouvez les examiner.
# Pour avoir plus de détails sur l'exécution du script, vous pouvez
# utiliser :
#	sh -x ./test4.sh
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
    printf "%s" "$str" | wc -m
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

# Vérifie que le résultat est bien celui attendu
# $1 = fichier de sortie
# $2 = résultat attendu
verifier_resultat ()
{
    [ $# != 2 ] && fail "ERREUR SYNTAXE verifier_resultat"
    local out="$1" att="$2"
    res=$(cat "$out")
    [ x"$res" != x"$att" ] && fail "Résultat ($res) != attendu ($att)"
}

# Vérifie que le résultat est bien celui attendu
# $1 = fichier de sortie
# $2 = série des X (avec les fins de ligne laissés par la commande seq)
# $3 = série des Y (avec les fins de ligne laissés par la commande seq)
calculer_et_verifier_resultat ()
{
    [ $# != 3 ] && fail "ERREUR SYNTAXE calculer_et_verifier_resultat"
    local out="$1" x="$2" y="$3"
    local att i xi yi

    att=0
    i=1
    for xi in $x
    do
	yi=$(echo "$y" | sed -n "${i} { p ; q }")
	att=$((att + xi*yi))
	i=$((i+1))
    done
    verifier_resultat "$out" "$att"
}

# retourne le numéro du dernier processus créé (cette fonction utilise 2 ps)
cur_ps ()
{
    echo blablabla > /dev/null &
    wait
    echo $!
}

# vérifie le nb minimum de processus depuis le pid indiqué
# $1 = nb de processus minimum
# $2 = pid avant l'exéction de la commande
verifier_nb_processus ()
{
    [ $# != 2 ] && fail "ERREUR SYNTAXE verifier_nb_processus"
    local nprocmin="$1" pid_avant="$2"
    local pid_apres nproc

    pid_apres=$(cur_ps)
    nproc=$((pid_apres - pid_avant - 2))
    [ $nproc -lt $nprocmin ] \
	&& fail "pas assez de processus ($nproc au lieu de $nprocmin)"
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
    [ $r != 0 ]  && fail "erreur programme (code=$r) avec valgrind (cf $TMP.*)"
    return $r
}

# Supprimer les fichiers restant d'une précédente exécution
nettoyer ()
{
    rm -rf $TMP*
}

nettoyer

##############################################################################
# Vérification des arguments

# Quelques cas simples pour commencer

# Est-ce que les messages d'erreur sont bien envoyés sur la sortie d'erreur ?
annoncer_test 1.1 "messages d'erreur sur la sortie d'erreur"
$PROG -1 > $TMP.out 2> $TMP.err
est_vide $TMP.err && fail "message d'erreur devrait être sur stderr"
est_vide $TMP.out || fail "rien ne devrait être affiché sur stdout"
echo OK

# Est-ce que le code de retour renvoyé (via exit) indique bien une
# valeur différente de 0 en cas d'erreur ?
annoncer_test 1.2 "code de retour en cas d'erreur"
$PROG -1      > $TMP.out 2> $TMP.err
[ $? = 0 ] && fail "en cas d'erreur, il faut utiliser exit(v) avec v!=0"
echo OK

# Test des arguments : nombre invalide
annoncer_test 1.3 "nombre d'arguments invalide (1)"
$PROG 1       > $TMP.out 2> $TMP.err && fail "1 argument"
verifier_usage $TMP.err
echo OK

# Test des arguments : nombre invalide
annoncer_test 1.4 "nombre d'arguments invalide (2)"
$PROG 1 2    > $TMP.out 2> $TMP.err && fail "2 args"
verifier_usage $TMP.err
echo OK

# Test des arguments : nombre invalide
annoncer_test 1.5 "nombre d'arguments invalide (6)"
$PROG 1 2 3 4 5 6 > $TMP.out 2> $TMP.err && fail "2 args"
verifier_usage $TMP.err
echo OK

# Test des arguments : nb de processus = 0
annoncer_test 1.6 "nb de processus invalide"
$PROG 0 1 2         > $TMP.out 2> $TMP.err && fail "nb proc = 0"
verifier_stderr $TMP
echo OK

##############################################################################
# Fonctionnalités basiques

annoncer_test 2.1 "calcul ultra simple, un seul processus"
pid=$(cur_ps)
$PROG 1 2 3     > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_nb_processus 3 $pid
verifier_resultat $TMP.out 6
echo OK

annoncer_test 2.2 "calcul simple, un seul processus"
$PROG 1 2 3 4 5 > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_resultat $TMP.out 23
echo OK

annoncer_test 2.3 "grand nombre de valeurs, un seul processus"
X=$(seq 5 100)
Y=$(seq 72 -1 -23)
$PROG 1 $X $Y   > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_resultat $TMP.out 49760
echo OK

annoncer_test 2.4 "calcul ultra simple, deux processus"
pid=$(cur_ps)
$PROG 2 2 3     > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_nb_processus 4 $pid
verifier_resultat $TMP.out 6
echo OK

annoncer_test 2.5 "calcul simple, deux processus"
$PROG 2 2 3 4 5 > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_resultat $TMP.out 23
echo OK

annoncer_test 2.6 "grand nombre de valeurs, deux processus"
X=$(seq 5 100)
Y=$(seq 72 -1 -23)
$PROG 2 $X $Y   > $TMP.out 2> $TMP.err || fail "code de retour != 0"
calculer_et_verifier_resultat $TMP.out "$X" "$Y"
echo OK

annoncer_test 2.7 "calcul ultra simple, 100 processus"
pid=$(cur_ps)
$PROG 100 2 3     > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_nb_processus 102 $pid
verifier_resultat $TMP.out 6
echo OK

annoncer_test 2.8 "100 couples, 10 processus"
X=$(seq 80 -1 -20)
Y=$(seq -20 1 80)
pid=$(cur_ps)
$PROG 10 $X $Y   > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_nb_processus 12 $pid
calculer_et_verifier_resultat $TMP.out "$X" "$Y"
echo OK

##############################################################################
# Gestion mémoire

annoncer_test 3.1 "valgrind"
tester_valgrind $PROG 1 2 3 4 5
echo OK

nettoyer
echo "Tests ok"
exit 0

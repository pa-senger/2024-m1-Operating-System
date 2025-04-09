#!/bin/sh

PROG=${PROG:=./poly}			# chemin de l'exécutable

TMP=${TMP:=/tmp/test}			# chemin des logs de test

#
# Script Shell de test de l'exercice 5
# Utilisation : sh ./test5.sh
#
# Si tout se passe bien, le script doit afficher "Tests ok" à la fin
# Dans le cas contraire, le nom du test échoué s'affiche.
# Les fichiers sont laissés dans /tmp/test* en cas d'échec, vous
# pouvez les examiner.
# Pour avoir plus de détails sur l'exécution du script, vous pouvez
# utiliser :
#	sh -x ./test5.sh
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

# vérifier l'existence des programmes cités dans les variables PROG*
verifier_prog ()
{
    [ $# != 0 ] && fail "ERREUR SYNTAXE verifier_prog"
    local listevars v prog
    listevars=$(set | sed -n 's/^\(PROG[^=]*\)=.*/\1/p')
    for v in $listevars
    do
	prog=$(eval echo \$$v)
	if [ ! -x "$prog" ]
	then
	    echo "Exécutable '$prog' (cité dans la variable $v) non trouvé" >&2
	    exit 1
	fi
    done
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
# $2 = nb d'itérations (k)
# $3 et suivants = coefficients du polynôme
verifier_resultat ()
{
    [ $# -lt 3 ] && fail "ERREUR SYNTAXE verifier_resultat"
    local out="$1" k="$2"
    local coeff x p ai
    local att="$TMP.att" diff="$TMP.diff"
    shift 2

    # calcul du polynôme par la méthode de Horner => inverser les coefficients
    coeff=""
    for ai
    do
	coeff="$ai $coeff"
    done

    for x in $(seq 1 $k)
    do
	p=0
	for ai in $coeff
	do
	    p=$(( (p*x) + ai ))
	done
	echo $p
    done > "$att"

    diff "$out" "$att" > "$diff" || fail "$out != $att, cf $diff"
}

# teste si un processus existe
# $1 = pid
ps_existe ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE ps_existe"

    local pid="$1"
    local r

    if kill -0 $pid 2> /dev/null
    then r=0
    else r=1
    fi
    return $r
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
    chmod -R +w $TMP* 2> /dev/null
    rm -rf $TMP*
}

verifier_prog
nettoyer

##############################################################################
# Vérification des arguments

# Quelques cas simples pour commencer

# Est-ce que les messages d'erreur sont bien envoyés sur la sortie d'erreur ?
annoncer_test 1.1 "messages d'erreur sur la sortie d'erreur"
$PROG 1 > $TMP.out 2> $TMP.err
est_vide $TMP.err && fail "message d'erreur devrait être sur stderr"
est_vide $TMP.out || fail "rien ne devrait être affiché sur stdout"
echo OK

# Est-ce que le code de retour renvoyé (via exit) indique bien une
# valeur différente de 0 en cas d'erreur ?
annoncer_test 1.2 "code de retour en cas d'erreur"
$PROG 1      > $TMP.out 2> $TMP.err
[ $? = 0 ] && fail "en cas d'erreur, il faut utiliser exit(v) avec v!=0"
echo OK

# Test des arguments : nombre invalide
annoncer_test 1.3 "nombre d'arguments invalide"
nettoyer
$PROG 1 $TMP.poly  > $TMP.out 2> $TMP.err && fail "2 argument"
verifier_usage $TMP.err
echo OK

# Test des arguments : nb d'itérations = 0
annoncer_test 1.4 "nb d'itérations (k) invalide"
nettoyer
$PROG 0 $TMP.poly 0 > $TMP.out 2> $TMP.err && fail "k = 0"
verifier_stderr $TMP
echo OK

# Test des arguments : fichier invalide
annoncer_test 1.5 "fichier invalide (répertoire)"
nettoyer
mkdir $TMP.d
$PROG 1 $TMP.d 0 > $TMP.out 2> $TMP.err && fail "fichier = répertoire"
verifier_stderr $TMP
echo OK

# Test des arguments : fichier inaccessible
annoncer_test 1.6 "fichier inaccessible"
nettoyer
touch $TMP.poly
chmod 0 $TMP.poly
$PROG 1 $TMP.poly 0 > $TMP.out 2> $TMP.err && fail "permissions sur fichier"
verifier_stderr $TMP
echo OK

##############################################################################
# Fonctionnalités basiques

annoncer_test 2.1 "polynôme de degré 0, 1 itération"
nettoyer
pid=$(cur_ps)
$PROG 1 $TMP.poly 3 > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_nb_processus 3 $pid		# père + fils + petit-fils pour expr
verifier_resultat $TMP.out 1 3
echo OK

annoncer_test 2.2 "polynôme de degré 4, 1 itération"
nettoyer
pid=$(cur_ps)
$PROG 1 $TMP.poly 2 3 4 5 6 > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_nb_processus 11 $pid		# père + 5*fils + 5 expr
verifier_resultat $TMP.out 1 2 3 4 5 6
echo OK

annoncer_test 2.3 "polynôme de degré 2, 5 itérations"
nettoyer
pid=$(cur_ps)
$PROG 5 $TMP.poly 4 3 2 > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_nb_processus 19 $pid		# père + 3 * fils + 5*3 expr
verifier_resultat $TMP.out 5 4 3 2
echo OK

annoncer_test 2.4 "polynôme de degré 3, 100 itérations"
pid=$(cur_ps)
$PROG 100 $TMP.poly 4 -3 2 -1 > $TMP.out 2> $TMP.err \
			|| fail "code de retour != 0"
verifier_nb_processus 405 $pid		# père + 4*fils + 4*100 expr
verifier_resultat $TMP.out 100 4 -3 2 -1
echo OK

annoncer_test 2.5 "suppression du fichier"
nettoyer
$PROG 1 $TMP.poly 1 > $TMP.out 2> $TMP.err || fail "code de retour != 0"
[ -f $TMP.poly ] && fail "fichier $TMP.poly non supprimé"
echo OK

##############################################################################
# Fonctionnalités plus avancées

annoncer_test 3.1 "détection de la terminaison prématurée d'un fils"
# compléter le chemin de PROG s'il ne contient pas de "/"
if echo $PROG | grep -q /
then P=$PROG
else P=./$PROG
fi
mkdir $TMP.bin
(
    echo "#!/bin/sh"
    echo "echo 'erreur fabriquée avec une fausse commande expr' >&2"
    echo "echo 'on est passé par là' > $TMP.bin/trace"
    echo "exit 1"
) > $TMP.bin/expr
chmod +x $TMP.bin/expr
PATH=$TMP.bin $P 2 $TMP.poly 1 2 3 > $TMP.out 2> $TMP.err \
			    && fail "erreur avec fausse commande 'expr'"
# vérifier qu'on a bien utilisé notre fausse commande "expr"
[ -f $TMP.bin/trace ] || fail "Pas de trace de l'exécution de notre expr"
echo OK

annoncer_test 3.2 "fichier correctement initialisé"
nettoyer
# avec un polynoôme de degré 1, on devrait avoir 4*4 + 2*4 octets
dd if=/dev/random of=$TMP.poly bs=1000 count=1 2> /dev/null > /dev/null
# on démarre une commande très lente
$PROG 10000 $TMP.poly 1 2 > $TMP.out 2> $TMP.err &
pid=$!
sleep 0.1
kill -TERM $pid
sleep 0.1
ps_existe $pid && fail "processus père non terminé par SIGTERM"
[ -f $TMP.poly ] || fail "fichier $TMP.poly non trouvé"
taille=$(cat $TMP.poly | wc -c)
[ $taille != 24 ] && fail "taille de $TMP.poly = $taille octets (attendu 24)"
echo OK


##############################################################################
# Gestion mémoire

annoncer_test 4.1 "valgrind"
# attention : valgrind vérifie également les fils : si de la mémoire
# est allouée dans le père et non libérée dans le fils, cela génère
# une erreur
tester_valgrind $PROG 2 $TMP.poly 2 3 4 5
echo OK

nettoyer
echo "Tests ok"
exit 0

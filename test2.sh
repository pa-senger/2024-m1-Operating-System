#!/bin/sh

PROG=${PROG:=./infos}			# chemin de l'exécutable

TMP=${TMP:=/tmp/test}			# chemin des logs de test

#
# Script Shell de test de l'exercice 2
# Utilisation : sh ./test2.sh
#
# Si tout se passe bien, le script doit afficher "Tests ok" à la fin
# Dans le cas contraire, le nom du test échoué s'affiche.
# Les fichiers sont laissés dans /tmp/test* en cas d'échec, vous
# pouvez les examiner.
# Pour avoir plus de détails sur l'exécution du script, vous pouvez
# utiliser :
#	sh -x ./test2.sh
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

reproduire_et_comparer ()
{
    [ $# != 2 ] && fail "ERREUR SYNTAXE reproduire_et_comparer"
    local out="$1" rep="$2"

    local nlignes nlettres
    local att outsansespace

    att="$out.att"		# fichier attendu par le script de test
    nosp="$out.nosp"		# fichier de sortie sans chemin avec ' '

    # retirer les noms avec des espaces que le shell ne gère pas bien
    grep -v '/.* ' "$out" > "$nosp"

    # -H : ne suit pas les liens symboliques
    find -H "$rep" -type f -print \
	| grep -v '/.* ' \
	| xargs ls -i 2> /dev/null \
	| sort -n \
	| while read ino chemin
	    do
		taille=$(wc -c < "$chemin")
		nlignes=$(LC_ALL=C tr -d -c '\n' < "$chemin" | wc -c)
		nlettres=$(LC_ALL=C tr -d -c A-Za-z < "$chemin" | wc -c)
		echo $ino $taille $nlignes $nlettres $chemin
	    done > $att

    # comparer le résultat du programme avec le résultat attendu
    diff "$att" "$nosp" > "$out.diff"	|| fail "$nosp != $att (cf $out.diff)"
}

# Crée un fichier de contenu de taille donnée et de contenu aléatoire
# $1 = chemin
# $2 = taille en octets
creer_fichier ()
{
    [ $# != 2 ] && fail "ERREUR SYNTAXE creer_fichier"
    local chemin="$1" taille=$2
    dd if=/dev/urandom bs=$taille count=1 of=$chemin 2> /dev/null
}

# Crée une arborescence minimale avec 5 fichiers :
#	racine
#	 |- d1
#	 |   |-d11
#	 |   |  `-a
#	 |   |  `-b
#	 |   `-d12
#	 |      `-c
#	 |- d2
#	 |   `-d21
#	 |      `-d
#	 `- d3
#	     `-d31
#	        `-e
# $1 = racine
creer_arbo ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE creer_arbo"
    local racine="$1"

    mkdir -p $racine/d1/d11 $racine/d1/d12 $racine/d2/d21 $racine/d3/d31
    creer_fichier $racine/d1/d11/a 16383
    creer_fichier $racine/d1/d11/b 8117
    creer_fichier $racine/d1/d12/c 23071
    creer_fichier $racine/d2/d21/d 2999
    creer_fichier $racine/d3/d31/e 3407
}

# Supprimer les fichiers restant d'une précédente exécution
nettoyer ()
{
    chmod -R +rwx $TMP* 2> /dev/null
    rm -rf $TMP*
}


nettoyer

##############################################################################
# Vérification des arguments

# Quelques cas simples pour commencer

# Est-ce que les messages d'erreur sont bien envoyés sur la sortie d'erreur ?
annoncer_test 1.1 "messages d'erreur sur la sortie d'erreur"
$PROG > $TMP.out 2> $TMP.err
est_vide $TMP.err && fail "message d'erreur devrait être sur stderr"
est_vide $TMP.out || fail "rien ne devrait être affiché sur stdout"
echo OK

# Est-ce que le code de retour renvoyé (via exit) indique bien une
# valeur différente de 0 en cas d'erreur ?
annoncer_test 1.2 "code de retour en cas d'erreur"
$PROG 2> $TMP.err
[ $? = 0 ] && fail "en cas d'erreur, il faut utiliser exit(v) avec v!=0"
echo OK

# Test des arguments : nombre invalide
annoncer_test 1.3 "nombre d'arguments invalide (0)"
$PROG 2> $TMP.err         && fail "0 argument => erreur => code de retour != 0"
verifier_usage $TMP.err
echo OK

# Test des arguments : nombre invalide
annoncer_test 1.4 "nombre d'arguments invalide (2)"
$PROG . . 2> $TMP.err     && fail "2 args => erreur => code de retour != 0"
verifier_usage $TMP.err
echo OK

# Le répertoire n'existe pas
annoncer_test 1.5 "répertoire inexistant"
rm -f $TMP.nonexistant		# on est vraiment sûr qu'il n'existe pas
$PROG $TMP.nonexistant > $TMP.out 2> $TMP.err && fail "devrait détecter une erreur"
verifier_stderr $TMP
echo OK

# Le répertoire n'est pas un répertoire
annoncer_test 1.6 "argument pas un répertoire"
creer_fichier $TMP.fichier 127
$PROG $TMP.fichier > $TMP.out 2> $TMP.err && fail "devrait détecter une erreur"
verifier_stderr $TMP
echo OK

# Le répertoire n'est pas lisible
annoncer_test 1.7 "répertoire non lisible"
mkdir $TMP.d
creer_fichier $TMP.fichier 127
chmod 0400 $TMP.d
$PROG $TMP.fichier > $TMP.out 2> $TMP.err && fail "devrait détecter une erreur"
verifier_stderr $TMP
echo OK

##############################################################################
# Arborescence basique

nettoyer

annoncer_test 2.1 "arborescence vide"
nettoyer
mkdir $TMP.d
$PROG $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour devrait être nul"
est_vide $TMP.err	|| fail "rien ne devrait être affiché sur stderr"
est_vide $TMP.out	|| fail "rien ne devrait être affiché sur stdout"
echo OK

annoncer_test 2.2 "arborescence simple"
nettoyer
mkdir $TMP.d
creer_fichier $TMP.d/x 4095
creer_fichier $TMP.d/y 8193
creer_fichier $TMP.d/z 1025
$PROG $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour devrait être nul"
[ $(wc -l < $TMP.out) = 3 ] || fail "mauvais nombre de fichiers trouvés"
reproduire_et_comparer $TMP.out $TMP.d
echo OK

annoncer_test 2.3 "arborescence complexe"
nettoyer
creer_arbo $TMP.d
$PROG $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour devrait être nul"
[ $(wc -l < $TMP.out) = 5 ] || fail "mauvais nombre de fichiers trouvés"
reproduire_et_comparer $TMP.out $TMP.d
echo OK

annoncer_test 2.4 "traitement des liens symboliques"
nettoyer
creer_arbo $TMP.d
ln -s $TMP.d/d2/d21/d $TMP.d/x
$PROG $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour devrait être nul"
# on ne vérifie que le nombre de fichiers trouvés : il doit y en avoir 5
[ $(wc -l < $TMP.out) = 6 ] && fail "lien symbolique non ignoré"
[ $(wc -l < $TMP.out) != 5 ] && fail "nombre de fichiers incorrect"
echo OK

##############################################################################
# Cas aux limites

annoncer_test 3.1 "chemin trop grand"
nettoyer
CHEMIN_MAX=128
# créer un chemin de taille "max" octets
max=$CHEMIN_MAX
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
# un chemin de 128 octets, ça passe
echo foo > $correct
$PROG $TMP.d > $TMP.out 2> $TMP.err || fail "il ne devrait pas y avoir d'erreur"
est_vide $TMP.err		|| fail "$TMP.err non vide"

# un chemin de 129 octets, ça ne passe plus
rm -f $correct
echo bla > $troplong
$PROG $TMP.d  > $TMP.out 2> $TMP.err && fail "il devrait y avoir une erreur"
verifier_stderr $TMP
echo OK

annoncer_test 3.2 "détecter les erreurs en profondeur"
nettoyer
creer_arbo $TMP.d
chmod 0 $TMP.d/d2/d21/d
$PROG $TMP.d > $TMP.out 2> $TMP.err && fail "devrait détecter une erreur"
est_vide $TMP.err	&& fail "il devrait y avoir un message sur stderr"
echo OK

annoncer_test 3.3 "grande arborescence (lent)"
nettoyer
$PROG /usr/include > $TMP.out 2> $TMP.err || fail "erreur détectée"
est_vide $TMP.err	|| fail "il ne doit rien y avoir sur stderr"
reproduire_et_comparer $TMP.out /usr/include
echo OK

##############################################################################
# Tests avec valgrind

annoncer_test 4.1 "valgrind"
nettoyer
creer_arbo $TMP.d
tester_valgrind $PROG $TMP.d > $TMP.out 2> $TMP.err || fail "erreur"
echo OK

nettoyer
echo "Tests ok"
exit 0

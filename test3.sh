#!/bin/sh

PROG=${PROG:=./majus}			# chemin de l'exécutable

TMP=${TMP:=/tmp/test}			# chemin des logs de test

# quelques fichiers qui sont censés exister sur tous les systèmes
EXEMPLES="
    /usr/include/stdio.h
    /usr/include/stdlib.h
    /usr/include/unistd.h
    /usr/include/string.h
    /usr/include/fcntl.h
"

#
# Script Shell de test de l'exercice 3
# Utilisation : sh ./test3.sh
#
# Si tout se passe bien, le script doit afficher "Tests ok" à la fin
# Dans le cas contraire, le nom du test échoué s'affiche.
# Les fichiers sont laissés dans /tmp/test* en cas d'échec, vous
# pouvez les examiner.
# Pour avoir plus de détails sur l'exécution du script, vous pouvez
# utiliser :
#	sh -x ./test3.sh
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

# retourne le numéro du dernier processus créé (cette fonction utilise 2 ps)
cur_ps ()
{
    echo blablabla > /dev/null &
    wait
    echo $!
}

# crée une arborescence simple
creer_petite_arbo ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE creer_petite_arbo"
    local src="$1"
    
    mkdir $src
    cp $EXEMPLES $src
}

# crée une arborescence pas simple
creer_grande_arbo ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE creer_grande_arbo"
    local src="$1"
    
    local dirs="$src
		    $src/d1
			$src/d1/d11
			$src/d1/d12
			    $src/d1/d12/d121
			    $src/d1/d12/d121/d1211
		    $src/d2
			$src/d2/d21
			$src/d2/d22
		"
    local d

    mkdir -p $dirs
    for d in $dirs
    do
	cp $EXEMPLES $d
    done
}

# reproduit le résultat attendu et compare avec le résultat
# $1 = répertoire source
# $2 = répertoire destination
reproduire_et_comparer ()
{
    [ $# != 2 ] && fail "ERREUR SYNTAXE reproduire_et_comparer"
    local src="$1" dst="$2"
    local att="$dst.att"	# arborescence attendue (= de référence)
    local diff="$dst.diff"
    local fin fout

    # reproduire les répertoires
    find $src -type d -print | sed "s:$src:$att:" | xargs mkdir -p

    # parcourir les fichiers et les traduire
    find $src -type f -print \
	| while read fin
	    do
		fout=$(echo "$fin" | sed "s:$src/:$att/:")
		tr a-z A-Z < "$fin" > "$fout"
	    done

    # comparer
    diff -r "$dst" "$att" > "$diff" || fail "$dst != $att, cf $diff"
}

# vérifie les permissions sur un fichier ou un répertoire
# $1 = permissions (au format "rwxrwxrwx")
# $2 = fichier ou répertoire
verifier_permissions ()
{
    [ $# != 2 ] && fail "ERREUR SYNTAXE verifier_permissions"
    local perm="$1" fichier="$2"

    local p
    # ls -l, puis suppression du premier caractère ('d' ou '-') et
    # de tout ce qui suit les permissions
    # ls -d pour afficher le répertoire et non son contenu
    p=$(ls -ld "$fichier" | sed -e 's/^.//' -e 's/ .*//')
    [ x"$p" = x"$perm" ] || fail "$fichier : '$p' incorrect, devrait être $perm"
}

# Chercher la commande "time" POSIX et la mettre dans la variable TIME
commande_time ()
{
    TIME=$(command -v -p time)
    if [ "$TIME" = "" ]
    then echo "Commande 'time' non trouvée" >&2  ; exit 1 ;
    fi
}

# récupère la durée en ms à partir de /usr/bin/time -p (POSIX)
# $1 = nom du fichier contenant le résultat de time -p
duree ()
{
    [ $# != 1 ] && fail "ERREUR SYNTAXE duree"

    local fichier="$1"
    local duree_s

    duree_s=$(sed -n 's/real *//p' "$fichier" | sed 's/,/\./')
    echo "$duree_s*1000" | bc | sed 's/\..*//'
}

# vérifie que le temps d'exécution est dans l'intervalle indiqué
# $1 = durée mesurée en ms (résultat de la fonction duree)
# $2 = durée attendue min
# $3 = durée attendue max
verifier_duree ()
{
    [ $# != 3 ] && fail "ERREUR SYNTAXE verifer_duree"

    local duree_ms="$1" min="$2" max="$3"

    if [ "$duree_ms" -lt "$min" ] || [ "$duree_ms" -gt "$max" ]
    then fail "durée incorrecte ($duree_ms ms) pas dans [$min,$max]"
    fi
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
    chmod -R +rwx $TMP* 2> /dev/null
    rm -rf $TMP*
}

nettoyer
commande_time

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
$PROG         > $TMP.out 2> $TMP.err
[ $? = 0 ] && fail "en cas d'erreur, il faut utiliser exit(v) avec v!=0"
echo OK

# Test des arguments : nombre invalide
annoncer_test 1.3 "nombre d'arguments invalide (1)"
mkdir $TMP.s
$PROG $TMP.s  > $TMP.out 2> $TMP.err && fail "1 argument"
verifier_usage $TMP.err
echo OK

# Test des arguments : nombre invalide
annoncer_test 1.4 "nombre d'arguments invalide (3)"
$PROG $TMP.s $TMP.d $TMP.d  > $TMP.out 2> $TMP.err && fail "3 args"
verifier_usage $TMP.err
echo OK

# Test des arguments : répertoire source inexistant
annoncer_test 1.5 "répertoire source inexistant"
nettoyer
# attention : piège... ceci n'est pas un cas particulier
$PROG $TMP.s $TMP.d > $TMP.out 2> $TMP.err && fail "$TMP.s inexistant"
verifier_stderr $TMP "répertoire source inexistant"
echo OK

# Test des arguments : répertoire source n'est pas un répertoire
annoncer_test 1.6 "répertoire source n'est pas un répertoire"
nettoyer
touch $TMP.s
# attention : piège... ceci n'est pas un cas particulier
$PROG $TMP.s $TMP.d > $TMP.out 2> $TMP.err && fail "$TMP.s inexistant"
verifier_stderr $TMP "répertoire source n'est pas un répertoire"
echo OK

##############################################################################
# Fonctionnalités basiques

annoncer_test 2.1 "arborescence simple"
nettoyer
mkdir $TMP.s
cp $EXEMPLES $TMP.s
$PROG $TMP.s $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_pas_de_sortie $TMP
reproduire_et_comparer $TMP.s $TMP.d
echo OK

annoncer_test 2.2 "arborescence moins simple"
nettoyer
creer_grande_arbo $TMP.s
$PROG $TMP.s $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_pas_de_sortie $TMP
reproduire_et_comparer $TMP.s $TMP.d
echo OK

annoncer_test 2.3 "utilisation de chemins relatifs"
nettoyer
creer_grande_arbo $TMP.s
if echo $PROG | grep -q '^/'
then PROGABS=$PROG
else PROGABS=$(pwd)/$PROG
fi
# $TMP.d en relatif par rapport à $TMP.s
RELd=$(echo $TMP.d | sed 's:.*/:../:')
(
cd $TMP.s
$PROGABS . $RELd > $TMP.out 2> $TMP.err || fail "code de retour != 0"
) || exit 1
verifier_pas_de_sortie $TMP
reproduire_et_comparer $TMP.s $TMP.d
echo OK

annoncer_test 2.4 "répertoire de destination existant"
nettoyer
creer_petite_arbo $TMP.s
mkdir $TMP.d
$PROG $TMP.s $TMP.d > $TMP.out 2> $TMP.err && fail "code de retour = 0"
verifier_stderr $TMP "répertoire destination existant"
# vérifier que le code d'erreur est bien restitué
grep -q "File exists" $TMP.err 
echo OK

annoncer_test 2.5 "ignorer les liens symboliques"
nettoyer
creer_petite_arbo $TMP.s
ln -s $TMP.s/stdio.h $TMP.s/lien
$PROG $TMP.s $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_pas_de_sortie $TMP
# vérifier que le lien ne figure pas dans la destination
[ -f $TMP.d/lien ] && fail "$TMP.d ne devrait pas être présent"
# vérification supplémentaire : pas plus de fichiers que de fichiers exemples
nex=$(echo "$EXEMPLES" | grep '[a-z]' | wc -l)
nfic=$(find $TMP.d -type f -print | wc -l)
[ $nex = $nfic ] || fail "mauvais nb de fichiers dans $TMP.d"
echo OK

annoncer_test 2.6 "restauration des permissions sur les fichiers"
nettoyer
creer_grande_arbo $TMP.s
chmod 600 $TMP.s/stdio.h
chmod 721 $TMP.s/d1/stdio.h
chmod 666 $TMP.s/d1/d11/stdio.h
chmod 777 $TMP.s/d1/d12/stdio.h
$PROG $TMP.s $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_pas_de_sortie $TMP
verifier_permissions rw------- $TMP.s/stdio.h
verifier_permissions rwx-w---x $TMP.s/d1/stdio.h
verifier_permissions rw-rw-rw- $TMP.s/d1/d11/stdio.h
verifier_permissions rwxrwxrwx $TMP.s/d1/d12/stdio.h
echo OK

annoncer_test 2.7 "restauration des permissions sur les répertoires"
nettoyer
creer_grande_arbo $TMP.s
chmod 700 $TMP.s
chmod 777 $TMP.s/d1
chmod 721 $TMP.s/d1/d11
$PROG $TMP.s $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_pas_de_sortie $TMP
verifier_permissions rwx------ $TMP.s
verifier_permissions rwxrwxrwx $TMP.s/d1
verifier_permissions rwx-w---x $TMP.s/d1/d11
echo OK

##############################################################################
# Processus et parallélisme

annoncer_test 3.1 "nombre de processus"
nettoyer
creer_grande_arbo $TMP.s
pid1=$(cur_ps)
$PROG $TMP.s $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour != 0"
pid2=$(cur_ps)
# on a déjà fait tous les tests sur les données, pas la peine de les refaire
# il doit y avoir au minimum 1 processus par fichier
nfic=$(find $TMP.s -type f -print | wc -l)
nproc=$((pid2 - pid1 - 2*2))		# cur_ps génère 2 processus
[ $nproc -le $nfic ] || fail "pas assez de processus ($nproc au lieu de $nfic)"
echo OK

# on a besoin du chemin absolu de la commande sleep
SLEEP=$(command -v -p sleep)
if [ "$SLEEP" = "" ]
then echo "Commande 'sleep' non trouvée" >&2  ; exit 1 ;
fi
# compléter le chemin de PROG s'il ne contient pas de "/"
if echo $PROG | grep -q /
then P=$PROG
else P=./$PROG
fi

annoncer_test 3.2 "exécution en parallèle (durée = 1 sec)"
nettoyer
mkdir $TMP.s
cp $EXEMPLES $TMP.s
# fabriquer une fausse commande "tr" dans $TMP.bin
mkdir $TMP.bin
(echo "#!/bin/sh" ; echo "$SLEEP 1") > $TMP.bin/tr
chmod +x $TMP.bin/tr
PATH=$TMP.bin $TIME -p $P $TMP.s $TMP.d > $TMP.out 2> $TMP.time \
			    || fail "erreur avec fausse commande 'tr'"
# vérifier qu'on n'a pas utilisé la vraie commande "tr"
for i in $EXEMPLES
do
    f=$(echo $i | sed 's:/usr/include::')
    [ $(wc -c < $TMP.d/$f) != 0 ] && fail "cmd 'tr' pas cherchée dans \$PATH"
done
# vérifier la durée totale (avec une tolérance de [-100,+300] ms)
duree=$(duree $TMP.time)
verifier_duree $duree 900 1300
echo OK


annoncer_test 3.3 "arrêt à la première erreur"
nettoyer
creer_grande_arbo $TMP.s
# fabriquer une fausse commande "tr" dans $TMP.bin qui renvoie une erreur
# dès le deuxième appel (approximativement, il y a un pb de concurrence,
# mais il n'est pas grave pour ce qu'on veut faire ici
echo 0 > $TMP.cpt
mkdir $TMP.bin
# cat <<-FINtr > $TMP.bin/tr
# 	#!/bin/sh
# 	n=\$(cat $TMP.cpt)
# 	echo \$((n+1)) > $TMP.cpt
# 	if [ x"\$n" = x0 ]
# 	then exit 0
# 	else sleep 1 ; exit 1
# 	fi
# FINtr
cat <<-FINtr >$TMP.bin/tr
    #!/bin/sh
    n=\$(cat $TMP.cpt)
    echo \$((n+1)) > $TMP.cpt
    if [ x"\$n" = x0 ]
    then
        # Acquire a lock on the counter file
        flock -x $TMP.cpt sleep 1
        exit 0
    else
        sleep 1 ; exit 1
    fi
FINtr
chmod +x $TMP.bin/tr
PATH=$TMP.bin:$PATH $TIME -p $P $TMP.s $TMP.d > $TMP.out 2> $TMP.time \
			    && fail "erreur avec fausse commande 'tr'"
# on doit avoir au maximum une durée de 1 seconde
duree=$(duree $TMP.time)
verifier_duree $duree 900 1300
echo OK

##############################################################################
# Cas aux limites


annoncer_test 4.1 "longueur des chemins"
nettoyer
creer_grande_arbo $TMP.ss
CHEMIN_MAX=128
# créer un chemin de taille "max" octets
max=$CHEMIN_MAX
d=$TMP.ss/d1/d12/d121/d1211	# on part du répertoire le plus long
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
# là, ça devrait passer
cp /usr/include/stdio.h $correct
$PROG $TMP.ss $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_pas_de_sortie $TMP
reproduire_et_comparer $TMP.ss $TMP.d
rm -rf $TMP.d
# là, ça ne devrait plus passer du fait de la destination
$PROG $TMP.ss $TMP.ddd > $TMP.out 2> $TMP.err && fail "code retour = 0 pour dst"
verifier_stderr $TMP "chemin trop long dans la destination"
rm -rf $TMP.ddd
# là, ça ne devrait plus passer du fait de la source
cp /usr/include/stdio.h $troplong
$PROG $TMP.ss $TMP.d > $TMP.out 2> $TMP.err && fail "code retour = 0 pour src"
verifier_stderr $TMP "chemin trop long dans la source"
echo OK

annoncer_test 4.2 "restauration des permissions au bon moment"
nettoyer
creer_grande_arbo $TMP.s
chmod 500 $TMP.s
chmod 400 $TMP.s/stdio.h
chmod 400 $TMP.s/d2/stdio.h
chmod 500 $TMP.s/d1
$PROG $TMP.s $TMP.d > $TMP.out 2> $TMP.err || fail "code de retour != 0"
verifier_pas_de_sortie $TMP
verifier_permissions r-x------ $TMP.s
verifier_permissions r-------- $TMP.s/stdio.h
verifier_permissions r-x------ $TMP.s/d1
verifier_permissions r-------- $TMP.s/d2/stdio.h
echo OK

##############################################################################
# Gestion mémoire

annoncer_test 5.1 "valgrind"
nettoyer
creer_petite_arbo $TMP.s
tester_valgrind $PROG $TMP.s $TMP.d
echo OK

nettoyer
echo "Tests ok"
exit 0

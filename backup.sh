#!/bin/bash

#Author Jakub Tolinski
#nr indeksu 439493

ADDED_PATH=
ABSOLUTE_PATH=
LISTLOC=~/.backup.lst
UPDATEMODE=0


if [ -e $LISTLOC ]
	then
echo "Elementy na liscie $LISTLOC:"
cat $LISTLOC
echo -------------------------

fi

function checkPath() {

	IS_ABSOLUTE=$(echo $ADDED_PATH | grep -c '^/.*')

	if [[ $IS_ABSOLUTE == 0 ]]
		then
		ABSOLUTE_PATH=$(pwd)/$ADDED_PATH
	else
		ABSOLUTE_PATH=$ADDED_PATH
	fi
}

function add() {
checkPath
touch $LISTLOC
if [ -e $ABSOLUTE_PATH ]
	then
	if [[ $(cat ~/.backup.lst | grep -c "^$ABSOLUTE_PATH$") == 0 && $(cat ~/.backup.lst | grep -c "^.*/$(echo $ABSOLUTE_PATH | rev | cut -d "/" -f 2 | rev)$") == 0  ]]
	then
		echo "Dodano do listy:"
		echo $ABSOLUTE_PATH
		echo $ABSOLUTE_PATH >> $LISTLOC
	else
		echo "Plik juz znajduje sie na liscie"
	fi
	else
		echo "Podany plik nie istnieje"
fi
}

function remove() {
checkPath
if  `cat $LISTLOC | grep -q "^$ABSOLUTE_PATH$"`
	then
	echo "usunieto z listy:"
	echo "$ABSOLUTE_PATH"
fi
RESULT=$(cat $LISTLOC | grep -v "^$ABSOLUTE_PATH$")
echo $RESULT | tr " " "\n" > $LISTLOC
if [[ $(wc -c $LISTLOC | cut -d " " -f 1) -lt 2 ]]
	then
	rm -r $LISTLOC
fi
}

function sendToServer(){
			COLNUM=$(echo "$DIRLOC$DATE$i" | tr "/" "\n" | wc -l)
			DIR=
			for ((j=1;j<=$COLNUM-1;j++))
				do
				 if [ $j -ne 1 ]
 					then
					DIR=$DIR/$(echo "$DIRLOC$DATE$i" | cut -d "/" -f $j)
				fi

			done
			DIR=$DIR/
			echo wysylany $DIR
			ssh $SERVERNAME "mkdir -p $DIR" && scp -r $i $SERVERNAME:$DIR
			echo Skopiowano: $(echo "$DIRLOC$DATE$i" | cut -d "/" -f $COLNUM)

}
function updateRecursively(){

if [ -d $i ]
	then
		echo jest direm
		echo dir $i
		DIRTEMP=$i
		for j in `ls $i`
			do
				i=$DIRTEMP/$j
				updateRecursively
			done
	else
		echo nie jest direm
		if [ `stat -c %Y $i` -gt $LASTBACKUP ]
		       then
			sendToServer
		else
		echo nieskopiowano $i
		fi
fi

}

function update(){
	if [ -n $(cat ~/backup_cfg | grep -w '^LASTBACKUP.*') ]
		then
		eval `cat ~/backup_cfg | grep -w '^LASTBACKUP.*'`
	else
		LASTBACKUP=0
	fi

	getServerName
	echo "nazwa $SERVERNAME"
	DATE=$(date +%F-%H-%M-%S)
	for i in $(cat $LISTLOC)
		do

		updateRecursively

		done
	LASTBACKUP=$(date "+%s")
	if [ -n $(cat ~/backup_cfg | grep -w '^LASTBACKUP.*') ]
		then
			TMP=$(cat ~/backup_cfg | grep -v '^LASTBACKUP.*')
			echo $TMP > ~/backup_cfg
			echo "LASTBACKUP=$LASTBACKUP" >> ~/backup_cfg
		else
			echo "LASTBACKUP=$LASTBACKUP" >> ~/.bashrc
	fi
}

function backupNow() {
	getServerName
	DATE=$(date +%F-%H-%M-%S)
	for i in $(cat $LISTLOC)
		do
			echo iteracja
		sendToServer
		done
	LASTBACKUP=$(date "+%s")
	if [ -n $(cat ~/backup_cfg | grep -w '^LASTBACKUP.*') ]
		then
			TMP=$(cat ~/backup_cfg | grep -v '^LASTBACKUP.*')
			echo $TMP > ~/backup_cfg
			echo "LASTBACKUP=$LASTBACKUP" >> ~/backup_cfg
		else
			echo "LASTBACKUP=$LASTBACKUP" >> ~/.bashrc
	fi

}

function getServerName()
{
	if [[ ( -e ~/backup_cfg ) && ( -n $(cat ~/backup_cfg | grep -w '^SERVERNAME.*') ) ]]
	then
		eval `cat ~/backup_cfg | grep -w '^SERVERNAME.*'`
		echo "$SERVERNAME zmienic dane adresowe serwera? (y/n)"
		read YON
		if [ $YON = y ] 2> /dev/null
			then
			echo "aby dokonac zmiany, prosze podac login i adres serwera (np. s12345@lts.wmi.amu.edu.pl):"
			read SERVERNAME
			TMP=$(cat ~/backup_cfg | grep -v '^SERVERNAME.*')
			echo $TMP > ~/backup_cfg
			echo "SERVERNAME=$SERVERNAME" >> ~/backup_cfg
		fi
	else
		echo "Prosze podac login i adres serwera (np. s12345@lts.wmi.amu.edu.pl):"
		read SERVERNAME
		TMP=$(cat ~/backup_cfg 2>/dev/null | grep -v '^SERVERNAME.*')
		echo $TMP > ~/backup_cfg
		echo "SERVERNAME=$SERVERNAME" >> ~/backup_cfg

	fi
}

function info()
{

echo "Opis dzialania poszczegolnych opcji:"
echo "-a [arg] - jesli podany w argumencie plik istnieje i nie znajduje sie na liscie dodaje do listy ~/.backup.lst "
echo "-r [arg] - jesli podany w argumencie plik znajduje sie na liscie usuwa go"
echo "-b [arg] - wykonuje kopie zapasowa plikow podanych na liscie w miejscu sciezki absolutnej podanej jako argument, w czasie uruchomienia trzeba podac adres i login serwera zdalnego, informacja o serwerze zostanie zapisana w pliku ~/backup_cfg. Aby dokonac zmiany juz wybranego serwera nalezy wpisac 'y' przy zapytaniu."
echo "-u [arg] dziala tak jak -b, z ta roznica, ze wykonuje kopie tylko tych plikow ktore zostaly zmodyfikowane od czasu ostatniego kopiowania"
echo "-h wyswietla informacje"

}


while getopts ":a:r:b:u:h" OPTION
do
case $OPTION in
	a) ADDED_PATH=$OPTARG
	     add ;;
	r) ADDED_PATH=$OPTARG
		remove ;;
	b) DIRLOC=$OPTARG/
	       	backupNow;;
	u)  DIRLOC=$OPTARG/
		update  ;;
	h)
		info ;;
	\?)
	echo "Nieprawidlowa opcja -$OPTARG" >&2
	exit 1;;
	:)
	echo "opcja -$OPTARG wymaga podania argumentu" >&2
	exit 1;;
	esac
done

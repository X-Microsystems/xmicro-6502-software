#!/bin/bash
#Syntax: .debuginfo.sh INPUTBIN INPUTDBG OUTPUTLST STARTADDR

rm -rf /tmp/debuginfo

set -e

mkdir /tmp/debuginfo

#Set up arguments
if [ -z $1 ]
then
	INPUTBIN=a.out
else
	INPUTBIN=$1
fi

if [ -z $2 ]
then
	INPUTDBG=a.dbg
else
	INPUTDBG=$2
fi

if [ -z $3 ]
then
	OUTPUTLST=`echo $INPUTBIN | cut -d . -f 1`.lst
else
	OUTPUTLST=$3
fi

if [ -z $4 ]
then
	STARTADDR=8000
else
	STARTADDR=$4
fi

#Comma-separate all fields, add a comma to keep the CR/LF characters at the end of the line out
sed 's/\t/,/g' $INPUTDBG | sed 's/\r/,\r/g' > /tmp/debuginfo/temp.dbg

#Collect total counts of all items (NOT zero-indexed)
grep 'info,' /tmp/debuginfo/temp.dbg > /tmp/debuginfo/temp2.dbg
while read -r line
do
	for field in {1..15}
	do
		csymCount=$csymCount`echo $line | cut -d , -f $field | grep '^csym=' | cut -d \= -f 2`
		fileCount=$fileCount`echo $line | cut -d , -f $field | grep '^file=' | cut -d \= -f 2`
		libCount=$libCount`echo $line | cut -d , -f $field | grep '^lib=' | cut -d \= -f 2`
		lineCount=$lineCount`echo $line | cut -d , -f $field | grep '^line=' | cut -d \= -f 2`
		modCount=$modCount`echo $line | cut -d , -f $field | grep '^mod=' | cut -d \= -f 2`
		scopeCount=$scopeCount`echo $line | cut -d , -f $field | grep '^scope=' | cut -d \= -f 2`
		segCount=$segCount`echo $line | cut -d , -f $field | grep '^seg=' | cut -d \= -f 2`
		spanCount=$spanCount`echo $line | cut -d , -f $field | grep '^span=' | cut -d \= -f 2`
		symCount=$symCount`echo $line | cut -d , -f $field | grep '^sym=' | cut -d \= -f 2`
		typeCount=$typeCount`echo $line | cut -d , -f $field | grep '^type=' | cut -d \= -f 2`
	done
done < /tmp/debuginfo/temp2.dbg

#Collect segment data
grep 'seg,' /tmp/debuginfo/temp.dbg > /tmp/debuginfo/temp2.dbg
while read -r line
do
	index=`echo $line | cut -d , -f 2 | grep '^id=' | cut -d \= -f 2`
	for field in {1..9}
	do
		segName[$index]=${segName[$index]}`echo $line | cut -d , -f $field | grep '^name=' | cut -d \" -f 2`
		segStart[$index]=${segStart[$index]}`echo $line | cut -d , -f $field | grep '^start=' | cut -d x -f 2`
		segSize[$index]=${segSize[$index]}`echo $line | cut -d , -f $field | grep '^size=' | cut -d x -f 2`
		segAddrsize[$index]=${segAddrsize[$index]}`echo $line | cut -d , -f $field | grep '^addrsize=' | cut -d \= -f 2`
		segType[$index]=${segType[$index]}`echo $line | cut -d , -f $field | grep '^type=' | cut -d \= -f 2`
		segOname[$index]=${segOname[$index]}`echo $line | cut -d , -f $field | grep '^oname=' | cut -d \" -f 2`
		segOoffs[$index]=${segOoffs[$index]}`echo $line | cut -d , -f $field | grep '^ooffs=' | cut -d \= -f 2`
	done
done < /tmp/debuginfo/temp2.dbg

#Collect symbol data
grep 'sym,' /tmp/debuginfo/temp.dbg > /tmp/debuginfo/temp2.dbg
while read -r line
do
	index=`echo $line | cut -d , -f 2 | grep '^id=' | cut -d \= -f 2`
	for field in {1..12}
	do
		symName[$index]=${symName[$index]}`echo $line | cut -d , -f $field | grep '^name=' | cut -d \" -f 2`
		symAddrsize[$index]=${symAddrsize[$index]}`echo $line | cut -d , -f $field | grep '^addrsize=' | cut -d \= -f 2`
		symScope[$index]=${symScope[$index]}`echo $line | cut -d , -f $field | grep '^scope=' | cut -d \= -f 2`
		symDef[$index]=${symDef[$index]}`echo $line | cut -d , -f $field | grep '^def=' | cut -d \= -f 2`
		symRef[$index]=${symRef[$index]}`echo $line | cut -d , -f $field | grep '^ref=' | cut -d \= -f 2`
		symVal[$index]=${symVal[$index]}`echo $line | cut -d , -f $field | grep '^val=' | cut -d x -f 2`
		symSeg[$index]=${symSeg[$index]}`echo $line | cut -d , -f $field | grep '^seg=' | cut -d \= -f 2`
		symType[$index]=${symType[$index]}`echo $line | cut -d , -f $field | grep '^type=' | cut -d \= -f 2`
		symExp[$index]=${symExp[$index]}`echo $line | cut -d , -f $field | grep '^exp=' | cut -d \= -f 2`
	done
done < /tmp/debuginfo/temp2.dbg

#################################################################
#Create code listing
echo "GLOBAL {
	HEXOFFS		TRUE;
	COMMENTS	4;
	CPU \"65C02\";
	};
" > /tmp/debuginfo/info.txt

#Add segment info
for ((index=0; index<$segCount; index++))
do
	#Only list segments that were written to the output (this script's input) file and have non-zero length.
	if [ "${segOname[$index]}" == "${INPUTBIN}" ] && [ "$((0x${segSize[$index]}))" != 0 ]
	then
		echo "SEGMENT { NAME \"${segName[$index]}\";	START \$`echo 16o$((0x${STARTADDR}+${segOoffs[$index]}))p | dc`;	END \$`echo 16o$((0x${STARTADDR}+${segOoffs[$index]}+0x${segSize[$index]}-1))p | dc`;	};" >> /tmp/debuginfo/info.txt
	fi
done

#Add symbol info
echo >> /tmp/debuginfo/info.txt
touch /tmp/debuginfo/temp3.dbg
for ((index=0; index<$symCount; index++))
do
	#Only list segments that were written to the output (this script's input) file and have non-zero length.
	if [ "${symType[$index]}" == "lab" ] || [ "${symType[$index]}" == "equ" ]
	then
		#List symbols with a conflicting address as comments at the end of the file
		if [ -z "`grep 'ADDR \$'"${symVal[$index]};" /tmp/debuginfo/info.txt`" ]
		then
			echo "LABEL { NAME \"${symName[$index]}\";	ADDR \$${symVal[$index]}; };" >> /tmp/debuginfo/info.txt
		else
			echo "#LABEL { NAME \"${symName[$index]}\";	ADDR \$${symVal[$index]}; };" >> /tmp/debuginfo/temp3.dbg
		fi
	fi
done

#Add commented symbol info for duplicates
echo "
#Duplicate Symbols" >> /tmp/debuginfo/info.txt
cat /tmp/debuginfo/temp3.dbg >> /tmp/debuginfo/info.txt


#Disassemble
da65 -i /tmp/debuginfo/info.txt -S \$${STARTADDR} -o /tmp/debuginfo/temp.s ${INPUTBIN}
grep -v " FF FF FF " /tmp/debuginfo/temp.s > $OUTPUTLST

#Extract relocated segments and disassemble them to their assembled address
for ((index=0; index<$segCount; index++))
do
	#Only do segments that were written to the output (this script's input) file and have non-zero length, and which have mismatched start and offset addresses
	if ( [ "${segOname[$index]}" == "${INPUTBIN}" ] && [ "$((0x${segSize[$index]}))" != 0 ] ) && [ "$((0x${segStart[$index]}))" != "$((0x${STARTADDR}+${segOoffs[$index]}))" ]
	then
		#Extract segment from main binary
		dd if=${INPUTBIN} of=/tmp/debuginfo/${segName[$index]}.out skip=${segOoffs[$index]} count=$((0x${segSize[$index]})) bs=1 status=none
		#Disassemble segment
		da65 -i /tmp/debuginfo/info.txt -S \$${segStart[$index]} -o /tmp/debuginfo/${segName[$index]}.s /tmp/debuginfo/${segName[$index]}.out
		cat /tmp/debuginfo/${segName[$index]}.s >> $OUTPUTLST
	fi
done
rm $INPUTDBG

############################################################################
#Create logic analyzer symbol files
> ./segments.sym
> ./labels.sym
#Create segment symbols
for ((index=0; index<$segCount; index++))
do
	#Only list segments that were written to the output (this script's input) file and have non-zero length.
	if [ "$((0x${segSize[$index]}))" != 0 ]
	then
		echo -e "${segName[$index]}			${segStart[$index]}..`echo 16o$((0x${segStart[$index]}+0x${segSize[$index]}-1))p | dc`\r" >> ./segments.sym
	fi
done

#Create label symbols
for ((index=0; index<$symCount; index++))
do
	#Only list segments that were written to the output (this script's input) file and have non-zero length.
	if [ "${symType[$index]}" == "lab" ] || [ "${symType[$index]}" == "equ" ]
	then
		#List symbols with a conflicting address as comments at the end of the file
		if [ -z "`grep "	${symVal[$index]}" ./labels.sym`" ]
		then
			echo -e "${symName[$index]}			${symVal[$index]}\r" >> ./labels.sym
		fi
	fi
done

#rm -r /tmp/debuginfo
exit 0

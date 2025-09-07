#!/bin/ksh

function ValEje
{
        Proce=`ps aux | grep -c infoPrePos.sh`
        if [[ $Proce -eq 1 ]]
        then
                EjeinfoPrePos
        else
            echo "Proceso infoPrePos.sh en Ejecucion.!!! No se puede ejecutar hasta que Termine"
        fi
}

function EjeinfoPrePos
{
AIX_InfoPP() {
HOST=$(hostname)
FECHA=$(date '+%Y%m%d-%H%M%S')
DIRINFO="/var/tmp/InfoPrePos"
BASE="$HOST.$FECHA"
ARCHIVO1="$DIRINFO/$BASE-Procesos.ipp"
ARCHIVO2="$BASE.ipp"
ARCHIVO="$DIRINFO/$ARCHIVO2"
USUARIO=$(id -un)
generar (){
> $ARCHIVO
echo ======================================================= >> $ARCHIVO
echo FECHA:$FECHA >> $ARCHIVO
echo HOSTNAME:$HOST >> $ARCHIVO
echo USUARIO:$USUARIO >> $ARCHIVO
echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Booteo ... "
bootlist -m normal -o | awk '{ print "BOOT:"$1":"$2":"$3 }' | sort >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Discos ... "
for D in $(lspv | awk '{ print $1 }' | sort); do
   echo DISCOS:$D $(lscfg -vl $D | grep Z1 | awk '{ print $2 }' | awk -F. '{ print $NF }') >> $ARCHIVO
done
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Volume Groups ... "
lsvg -o | sort | awk '{ print "VGS:"$1 }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de File Systems ... "
for F in $(df -gP | egrep -vw "Filesystem|/proc" | awk '{ print $NF }'); do
   TIPO=$(lsfs | grep $F' ' | awk '{ print $4 }')
   case "$TIPO" in
      'nfs') LV=$(df -gP | grep $F' ' | awk '{ print $1 }')
             VG="N/A";;
      *)     LV=$(lsfs | grep $F' ' | awk '{ print $1 }' | cut -d / -f 3)
             VG=$(lslv $LV | grep "VOLUME GROUP" | awk '{ print $NF }');;
   esac
   printf "FS:%s:%s:%s:%s\n" $F $LV $VG $TIPO >> $ARCHIVO
done
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Red ... "
for I in $(lsdev -c if | grep -w Available | awk '{ print $1 }'); do
   IP=$(ifconfig $I | grep -w inet | awk '{ printf "%s/%d.%d.%d.%d\n",$2,substr($4,1,4),"0x"substr($4,5,2),"0x"substr($4,7,2),"0x"substr($4,9,2) }' | awk 'BEGIN { ORS="," } { print $1 }' | sed 's/,$//g')
   ESTADO=$(lsattr -El $I -a state | awk '{ print $2 }')
   if [ $I == "lo0" ]; then
      ADAP=$I
      TIPO=$(lsdev -l $I | awk '{ print $3 }')
      DISPOSITIVO="N/A"
   else
      ADAP=$(echo $I | sed 's/en/ent/g')
      TIPO=$(lsdev -l $ADAP | awk '{ print $3 }')
      if [ $TIPO == "EtherChannel" ]; then
         DISPOSITIVO=$(lsattr -El $ADAP -a adapter_names -a backup_adapter | awk '{ printf "%s ",$2; system("lscfg -pl "$2" | grep Location") }' | awk ' BEGIN { ORS="," } { print $1"/"$NF }' | sed 's/,$//g')
      else
         DISPOSITIVO=$(lscfg -pl $ADAP | grep "Physical Location" | awk '{ print $NF }')
      fi
   fi
   printf "RED:%s:%s:%s:%s:%s\n" $I $ESTADO $TIPO $DISPOSITIVO $IP >> $ARCHIVO
done
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Rutas Rstaticas ... "
netstat -rn -f inet | grep -p '(Internet):' | grep -v "Route Tree" | awk '{ print "RUTAS:"$1":"$2":"$3":"$6 }' | grep -v ":::" >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Swap ... "
lsps -a | grep -v "Page Space" | awk '{ printf "SWAP:%s:%s:%s:%s:%s\n",$1,$2,$3,$4,$6 }' | sort >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de DNS ... "
grep -v ^# /etc/resolv.conf | grep ^nameserver | awk '{ print "DNS:"$2 }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de CPU ... "
lparstat -i | grep 'Desired Capacity' | awk '{ print "CPU:"$NF }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Memoria ... "
lparstat -i | grep 'Desired Memory' | cut -d: -f2 | awk '{ print "MEMORIA:"$1 }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Sistema Operativo ... "
oslevel -s | awk '{ print "VERSO:"$1 }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Dispositivos de Red ... "
lsdev -c adapter 2> /dev/null | grep ^ent[0-9] | awk '{ print "DEVRED:"$1":"$2 }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Dispositivos de Fibra ... "
lsdev -c adapter 2> /dev/null | grep ^fcs[0-9] | awk '{ print "DEVHBA:"$1":"$2 }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Usuarios ... "
lsuser -c -a id pgrp groups home ALL | grep -v ^# | awk '{ print "USUARIOS:"$0 }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Grupos ... "
lsgroup -c ALL | grep -v ^# | awk '{ print "GRUPOS:"$0 }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de /etc/hosts ... "
hostent -S | awk '{ print "HOSTS:"$0 }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de kernel ... "
vmo -a | awk '{ print "KERNEL:"$1$2$3 }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Parametros de Red ... "
no -a | awk '{ print "REDPARAM:"$1$2$3 }' >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO
printf "Generando informacion de Puertos en escucha ... "
netstat -an | grep -v tcp6 | grep LISTEN | sort -k 4 >> $ARCHIVO
printf "OK\n"

echo ===================================================== >> $ARCHIVO1
printf "Generando informacion de los procesos ... "
ps -fea | grep -v "ssh|ksh|sftp|bash|awk|grep|sshd"|sort -nk 2 >> $ARCHIVO1
printf "OK\n"

echo ===================================================== >> $ARCHIVO
echo Salida registrada en archivo $ARCHIVO

}

ayuda (){
echo "Modo de uso: $0"
echo "             $0 comp"
echo "             $0 comp [archivo PRE] [archivo POST]"
}


compararItem(){
ITEM=$1
ESTADO="OK"
printf "$ITEM\t\t"
for I in $(grep -w ^$ITEM $PRE | cut -d: -f2); do
   grep -e ^$ITEM:$I: -e ^$ITEM:$I$ $POST > /dev/null 2>&1
   if (( $? != 0 )); then
      printf "\n\t\t%s no presente. %s" $I $(grep -e ^$ITEM:$I: -e ^$ITEM:$I$ $PRE)
      ESTADO=" "
   else
      INI=$(grep -e ^$ITEM:$I: -e ^$ITEM:$I$ $PRE)
      ACT=$(grep -e ^$ITEM:$I: -e ^$ITEM:$I$ $POST)
      if [ $INI != $ACT ]; then
         printf "\n\t\t%s configuracion ha cambiado:\n" $I
         printf "\t\t\tInicial: %s\n" $INI
         printf "\t\t\tActual:  %s" $ACT
         ESTADO=" "
      fi
   fi
done
printf "%s\n" $ESTADO
}


comparar (){
echo Comparando archivos $PRE y $POST
echo =====================================================
# BOOT ---------------------------------------------------
ESTADO="OK"
printf "BOOT\t\t"
for B in $(grep BOOT $PRE); do
   grep ^$B $POST > /dev/null 2>&1
   if (( $? != 0 )); then
      printf "\n\t\t%s no presente." $(echo $B | cut -d: -f 2,3,4)
      ESTADO=" "
   fi
done
printf "%s\n" $ESTADO

# DISCOS -------------------------------------------------
ESTADO="OK"
printf "DISCOS\t\t"
for D in $(grep DISCOS $PRE |  cut -d: -f2 | awk '{ print $1 }'); do
   grep ^DISCOS $POST | grep -w $D > /dev/null 2>&1
   if (( $? != 0 )); then
      printf "\n\t\t%s no presente. ID: %s" $D $(grep DISCOS $PRE | grep -w $D | cut -d: -f2 | awk '{ print $2 }')
      ESTADO=" "
   fi
done
printf "%s\n" $ESTADO
echo "aqui voy"
compararItem VGS
compararItem FS
compararItem RED
compararItem RUTAS
compararItem SWAP
compararItem DNS
compararItem CPU
compararItem MEMORIA
compararItem VERSO
compararItem DEVRED
compararItem DEVHBA
compararItem USUARIOS
compararItem GRUPOS

# HOSTS --------------------------------------------------
ESTADO="OK"
printf "HOSTS\t\t"
for H in $(grep HOSTS $PRE | cut -d: -f2 | awk '{ print $1 }'); do
   grep ^HOSTS $POST | grep -w $H > /dev/null 2>&1
   if (( $? != 0 )); then
      printf "\n\t\t%s no presente. IP: %s" $H $(grep ^HOSTS $PRE | grep -w $H | cut -d: -f2 | awk '{ print $2 }')
      ESTADO=" "
   fi
done
printf "%s\n" $ESTADO

compararItem KERNEL
compararItem REDPARAM
}


validarArchivo(){
if [ ! -e $PRE ]; then
   PRE=$DIRINFO/$PRE
fi
if [ ! -e $POST ]; then
   POST=$DIRINFO/$POST
fi
}

if [ ! -e $DIRINFO ]; then
   mkdir $DIRINFO
fi
case "$#" in
   0 ) generar;;
   1 ) case "$1" in
          'comp') if (( $(ls $DIRINFO | wc -l) >=2 )); then
                     PRE="$DIRINFO/$(ls -tr $DIRINFO | tail -2 | head -1)"
                     POST="$DIRINFO/$(ls -tr $DIRINFO | tail -1)"
                  else
                     echo No hay suficientes archivos a comparar en $DIRINFO
                  fi
                  comparar;;
          'ayuda') ayuda;;
          *) echo Parametro $1 desconocido
             ayuda;;
       esac;;
   2 ) PRE=$2
       validarArchivo
       echo Solo a proporcionado un archivo: $PRE
       if [ ! -e $PRE ]; then
          echo Archivo $PRE no existe
       fi
       ayuda;;
   * ) PRE=$2
       POST=$3
       validarArchivo
       if [ ! -e $PRE ]; then
          echo Archivo $PRE no existe
       fi
       if [ ! -e $POST ]; then
          echo Archivo $POST no existe
       fi
       if [ -e $PRE -a -e $POST ]; then
          comparar
       fi;;
esac

cd $DIRINFO
ls -l $ARCHIVO; ls -l $ARCHIVO1
/usr/bin/tar -cvf $ARCHIVO.tar $ARCHIVO $ARCHIVO1; gzip $ARCHIVO.tar
/usr/bin/sh /usr/bin/tools/envioftp.sh $ARCHIVO2.tar.gz
/usr/bin/rm $ARCHIVO.tar.gz

}


HPUX_InfoPP() {
##Version 13-06-2020_08:31
##quite df -kP y quite la salida de error de setboot -v
##Version 28-03-2020_16:07
##corrigue la salida de drd status
maquina=`hostname`
fecha=`date "+%F-%H%M%S"`
mkdir -p /var/tmp/InfoPrePos/$maquina.$fecha
### 2 lineas agregadas 28/08/18 12:45 PM
echo " Mapa de discos ASM" > /var/tmp/InfoPrePos/$maquina.$fecha/asmlinks.$maquina.$fecha
/usr/bin/tools/info_nombres_asm.sh > /var/tmp/InfoPrePos/$maquina.$fecha/asmlinks.$maquina.$fecha
###
echo " Disco de Boot" > /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/tools/VerBoot >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
cat /stand/bootconf   >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/setboot -v 1>> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha 2>>/tmp/salida.err
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "File Systems" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/df >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
Fm=`/usr/bin/df|wc -l`
echo " Numero de File systems Montados ==> $Fm " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
Ff=`cat /etc/fstab |grep -v "#"|grep -v sw|grep dev |wc -l`
echo " Numero de File systems en fstab ==> $Fm " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " Salida de mount para ver la fecha de los filesystem montados" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/sbin/mount >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " Crones en ejecucion" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/ps -edf|grep cron  |grep -v grep >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " Salida de bdfmegs para ver el espacio en megas"         >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
#####/usr/bin/df -kP  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/bdfmegs | sed -e "/^[[:blank:]]*$/d"  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "informacion de swap" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "  " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/swapinfo >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/swapinfo -tam >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " Informacion Red - netstat -ni" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/netstat -ni >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "  " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "Informacion Rutas estaticas - netstat -nr" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/netstat -nr >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "  " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " informacion de la Red - lanscan -qv" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/lanscan -qv  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
for i in `/usr/sbin/lanscan -q|awk '{print $1}'`
do
  echo lan $i >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  /usr/sbin/lanadmin -x $i    >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  /usr/sbin/lanadmin -a $i >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
done

echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " informacion de la Red - lanscan" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/lanscan >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha

echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " informacion de la Red - nwmgr" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/nwmgr >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha

echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha

echo " informacion de la Red APA " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/nwmgr -S apa >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "    Configuracion de red" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
cat /etc/rc.config.d/netconf|grep -v "#" | sed -e "/^[[:blank:]]*$/d"  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/ntpq -p >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " DNS " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ===================================================== " >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
cat /etc/resolv.conf >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " =====================================================" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "Cpu" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "Informacion de la Conformacion de las CPUS"  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/contrib/bin/machinfo -v -m >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
#echo "selclass qualifier cpu;info;wait;infolog" | cstm|egrep 'CPU Number|Processor Speed|CPU Serial|product'   >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " version de sistema operativo" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
uname -a >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "modelo de la maquina  $maquina"  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/model  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "Informacion del estatus de la celda "  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/parstatus 1>>/dev/null 2>>/dev/null
if [ $? = 1 ]; then
  echo "No es una vpar" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
else
  /usr/sbin/parstatus >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
fi
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
#echo "Informacion de la Conformacion de la Memoria"  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
#echo "selclass qualifier memory;info;wait;infolog" | cstm  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha 2>&1
#echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "Informacion de las tarjetas de RED "  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/ioscan -fnC lan >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
#ioscan -fnC fc  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/tools/hba  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "Informacion de DRD "  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/opt/drd/bin/drd status  1>> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha 2>&1
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "Informacion de cluster "  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
if [ -f /usr/sbin/cmviewcl ]; then
  /usr/sbin/cmviewcl -v >>/dev/null 2>>/dev/null
  if [ $? = 1 ]; then
    echo "No tiene Service Guard configurado" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  else
    /usr/sbin/cmviewcl -v  1>> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha 2>&1
  fi
else
   echo "No tiene Service Guard instalado" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
fi
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "              Passwd                                       ">> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
cat /etc/passwd  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "              Shadow                                       ">> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
cat /etc/shadow  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "              Group                                       ">> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
cat /etc/group >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "              Hosts                                       ">> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
cat /etc/hosts  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "              Fstab                                       ">> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
cat /etc/fstab  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo "              Parametros de Kernel                                       ">> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/kctune  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
netstat -an | grep -v tcp6 | grep LISTEN | sort -k 4 >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/Procesos.txt
ps -fea |grep -v "ssh|ksh|sftp|bash|awk|grep|sshd"|sort -nk 2 >> /var/tmp/InfoPrePos/$maquina.$fecha/Procesos.txt
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/Procesos.txt

echo "Informacion de Bases de datos  "  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/ps -edf|grep pmon |grep -v grep|awk '{print $1"    "NF}'|sort +0   >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha 2>&1
echo "Informacion de Listeners       "  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/sh /usr/bin/tools/Listener.sh   >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/sh /usr/bin/tools/Listener.sh   >> /var/tmp/InfoPrePos/$maquina.$fecha/Listener.$fecha 2>&1
/usr/bin/ls -lat /dev/*/group > /var/tmp/InfoPrePos/$maquina.$fecha/lista_vg
echo "Informacion de la Conformacion de Vgs en el sistema "  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/cat /var/tmp/InfoPrePos/$maquina.$fecha/lista_vg >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/bin/cp -rp /etc/rc.config.d/netconf /var/tmp/InfoPrePos/$maquina.$fecha/
/usr/bin/cp -rp /etc/passwd   /var/tmp/InfoPrePos/$maquina.$fecha/
/usr/bin/cp -rp /etc/shadow   /var/tmp/InfoPrePos/$maquina.$fecha/
/usr/bin/cp -rp /etc/group    /var/tmp/InfoPrePos/$maquina.$fecha/
/usr/bin/cp -rp /etc/hosts    /var/tmp/InfoPrePos/$maquina.$fecha/
/usr/bin/cp -rp /etc/fstab    /var/tmp/InfoPrePos/$maquina.$fecha/
/usr/bin/cp -rp /etc/resolv.conf /var/tmp/InfoPrePos/$maquina.$fecha/
### copiemos todos los contabs del sistema operativo
/usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs
/usr/bin/cp -rp /var/spool/cron/crontabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs

####################################################################################################
### copiamos el contenido de /gwmemfs del comhp05
if [ -d "/gwmemfs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/gwmemfs
    /usr/bin/cp -rp /gwmemfs/* /var/tmp/InfoPrePos/$maquina.$fecha/gwmemfs
fi
####################################################################################################

### copiamos los crontabs de BSCS en COMHP35
if [ -d "/bscssystem/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.bscs
    /usr/bin/cp -rp /bscssystem/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.bscs
fi

### copiamos los crontabs de Provisionador en COMHP36
if [ -d "/Provisionador/.cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.Provisionador
    /usr/bin/cp -rp /Provisionador/.cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.Provisionador
fi

### copiamos los crontabs de billro en COMHP36
if [ -d "/billroprdsys01/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.Billro
    /usr/bin/cp -rp /billroprdsys01/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.Billro
fi

### copiamos los crontabs de RTX en COMHP36
if [ -d "/rtxsystem/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.RTX
    /usr/bin/cp -rp /rtxsystem/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.RTX
fi

### copiamos los crontabs de SMOP2 en COMHP20

if [ -d "/smop2system/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.SMOP2
    /usr/bin/cp -rp /smop2system/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.SMOP2
fi

### copiamos los crontabs de SMSSERV en COMHP20

if [ -d "/smsservsystem/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.SMSSERV
    /usr/bin/cp -rp /smsservsystem/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.SMSSERV
fi

### copiamos los crontabs de BANK en COMHP21

if [ -d "/banksystem/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.BANK
    /usr/bin/cp -rp /banksystem/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.BANK
fi

### copiamos los crontabs de MAYORIS en COMHP21

if [ -d "/mayorissystem/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.MAYORIS
    /usr/bin/cp -rp /mayorissystem/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.MAYORIS
fi

### copiamos los crontabs de SMOP1 en COMHP21

if [ -d "/smop1system/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.SMOP1
    /usr/bin/cp -rp /smop1system/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.SMOP1
fi

### copiamos los crontabs de SMSBROAD en COMHP21
if [ -d "/smsbroadsystem/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.SMSBROAD
    /usr/bin/cp -rp /smsbroadsystem/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.SMSBROAD
fi

### copiamos los crontabs de CAJAS en COMHP01
if [ -d "/cajasprdsys01/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.CAJAS
    /usr/bin/cp -rp /cajasprdsys01/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.CAJAS
fi

### copiamos los crontabs de COMCORP en COMHP01
if [ -d "/comcorpsystem/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.COMCORP
    /usr/bin/cp -rp /comcorpsystem/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.COMCORP
fi

### copiamos los crontabs de PORTAL en COMHP01
if [ -d "/portalsystem/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.PORTAL
    /usr/bin/cp -rp /portalsystem/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.PORTAL
fi

### copiamos los crontabs de SERCON en COMHP01
if [ -d "/serconsystem/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.SERCON
    /usr/bin/cp -rp /serconsystem/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.SERCON
fi

### copiamos los crontabs de ACTIVA en COMHP06
if [ -d "/actprdsys01/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.ACTIVA
    /usr/bin/cp -rp /actprdsys01/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.ACTIVA
fi

### copiamos los crontabs de POLIEXP en COMHP06
if [ -d "/poliexp_system/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.POLIEXP
    /usr/bin/cp -rp /poliexp_system/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.POLIEXP
fi

### copiamos los crontabs de PPACTIVA en COMHP06
if [ -d "/ppactivasys01/cron/var/cron/tabs" ]
then
    /usr/bin/mkdir /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.PPACTIVA
    /usr/bin/cp -rp /ppactivasys01/cron/var/cron/tabs/* /var/tmp/InfoPrePos/$maquina.$fecha/crontabs.PPACTIVA
fi

####################################################################################################
echo "Informacion Vgs                                       ">> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
/usr/sbin/vgdisplay -v |grep -e "VG Name" -e "Cur PV" -e "Act PV" 1>> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
for i in `cat /var/tmp/InfoPrePos/$maquina.$fecha/lista_vg |awk '{print $NF}'|awk '{FS="/"; print $3}'`
do
  /usr/sbin/vgexport -p -f /var/tmp/InfoPrePos/$maquina.$fecha/$i.dsk.$fecha  $i 
  /usr/sbin/vgexport -p -s -m /var/tmp/InfoPrePos/$maquina.$fecha/$i.map.$fecha $i 
  /sbin/vgcfgbackup -f /var/tmp/InfoPrePos/$maquina.$fecha/$i.backup.$fecha $i 
done

VMHOST=`ps -ef | grep /opt/hpvm/bin/hpvmctrld | grep -v grep | wc -l`
if [ $VMHOST  -gt "0" ]; then
  echo " =================================================================================" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  echo "Informacion de todas las maquinas virtuales"                                        >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  /opt/hpvm/bin/hpvmstatus | egrep -v "Virtual Machines"                                    >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  echo "Informacion Detallada de todas las maquinas virtuales"                              >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  for i in `/opt/hpvm/bin/hpvmstatus | egrep -v "Virtual|^=" | awk '{print $1}'`;do
    echo "================================================================================" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
    echo "Informacion de la maquina virtual $i"                                             >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
    echo "================================================================================" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
    /opt/hpvm/bin/hpvmstatus -P $i -V                                                       >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
    echo ""                                                                                 >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  done

  echo "================================================================================"   >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  echo ""                                                                                   >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  for i in `/opt/hpvm/bin/hpvmstatus | egrep -v "Virtual|^=" | awk '{print $1}'`;do
    TIPO_BOOT=`/opt/hpvm/bin/hpvmstatus -P $i -V | grep "Start type" | awk '{print $NF}'`
    echo "Servidor: $i Tipo de Boot: $TIPO_BOOT"                                            >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  done
  echo " =================================================================================" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
fi
ES_VIRTUAL=`/usr/contrib/bin/machinfo -v -m | grep "Model:" | grep Virtual | wc -l`
if [ $ES_VIRTUAL  -gt "0" ]; then
  echo " =================================================================================" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  BASE=`/opt/hpvm/bin/hpvminfo -V | grep Hostname | awk '{print $NF}'`
  SERIAL_BASE=`/opt/hpvm/bin/hpvminfo -V | grep "VSP Host serial number" | awk '{print $NF}'`
  echo "Es un Servidor Virtual"                                                             >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  echo "Base           : $BASE"                                                             >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  echo "Serial del Base: $SERIAL_BASE"                                                      >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
  echo " =================================================================================" >> /var/tmp/InfoPrePos/$maquina.$fecha/config.$maquina.$fecha
fi

cd /var/tmp/InfoPrePos/$maquina.$fecha/
/usr/bin/tar -cvf /var/tmp/InfoPrePos/$maquina.$fecha.tar /var/tmp/InfoPrePos/$maquina.$fecha; gzip /var/tmp/InfoPrePos/$maquina.$fecha.tar
/usr/bin/sh /usr/bin/tools/envioftp.sh $maquina.$fecha.tar.gz
/usr/bin/rm /var/tmp/InfoPrePos/$maquina.$fecha.tar.gz
/usr/bin/rm /var/tmp/InfoPrePos/$maquina.$fecha.tar
/usr/bin/find /var/tmp/InfoPrePos -mtime +60 -type d -exec rm -r {} \;
}


Linux_InfoPP() {
maquina=`hostname|sed -e "s/.comcel.com.co//g"`
fecha=`date "+%F-%H%M%S"`
ruta="/var/tmp/InfoPrePos/"
SCSIID=/usr/lib/udev/scsi_id
#OSMajor=`cat ${ReleaseFile} | awk '{print $7}' | cut -d. -f1`
OSMajor=`uname -r | awk -F. '{print $4}'`

mkdir -p $ruta$maquina.$fecha
echo "================================================================================" > $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Informacion  Sobre Estado Servidor $maquina Fecha `date` " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" > $ruta$maquina.$fecha/config.$maquina.$fecha

echo "Informacion de los dispositivos y sus WWNID" >> $ruta$maquina.$fecha/config.$maquina.$fecha
if [ "${OSMajor}" = "el6" -o "${OSMajor}" = "el7" ]; then
{
  for i in `cat /proc/partitions | awk {'print $4'} | grep sd`
  do
  echo "Dispositivo: $i WWID: `${SCSIID} --page=0x83 --whitelisted --device=/dev/$i`"
  done
} | sort -k4 $1 >> $ruta$maquina.$fecha/config.$maquina.$fecha
        elif [ "${OSMajor}" = "el5" ]; then
{
  for i in `cat /proc/partitions | awk {'print $4'} | grep sd`
  do
  echo "Dispositivo: $i WWID: `${SCSIID} -g -u -s /block/$i`"
  done
} | sort -k4 $1 >> $ruta$maquina.$fecha/config.$maquina.$fecha
else
  echo "Advertencia: no puedo procesar los dispositivos en este Sistema Operativo" >> $ruta$maquina.$fecha/config.$maquina.$fecha
fi

echo "Informacion Discos de Boot" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
cat /etc/fstab |grep 00|grep -v mapper |sort -u |awk -F/ '{print "lvs |grep "$3"\npvs |grep "$3"\nvgs|grep "$3}'|sort -u|sort -r|sh >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "  " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Configuracion Boot " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
cat /boot/grub/menu.lst  |grep -v "#"  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "  " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "File Systems" >> $ruta$maquina.$fecha/config.$maquina.$fecha
df -h >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "  " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
Fm=`df|wc -l`
echo " Numero de File systems Montados ==> $Fm " >> $ruta$maquina.$fecha/config.$maquina.$fecha
Ff=`cat /etc/fstab |grep -v "#"|grep -v sw|grep dev |wc -l`
echo " Numero de File systems en fstab ==> $Fm " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "  " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo " Crones en ejecucion" >> $ruta$maquina.$fecha/config.$maquina.$fecha
ps -edf|grep cron |grep -v grep  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "  " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "informacion de swap" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "  " >> $ruta$maquina.$fecha/config.$maquina.$fecha
cat /proc/swaps >> $ruta$maquina.$fecha/config.$maquina.$fecha
free >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "  " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo " Informacion Red" >> $ruta$maquina.$fecha/config.$maquina.$fecha
netstat -ni >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "  " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Informacion Rutas estaticas" >> $ruta$maquina.$fecha/config.$maquina.$fecha
netstat -nr >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "  " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Informacion Default Gateway " >> $ruta$maquina.$fecha/config.$maquina.$fecha
default_gateway_ip=$(netstat -rn | awk '{if($1=="0.0.0.0")print $2}')
echo " Default Gateway  = $default_gateway_ip " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "  " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo " informacion de la Red" >> $ruta$maquina.$fecha/config.$maquina.$fecha
for i in `netstat -i | tail -n +3 | awk '{if($1!="lo") print $1}'`; do ifconfig $i|egrep "$i|inet";ethtool ${i} | grep -i speed: | awk '{print "Speed     "$2}'; ethtool ${i}| grep -i duplex: | awk '{print "Duplex    "$2}' ;done >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo " informacion de  Bonding " >> $ruta$maquina.$fecha/config.$maquina.$fecha
if [ -d /proc/net/bonding ]
   then
      for dir in $(ls /proc/net/bonding)
        do
          cat /proc/net/bonding/$dir >> $ruta$maquina.$fecha/config.$maquina.$fecha
done
fi
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "    Configuracion de red" >> $ruta$maquina.$fecha/config.$maquina.$fecha
if [ -d /etc/sysconfig/networking/devices ]
   then
      for dir in $(ls /etc/sysconfig/networking/devices)
        do
          cat /etc/sysconfig/networking/devices/$dir >> $ruta$maquina.$fecha/config.$maquina.$fecha
done
fi
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
ntpq -p >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo " DNS " >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
cat /etc/resolv.conf >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Cpu" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Informacion de la Conformacion de las CPUS"  >> $ruta$maquina.$fecha/config.$maquina.$fecha
processor_count=$(grep processor /proc/cpuinfo | wc | awk '{print $1}') >> $ruta$maquina.$fecha/config.$maquina.$fecha
processor_type=$(grep "model name" /proc/cpuinfo | head -n1 | awk -F: '{gsub("^[ ]*","",$2);print $2}') >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Velocidad Cpu" >> $ruta$maquina.$fecha/config.$maquina.$fecha
cpu_speed=$(grep -i "cpu MHz" /proc/cpuinfo | head -n1 | awk -F"[ :]+" '{print $3}') >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo " version de sistema operativo" >> $ruta$maquina.$fecha/config.$maquina.$fecha
uname -a >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Informacion de las tarjetas de RED "  >> $ruta$maquina.$fecha/config.$maquina.$fecha
netstat -i | tail -n +3 | awk '{if($1!="lo") print $1}' >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
hba  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "              Passwd                                       ">> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
cat /etc/passwd  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "              Shadow                                       ">> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
cat /etc/shadow  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "              Group                                       ">> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
cat /etc/group >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "              Hosts                                       ">> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
cat /etc/hosts  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "              Fstab                                       ">> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
cat /etc/fstab  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo " ====================================================="  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "              Servicios Configurados                  ">> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
/sbin/chkconfig --list|awk '{if($0 ~ "xinetd based services"){exit};print $0}'  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "              Parametros de Kernel                                       ">> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
/sbin/lsmod  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Informacion de Bases de datos  "  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
ps -edf|grep pmon |grep -v grep|awk '{print $1"    "NF}'|sort +0   >> $ruta$maquina.$fecha/config.$maquina.$fecha 2>&1
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/Procesos.txt
ps -fea | grep -v "ssh|ksh|sftp|bash|awk|grep|sshd"|sort -nk 2 >> $ruta$maquina.$fecha/Procesos.txt

echo "Informacion de Listeners       "  >> $ruta$maquina.$fecha/config.$maquina.$fecha
sh /usr/bin/tools/Listener.sh   >> $ruta$maquina.$fecha/config.$maquina.$fecha
sh /usr/bin/tools/Listener.sh   >> $ruta$maquina.$fecha/Listener.$fecha 2>&1
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Informacion de la Conformacion de Vgs en el sistema "  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
ls -lat /dev/*/group > $ruta$maquina.$fecha/lista_vg
cat /tmp/lista_vg >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Informacion de PuertosAbiertos  "  >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
netstat -tulpn | grep -v tcp6 | grep LISTEN | sort -k 4 >> $ruta$maquina.$fecha/config.$maquina.$fecha

cp -rp /etc/rc.config.d/netconf $ruta$maquina.$fecha/
cp -rp /etc/passwd   $ruta$maquina.$fecha/
cp -rp /etc/shadow   $ruta$maquina.$fecha/
cp -rp /etc/group  $ruta$maquina.$fecha/
cp -rp /etc/hosts   $ruta$maquina.$fecha/
cp -rp /etc/fstab   $ruta$maquina.$fecha/
cp -rp /etc/resolv.conf $ruta$maquina.$fecha/
cp -rp /etc/cluster/cluster.conf $ruta$maquina.$fecha/
cp -rp /etc/limits.conf $ruta$maquina.$fecha/ 
cp -rp /etc/sysctl.conf $ruta$maquina.$fecha/
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "Informacion Vgs                                       ">> $ruta$maquina.$fecha/config.$maquina.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
vgdisplay -v |grep -e "VG Name" -e "Cur PV" -e "Act PV" 1>> $ruta$maquina.$fecha/config.$maquina.$fecha
for i in `cat $ruta$maquina.$fecha/lista_vg |awk '{print $NF}'|awk '{FS="/"; print $3}'`
 do
  vgexport -p -f $ruta$maquina.$fecha/$i.dsk.$fecha  $i 
 vgexport -p -s -m $ruta$maquina.$fecha/$i.map.$fecha $i 
 /sbin/vgcfgbackup -f $ruta$maquina.$fecha/$i.backup.$fecha $i 
 done
cd $ruta$maquina.$fecha/
tar -cvf $ruta$maquina.$fecha/${maquina}_${fecha}.tar *
gzip $ruta$maquina.$fecha/${maquina}_${fecha}.tar
/usr/bin/sh /usr/bin/tools/envioftp.sh $maquina.$fecha.tar.gz
#/usr/bin/rm /var/tmp/InfoPrePos/$maquina.$fecha.tar.gz
#/usr/bin/rm /var/tmp/InfoPrePos/$maquina.$fecha.tar
/usr/bin/find /var/tmp/InfoPrePos -mtime +60 -type d -exec rm -r {} \;

#sh /usr/bin/tools/mailPrePos.sh $ruta$maquina.$fecha/config.$maquina.$fecha $maquina  texto
#sh /usr/bin/tools/mailPrePos.sh $ruta$maquina.$fecha/${maquina}_${fecha}_tar.gz $maquina Vgs
#rm $ruta$maquina.$fecha/*.map.$fecha *.dsk.$fecha *.backup.$fecha
echo "================================================================================" >> $ruta$maquina.$fecha/config.$maquina.$fecha
#Para Enviar Correo a UNIX HP
#mutt -e 'set realname='GDI_ADMUNIX'' -e 'my_hdr From:gdi_admunix@claro.com.co' -s "Informacion InfoPrePos Servidor $maquina `date`" gdi_admunix@claro.com.co < /etc/redhat-release -a $ruta$maquina.$fecha/${maquina}_${fecha}_tar.gz 

}

Solaris_InfoPP() {

#!/usr/bin/bash

# Variables
BASE="/var/tmp/InfoPrePos"
SERVER=$(hostname)
DATE=$(date '+%d-%m-%y_%H%M%S')
DIRLOG="${BASE}/${SERVER}.${DATE}"
RES="${BASE}/${SERVER}.${DATE}.tar"
LOG="${BASE}/${SERVER}.${DATE}/config.${SERVER}.${DATE}"

echo " Archivo Generado Queda en : ${DIRLOG}/config.${SERVER}.${DATE}"
if [ ! -d ${DIRLOG} ];
then
        mkdir -p ${DIRLOG}
else
        clear
        echo "Folder Exists"
fi

# Creates a segment on the final output
segment () {
        title=$1

        echo "===================================================="  >> ${LOG} 2>&1
        echo ${title} >> ${LOG} 2>&1
        echo >> ${LOG} 2>&1
}

# Receives a functions and logs the result
logger () {
        func=$1
        ${func} >> ${LOG} 2>&1
}

noinfo () {

        echo "No info available in this section..." >> ${LOG} 2>&1
}

echo
echo "Running infoPrePost for server $(hostname)"
echo

        # Show version kernel release
        segment Kernel_Release
        echo -en "KERNEL_RELEASE:\t\t"
        /usr/bin/uname -a >> ${LOG} 2>&1
        /usr/bin/cat /etc/release >> ${LOG} 2>&1
        if [[ $(uname -r) -eq "5.11" ]]; then
        pkg info entire >> ${LOG} 2>&1
        fi
        echo -e "[DONE]"

        # Show boot disks information
        echo -en "BOOTDISKS:\t\t"
        segment BootDisks
        /usr/sbin/prtconf -vp | grep disk | grep -v "'disk'" >> ${LOG} 2>&1
        /usr/sbin/eeprom | egrep -e "boot-device|devalias" >> ${LOG} 2>&1
        echo "Boot Filesystem: $(df -h /|grep "/"|awk '{print $1}')" >> ${LOG} 2>&1
        echo -e "[DONE]"

        #show mounted filesystems
        segment Filesystems
        echo "Total Filesystem: $(/usr/sbin/df -h|wc -l)" >> ${LOG} 2>&1
        echo "________________________________________________________" >> ${LOG} 2>&1
        echo -en "FILE SYSTEMS:\t\t"
        /usr/sbin/df -h|sort >> ${LOG} 2>&1
        echo -e "[DONE]"

        # Show SVM info
        echo -en "SVM CONF:\t\t"
        if [ -x "/usr/sbin/metastat" ]; then
                segment SolarisVolumeManager
                /usr/sbin/metastat -ac >> ${DIRLOG}/metastat 2>&1
                /usr/sbin/metastat -ap >> ${LOG} 2>&1
            else
                noinfo
        fi
        echo -e "[DONE]"

        # Show ZFS info
        echo -en "ZFS CONF:\t\t"
        segment ZFS
        ZFSQDEPTH=`echo zfs_vdev_max_pending::print | /usr/bin/mdb  -k 2>/dev/null|awk -F"x" '{print $NF}'`
        echo "____________ Queue depth ZFS ___________________________" >> ${LOG} 2>&1
        echo $((0x$ZFSQDEPTH)) >> ${LOG} 2>&1
        echo "____________ Queue depth UFS ___________________________" >> ${LOG} 2>&1
        echo "sd_max_throttle/D"| mdb -k  2>/dev/null |tail -1 >> ${LOG} 2>&1
        echo "________________________________________________________" >> ${LOG} 2>&1
        /usr/sbin/zpool list >> ${LOG} 2>&1
        echo "$(/usr/sbin/zpool list | grep -v NAME | wc -l) Total Zpools" >> ${LOG} 2>&1
        /usr/sbin/zpool status >> ${LOG} 2>&1
        /usr/sbin/zfs list -t all >> ${LOG} 2>&1
        /usr/sbin/zfs get all >> ${DIRLOG}/zfs_properties
        echo -e "[DONE]"

        # Show SAN disks
        echo -en "SAN DISKS:\t\t"
        segment SANdisks
        echo "$(/usr/sbin/luxadm probe >> ${LOG} 2>&1 |grep rdsk|wc -l) Total SAN disks" >> ${LOG} 2>&1
        /usr/sbin/luxadm probe 2>&1 |grep rdsk >> ${LOG} 2>&1
        /usr/sbin/cfgadm -al >> ${LOG} 2>&1
        echo -e "[DONE]"

        # Show physical memory
        echo -en "PH MEMORY:\t\t"
        segment Memory
        /usr/sbin/prtconf -v |grep "Memory size" >> ${LOG} 2>&1
        /usr/sbin/prtconf -v >> ${DIRLOG}/prtconf_v.out 2>&1
        echo "____________ Swap _____________________________" >> ${LOG} 2>&1
        /usr/sbin/swap -l >> ${LOG} 2>&1
        echo -e "[DONE]"

        # Show physical processors
        echo -en "PROCESSOR:\t\t"
        segment Processor
        /usr/sbin/psrinfo -p -v >> ${LOG} 2>&1
        echo -e "[DONE]"

        # Show network information
        echo -en "NETWORK:\t\t"
        segment Network
        if [ $(uname -r) -eq "5.10" ]; then
                /usr/sbin/dladm show-dev 2>&1 | grep -v down |grep -v unknown >> ${LOG} 2>&1
                /usr/sbin/ifconfig -a >> ${LOG} 2>&1
        elif [[ $(uname -r) -eq "5.11" ]]; then
                /usr/sbin/dladm show-phys 2>&1 | egrep -v "down|unknown" >> ${LOG} 2>&1
                /usr/sbin/ipadm show-addr >> ${LOG} 2>&1

        fi
        echo "Configured Network Cards:" >> ${LOG} 2>&1
        /usr/bin/netstat -in >> ${LOG} 2>&1
        /usr/bin/netstat -rn >> ${LOG} 2>&1
        echo -e "[DONE]"

        # Show services
        segment Services
        SERV_FAULT=`svcs -x`
        if [ "$SERV_FAULT" != "" ]; then
                echo "____________ Service Fail ____________________________" >> ${LOG} 2>&1
                svcs -x >> ${LOG} 2>&1
                echo "______________________________________________________" >> ${LOG} 2>&1
        fi
        svcs  >> ${LOG} 2>&1
        echo -e "[DONE]"

        # Show HBA information
        echo -en "HBA PORTS:\t\t"
        segment HBA
        /usr/sbin/luxadm -e port >> ${LOG} 2>&1
        /usr/sbin/fcinfo hba-port |egrep "No Adapters Found|HBA Port WWN" |awk '{print $NF}' >> ${LOG} 2>&1 | while read output
        do
            if [ ${output} -eq "" ]; then
                echo "No Adapters Found" >> ${LOG} 2>&1
            fi
                hwp=$(/usr/sbin/fcinfo hba-port $output|grep "OS Device Name:"|awk '{print $4}')
                State=$(/usr/sbin/fcinfo hba-port $output|grep "State"|awk '{print $2}')
                Speed=$(/usr/sbin/fcinfo hba-port $output|grep "Current"|awk '{print $3}')
                ntape=$(/usr/sbin/fcinfo remote-port -sl -p $output | grep Ultrium |wc -l)
                ndisk=$(/usr/sbin/fcinfo remote-port -sl -p $output | grep rdsk |wc -l)

                    if [ $ndisk -gt 0 ]
                     then
                        echo $server"|"$hwp"|"$State"|"$Speed"|"$output"|Datos" >> ${LOG} 2>&1
                    fi

                    if [ $ntape -gt 0 ]
                     then
                        echo $server"|"$hwp"|"$State"|"$Speed"|"$output"|BCK" >> ${LOG} 2>&1
                     fi

                   if [ $ndisk -eq 0 ] && [ $ntape -eq 0 ]
                     then
                        echo $server"|"$hwp"|"$State"|"$Speed"|"$output"|Libre" >> ${LOG} 2>&1
                    fi
        done
        echo -e "[DONE]"

        # Show NTP information
        echo -en "NTP CONF:\t\t"
        segment NTP
        /usr/sbin/ntpq -p >> ${LOG} 2>&1
        echo -e "[DONE]"

        # Show Cluster info
        echo -en "CLUSTER:\t\t"
        segment SolarisCluster
        if [ -x "/usr/cluster/bin/clrg" ]; then
                /usr/cluster/bin/clrg status >> ${LOG} 2>&1
                /usr/cluster/bin/scstat >> ${LOG} 2>&1
                echo -e "[DONE]"
            else
                noinfo
                echo -e "[DONE]"
        fi

        # Show CRONTABS info
        echo -en "CRONTABS:\t\t"
        segment CRONTABS
        echo "$(/usr/bin/ps -fea|grep cron |grep -v grep|wc -l) Total Running crontabs" >> ${LOG} 2>&1
        /usr/bin/ps -fea|grep cron |grep -v grep >> ${LOG} 2>&1
        echo -e "[DONE]"

        # Show zones info
        echo -en "ZONE CONF:\t\t"
        segment Zones
        /usr/sbin/zoneadm list -cv >> ${LOG} 2>&1
        /usr/sbin/zoneadm list -cv | grep -vi name | awk '{print $2}' | while read output; do echo "%%%%%% $output %%%%%%" >> ${LOG} 2>&1; /usr/sbin/zonecfg -z $output export >> ${LOG} 2>&1; done
        echo -e "[DONE]"

        # Show ORACLEVM info
        echo -en "ORACLEVM:\t\t"
        segment ORACLEVM
        if [ -x "/usr/sbin/ldm" ]; then
                /usr/sbin/ldm list >> ${LOG} 2>&1
                /usr/sbin/ldm list -l >> ${DIRLOG}/ldm_list_l 2>&1
                /usr/sbin/ldm list-bindings >> ${DIRLOG}/ldm_list_bindings 2>&1
                echo -e "[DONE]"
            else
                noinfo
                echo -e "[DONE]"
        fi

        # List current processes list.
        echo -en "PROCESSES:\t\t"
        /usr/bin/ps -fea >> ${DIRLOG}/ps_fea.out
        segment Process_JAVA
        echo -en "JAVA PROCESSES:\t\t"
        ps -ef |grep java |grep -v grep |sort -k 9|awk '{print $1 "       "$9,$10,$11,$12,$13,$14}'  >> ${LOG} 2>&1
        segment Process_DATABASE
        echo -en "DATABASE PROCESSES:\t\t"
        ps -ef|grep pmon|grep -v "grep pmon"|awk '{print $1 "    " $NF}'  >> ${LOG} 2>&1
        segment Listener
        ps -edf|grep tns |grep -v grep|awk '{print $10}' >> ${LOG} 2>&1
        echo -e "[DONE]"

        # List ASM disks
        echo -en "ASM DISKS:\t\t"
        segment ASM
                ls -ltrh /dev/asmdisk >> ${DIRLOG}/asmdisk_dir.out
        echo -e "[DONE]"

        # Show Puertos en escucha
        echo -en "NETSAT CONF:\t\t"
        segment NETSTAT
        netstat -an | grep -v tcp6 | grep LISTEN | sort -k 4 >> ${LOG} 2>&1
        echo -e "[DONE]"

        # Procesos en ejecucion
        echo -en "PS -FEA CONF:\t\t"
        segment PS
        ps -fea |grep -v "ssh|ksh|sftp|bash|awk|grep|sshd"|sort -nk 2 >>  ${DIRLOG}/Procesos.txt 2>&1
        echo -e "[DONE]"
    
        # Backup conf files
        echo -en "CONF FILES:\t\t"
        /usr/bin/cp -rp /etc/passwd ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/resolv.conf ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/hosts ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/shadow ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/group ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/hosts ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/vfstab ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/system ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /var/spool/cron/crontabs ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/netmasks ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/defaultrouter ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/hostname.* ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/profile ${DIRLOG} >> ${LOG} 2>&1
        /usr/bin/cp -rp /etc/user_attr ${DIRLOG} >> ${LOG} 2>&1
        #### Se agrega la salida de verlun.sh 24/11/2017 04:00 pm
        /usr/bin/tools/verlun.sh > ${DIRLOG}/verlun.txt
        echo -e "[DONE]"

        # Compressing results
        echo -en "COMPRESS:\t\t"
        /usr/sbin/tar -cf ${RES} ${DIRLOG}
                /usr/bin/gzip ${RES}
                #/bin/mv ${RES}.gz ${DIRLOG}
        echo -e "[DONE]"
                /usr/bin/sh /usr/bin/tools/envioftp.sh ${SERVER}.${DATE}.tar.gz
                /usr/bin/rm ${BASE}/${SERVER}.${DATE}.tar.gz
                /usr/bin/find ${BASE} -mtime +60 -type d -exec rm -r {} \;
        # Sending email
        #/usr/bin/uuencode ${RES}.gz ${RES} |mailx -r GDI_ADMSUN@claro.com.co -s "InfoPrePost for ${SERVER} - ${DATE}" gdi_admsun@claro.com.co

        # Removing logs
        #echo -en "CLEANING UP:\t\t"
        #/usr/bin/rm -R ${DIRLOG}
        #echo -e "[DONE]"
        #echo
        #echo "Finished."
}


OS=`uname -s`

case "$OS" in
"SunOS")
Solaris_InfoPP
;;
"Linux")
Linux_InfoPP
;;
"HP-UX")
HPUX_InfoPP

;;
"AIX")
AIX_InfoPP
;;

esac
exit 0
}
ValEje
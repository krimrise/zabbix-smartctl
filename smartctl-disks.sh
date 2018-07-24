#!/bin/sh
#
# smartctl-disks.sh [<dev> <disk_type> [client_hostname_in_zabbix]]
# Example1: smartctl-disks.sh
# Example2: smartctl-disks.sh sda sat
#
# 20171130 v1.0 stas630
# sudo apt-get install smartmontools
#
ZBX_CONFIG_AGENT="/etc/zabbix/zabbix_agentd.conf"
AGENT_CFG='/etc/zabbix/zabbix_agentd.conf'
LIST="/etc/zabbix/scripts/list"
# Uncomment if need log
#LOG="/var/log/zabbix-agent/smartctl-disks.log"
#
#
export PATH=/sbin:/usr/sbin:/bin:/usr/bin

DEV_NAME=$1
DEV_TYPE=$2
HOSTNAME=`hostname`
DEBUG="False"

ScanDevices ()
{
          sudo /usr/sbin/smartctl --scan-open | awk 'BEGIN{print "{\"data\":["}{
            if(NR!=1){
              printf ","
            }
            printf "{ \"{#DEVNAME}\":\""substr($1,6)"\", \"{#DEVTYPE}\":\""$3"\" }\n"
          }END{
            print "]}"
          }'
}

AllDevType ()
{
	  sudo /usr/sbin/smartctl --scan-open | awk 'BEGIN{ }{
	    if(NR!=1){
	    }
	    printf ""substr($1,6)" "$3" \n"
	  }END{
	  }' > ${LIST}
}

# args dev_name dev_type hostname tmps
SmartDevice ()
{
	sudo /usr/sbin/smartctl -A -H -i -d $2 /dev/$1 | awk 'BEGIN{
	  INFO_FIELDS=";Model Family;Device Model;Serial Number;Firmware Version;User Capacity;Sector Size;Rotation Rate;"
	  ATTR_FIELDS=";1;3;4;5;7;9;10;11;12;177;190;192;193;194;196;197;198;199;200;233;"
	}
	function trim(s){
	  sub(/^[ \t]+/,"",s)
	  sub(/[ \t]+$/,"",s)
	  return s;
	}
	function toattr(s){
	  gsub(/ /,"_",s)
	  return tolower(s);
	}
	{
	  if($0=="=== START OF INFORMATION SECTION ==="){ type="info"; next
	  }else if($0=="=== START OF READ SMART DATA SECTION ==="){ type="healf"; next
	  }else if($1=="ID#"){ type="attr"; next
	  }
	  if(type=="info"){
	    split($0,linearr,":")
	    if(index(INFO_FIELDS,";"trim(linearr[1])";")){
	      print "'${3}' smartctl.info['${1}',"toattr(trim(linearr[1]))"] \""trim(linearr[2])"\"" >"'${4}'"
	    }
	    next
	  }
	  if(type=="healf"){
	    split($0,linearr,":")
	    if(linearr[1]=="SMART overall-health self-assessment test result"){
	      print "'${3}' smartctl.smart['${1}',test_result] \""trim(linearr[2])"\"" >"'${4}'"
	    }
	    next
	  }
	  if(type=="attr"){
	    if(NF<10||!index(ATTR_FIELDS,";"$1";")) next
	    print "'${3}' smartctl.smart['${1}',"$1",attribute_name] \""$2"\"" >"'${4}'"
	    print "'${3}' smartctl.smart['${1}',"$1",flag] \""$3"\"" >"'${4}'"
	    print "'${3}' smartctl.smart['${1}',"$1",value] "$4 >"'${4}'"
	    print "'${3}' smartctl.smart['${1}',"$1",worst] "$5 >"'${4}'"
	    print "'${3}' smartctl.smart['${1}',"$1",thresh] "$6 >"'${4}'"
	    print "'${3}' smartctl.smart['${1}',"$1",type] \""$7"\"" >"'${4}'"
	    print "'${3}' smartctl.smart['${1}',"$1",updated] \""$8"\"" >"'${4}'"
	    print "'${3}' smartctl.smart['${1}',"$1",when_failed] \""$9"\"" >"'${4}'"
	    print "'${3}' smartctl.smart['${1}',"$1",raw_value] "$10 >"'${4}'"
	  }
	}'
}

TMPS=`mktemp -t zbx-smart.XXXXXXXXXXXXXXXXXXX`
TMPS2=`mktemp -t zbx-smart-t.XXXXXXXXXXXXXXXXXXX`

if [ $# -eq 0 ]; then
	ScanDevices
	AllDevType
elif [ ${1} = "all" ]; then
	while read attr; do
		SmartDevice ${attr} ${HOSTNAME} ${TMPS}
		cat ${TMPS} >> ${TMPS2}
	done < ${LIST}
	if [ ${DEBUG} = "True" ]; then
		cat ${TMPS2}
	fi
	cat ${TMPS2} | /usr/bin/zabbix_sender -c $AGENT_CFG -i -
fi

#if [ -z ${HOSTNAME} ]; then
#  cat ${TMPS}
#elif [ -s ${TMPS} ]; then
#  if [ -z ${LOG} ]; then
#    zabbix_sender -c ${ZBX_CONFIG_AGENT} -i ${TMPS}
#  else
#    zabbix_sender -c ${ZBX_CONFIG_AGENT} -i ${TMPS} -vv >> ${LOG} 2>&1
#  fi
#fi

rm -f ${TMPS}
rm -f ${TMPS2}

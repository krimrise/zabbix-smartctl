#!/bin/bash

SIPDiscovery ()
{
   asterisk -rx 'sip show registry' | awk 'BEGIN{print "{\"data\":["}
   {
     if((NR>1) && ($3 !~ /registrations/)){
       split($1, linearr, ":")
       if(NR!=2){
         printf ","
       }
       printf "{ \"{#SIPNAME}\":\""linearr[1]"\", \"{#SIPUSER}\":\""$3"\" }\n"
     }
   }
   END{
     print "]}"
   }'
}

SIPStatus ()
{
  asterisk -rx 'sip show registry' | awk -v SIP=$1 '{split(SIP, linearr, "/")
      if(($1 ~ linearr[1]) && ($3 ~ linearr[2])){
      print $5
      }
  }'
}


case $1 in
  discovery)
    SIPDiscovery
    ;;
  status)
    SIPStatus $2
    ;;
  *)
    echo ";)"
    ;;
esac

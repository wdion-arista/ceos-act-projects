#!/bin/bash
# File to format the correct name for the AVD Fabric

dir=$1
FABRIC_NAME_UPPER=$2
FABRIC_NAME=$3
export TARGET_SITE_RAW=$(basename "$dir"); 

if [ "$FABRIC_NAME_UPPER" = "false" ]; then 
export TARGET_SITE="$TARGET_SITE_RAW"; 
else 
export TARGET_SITE=$(echo "$TARGET_SITE_RAW" | tr '[:lower:]' '[:upper:]'); 
fi;

if [ "$FABRIC_NAME" = "false" ]; then 
export FABRIC_BASENAME=""; 
else 
export FABRIC_BASENAME="_FABRIC"; 
fi;

export ANSIBLE_TARGET_HOSTS="$TARGET_SITE$FABRIC_BASENAME";
echo "$ANSIBLE_TARGET_HOSTS";


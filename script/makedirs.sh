#!/bin/bash


for var in "$@"
do
    if [ -d "$var" ];
    then
        :
    else
      mkdir -p "$var"
      echo "Creating $var"
    fi
    chown -R docker:docker "$var"
    echo "Changing ownership of $var"

done

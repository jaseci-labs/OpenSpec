#!/bin/bash
# alternate full test suites: orig, jac-before, jac-after; two rounds
declare -A DIR=([orig]=/home/jayanaka/neojac-deslop/base/OpenSpec [before]=/tmp/osbench/jac-before [after]=/home/jayanaka/neojac-deslop/repos/Fission-AI_OpenSpec)
for round in ${ROUNDS:-1 2}; do
  order="orig before after"; [ $round = 2 ] && order="after before orig"
  for s in $order; do
    l0=$(cut -d' ' -f1 /proc/loadavg)
    cd ${DIR[$s]}
    /usr/bin/time -f "%e %U %S" -o /tmp/osbench/suite-$s-$round.time neojac npx vitest run --reporter=json --outputFile=/tmp/osbench/suite-$s-$round.json > /dev/null 2>&1
    l1=$(cut -d' ' -f1 /proc/loadavg)
    echo "$s round$round $(cat /tmp/osbench/suite-$s-$round.time) load $l0 $l1"
  done
done

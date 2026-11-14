#!/usr/bin/env bash
# shard.sh SHARD BASESEED NBATCH  -> 500-program batches, each with its own seed
s=$1; base=$2; nb=$3; cd /tmp/beru-c9full
for b in $(seq 0 $((nb-1))); do
  seed=$((base + b))
  python3 -I tests/random/c9/run.py --nprog 500 --ncyc 1000 --seed $seed --rtl /tmp/beru-rtlmain/rtl --out /tmp/beru-c9full/out$s > logs/shard$s-batch$b.log 2>&1
  tail -1 logs/shard$s-batch$b.log | sed "s/^/shard$s batch$b seed$seed: /" >> logs/progress.txt
  rm -rf /tmp/beru-c9full/out$s
done

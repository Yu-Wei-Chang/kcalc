#!/usr/bin/env bash

CALC_DEV=/dev/calc
CALC_MOD=calc.ko
LIVEPATCH_CALC_MOD=livepatch-calc.ko

source scripts/eval.sh

test_op() {
    local expression=$1 
    echo "Testing " ${expression} "..."
    echo -ne ${expression}'\0' > $CALC_DEV
    fromfixed $(cat $CALC_DEV)
}

test_fib() {
    local fib_seq=(0 1 1 2 3 5 8 13 21 34 55 89 144
        233 377 610 987 1597 2584 4181 6765 10946
	17711 28657 46368 75025 121393 196418 317811
	514229 832040 1346269 2178309 3524578 5702887
	9227465 14930352 24157817 39088169 63245986
	102334155 165580141)
    for i in ${!fib_seq[*]}
    do
        echo "Testing fib("$i")..."
	echo -ne "fib("$i")\0" > $CALC_DEV
	if [ $(fromfixed $(cat $CALC_DEV)) != ${fib_seq[$i]} ]; then
	    echo "Failed! Fib("$i") should be "${fib_seq[$i]}
	fi
    done
}

if [ "$EUID" -eq 0 ]
  then echo "Don't run this script as root"
  exit
fi

sudo rmmod -f livepatch-calc 2>/dev/null
sudo rmmod -f calc 2>/dev/null
sleep 1

modinfo $CALC_MOD || exit 1
sudo insmod $CALC_MOD
sudo chmod 0666 $CALC_DEV
echo

# multiply
test_op '6*7'

# add
test_op '1980+1'

# sub
test_op '2019-1'

# div
test_op '42/6'
test_op '1/3'
test_op '1/3*6+2/4'
test_op '(1/3)+(2/3)'
test_op '(2145%31)+23'
test_op '0/0' # should be NAN_INT

# binary
test_op '(3%0)|0' # should be 0
test_op '1+2<<3' # should be (1 + 2) << 3 = 24
test_op '123&42' # should be 42
test_op '123^42' # should be 81

# parens
test_op '(((3)))*(1+(2))' # should be 9

# assign
test_op 'x=5, x=(x!=0)' # should be 1
test_op 'x=5, x = x+1' # should be 6

# fancy variable name
test_op 'six=6, seven=7, six*seven' # should be 42
test_op '小熊=6, 維尼=7, 小熊*維尼' # should be 42
test_op 'τ=1.618, 3*τ' # should be 3 * 1.618 = 4.854
test_op '$(τ, 1.618), 3*τ()' # shold be 3 * 1.618 = 4.854

# functions
test_op '$(zero), zero()' # should be 0
test_op '$(one, 1), one()+one(1)+one(1, 2, 4)' # should be 3
test_op '$(number, 1), $(number, 2+3), number()' # should be 5

# pre-defined function
test_op 'nop()'

# Livepatch
sudo insmod $LIVEPATCH_CALC_MOD
sleep 1
echo "livepatch was applied"
test_op 'nop()'
dmesg | tail -n 6

echo "Testing Fibonacci sequence..."
test_fib

echo "Disabling livepatch..."
sudo sh -c "echo 0 > /sys/kernel/livepatch/livepatch_calc/enabled"
sleep 2
sudo rmmod livepatch-calc

sudo rmmod calc

# epilogue
echo "Complete"

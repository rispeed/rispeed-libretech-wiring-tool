#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2021 Da Xue <da@libre.computer>

# PURPOSE: testing SPI chip select, modes, and frequency   

if [ "$USER" != "root" ]; then
	echo "Please run this as root." >&2
	exit 1
fi

if [ -z "$1" ]; then
	echo "$0 SPIDEVNUM" >&2
	exit 1
fi

if ! which spi-config > /dev/null; then
	echo "$0 requires spi-config from spi-tools." >&2
	exit 1
fi

SPIDEVNUM="$1"
SPICSMAX="0"
while true; do
	if [ ! -e "/dev/spidev${SPIDEVNUM}.${SPICSMAX}" ]; then
		if [ "$SPICSMAX" -eq 0 ]; then
			echo "SPIDEV $SPIDEVNUM does not exist." >&2
			exit 1
		fi
		break
	fi
	((SPICSMAX++))
done
echo "SPIDEV $SPIDEVNUM has $SPICSMAX chip enable(s)." >&2

freq=500000
chip=0
mode=0
data='S'
block=512
stop=0

function TEST_SPI_help(){
	echo "Press q to quit, m to change mode, c to change chip select, w and s to double/half freq, d to change ascii byte." >&2
}

TEST_SPI_help

while [ $stop -eq 0 ]; do
	echo "Testing SPI ${SPIDEVNUM} CHIP ${chip} MODE ${mode} @ ${freq}Hz." >&2
	dev=/dev/spidev$SPIDEVNUM.$chip
	spi-config -d $dev -m $mode -s $freq -w &
	spi_config_pid=$!
	tr '\0' "$data" < /dev/zero | dd bs=$block of=$dev &
	dd_pid=$!
	read -n 1 ctrl_char
	kill $dd_pid
	kill $spi_config_pid
	case "$ctrl_char" in
		q)
			stop=1
			break
			;;
		m)
			mode=$((++mode % 4))
			;;
		c)
			chip=$((++chip % SPICSMAX))
			;;
		w)
			freq=$((freq << 1))
			;;
		d)
			echo >&2
			read -n 1 -p "Change ASCII byte '$data' to: " data >&2
			echo >&2
			;;
		s)
			if [ $freq -lt 31250 ]; then
				echo "Frequency is already at minimum." >&2
			else
				freq=$((freq >> 1))
			fi
			;;
		h)
			TEST_SPI_help
			;;
		*)
			echo "Unrecognized command character $ctrl_char." >&2
			TEST_SPI_help
			;;
	esac
done


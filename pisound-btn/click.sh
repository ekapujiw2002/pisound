#!/bin/sh

# pisound-btn daemon for the pisound button.
# Copyright (C) 2016  Vilniaus Blokas UAB, http://blokas.io/pisound
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 2 of the
# License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

PURE_DATA_STARTUP_SLEEP=3

. $(dirname $(readlink -f $0))/common.sh

log "pisound button clicked!"

PURE_DATA=`which puredata`

if [ -z $PURE_DATA ]; then
	log "Pure Data was not found! Install by running: sudo apt-get install puredata"
	exit 0
fi

log "Searching for main.pd in USB storage!"

PURE_DATA_PATCH=`find /media 2> /dev/null | grep main.pd | head -1`

if [ -z $PURE_DATA_PATCH ]; then
	log "No patch found! Exiting..."
	exit 0
else
	log "Found patch: $PURE_DATA_PATCH"
fi

log "Killing all Pure Data instances!"

for pd in `ps -C puredata --no-headers | awk '{print $1;}'`; do
	log "Killing pid $pd..."
	kill $pd
done

log "All sanity checks succeeded, flashing MIDI output LED to indicate it."
flash_out_led

log "Launching Pure Data."
nohup puredata -alsa -audioadddev pisound -alsamidi -r 48000 -mididev 1 -send ";pd dsp 1" $PURE_DATA_PATCH > /dev/null 2>&1 &

if [ $? -eq 0 ]; then
	log "Pure Data started successfully!"
else
	log "Pure Data failed to start!"
	exit 1
fi

log "Giving $PURE_DATA_STARTUP_SLEEP seconds for Pure Data to start up before connecting MIDI ports."
sleep $PURE_DATA_STARTUP_SLEEP

READABLE_PORTS=`aconnect -i | egrep -iv "(Through|Pure Data|System)" | egrep -o "[0-9]+:" | egrep -o "[0-9]+"`

RANGE="0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"

log "Pure Data started!"
flash_out_led

log "Connecting all MIDI ports to and from Pure Data."

# After connecting the ports, we can no longer flash the MIDI out LED.
for p in $READABLE_PORTS; do
	for i in $RANGE; do
		aconnect $p:$i "Pure Data" 2> /dev/null;
		aconnect "Pure Data:1" $p:$i 2> /dev/null;
	done;
done

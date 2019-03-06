#!/bin/bash

# Copyright (c) 2019 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

set -u

####################
# argument parsing #
####################
! getopt --test > /dev/null
if [ ${PIPESTATUS[0]} != 4 ]; then
    echo '`getopt --test` failed in this environment.'
    exit 1
fi

OPTS="hvp:o:r:"
LONGOPTS="help,verbose,pid:,output:,rows:"
print_help() {
	echo "Usage: $(basename $0) --pid <process ID> [--out base_filename] [--rows 100000] [--verbose]"
	echo "E.g.: $(basename $0) --pid 12345 --out bla # produces bla.rrd, bla.sh and bla.svg"
}
! PARSED=$(getopt --options=${OPTS} --longoptions=${LONGOPTS} --name "$0" -- "$@")
if [ ${PIPESTATUS[0]} != 0 ]; then
    # getopt has complained about wrong arguments to stdout
    exit 1
fi
# read getopt's output this way to handle the quoting right
eval set -- "$PARSED"
VERBOSE="0"
PID=""
OUT="out"
ROWS="100000"
while true; do
	case "$1" in
		-h|--help)
			print_help
			exit
			;;
		-v|--verbose)
			VERBOSE=1
			shift
			;;
		-p|--pid)
			PID="$2"
			shift 2
			;;
		-o|--output)
			OUT="$2"
			shift 2
			;;
		-r|--rows)
			ROWS="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			echo "argument parsing error"
			exit 1
	esac
done

[ -z "${PID}" ] && { echo "Error: missing PID!"; print_help; exit 1; }
PROCESS_NAME="$(ps -p ${PID} -o comm --no-headers)"
[ "$(basename $0)" = "${OUT}.sh" ] && { echo "Choose another output filename."; print_help; exit 1; }

###############################
# check for required programs #
###############################
for PROGRAM in pidstat rrdtool gawk nethogs; do
	type "$PROGRAM" &>/dev/null || { echo "Error: '${PROGRAM}' missing"; exit 1; }
done
# nethogs usually needs root access or some capabilities
ERROR=$(nethogs -c 2 -t 2>&1 >/dev/null)
[ $? != 0 ] && { echo "$ERROR"; exit 1; }

########################
# network traffic info #
########################
net_data() {
	DATA="$(nethogs -c 2 -t 2>/dev/null | grep "/${PID}/" | tail -n 1 | gawk '{print $2":"$3}')"
	[ -z "${DATA}" ] && DATA="0:0"
	echo -n "${DATA}"
}

########################
# SVG graph generation #
########################
draw_graph() {
	END_TIME="$(date +%s)"
	TOTAL_SECONDS="$[${END_TIME} - ${START_TIME} + 1]"
	# arithmetic expansion again
	(( i = TOTAL_SECONDS, SECONDS = i % 60, i /= 60, MINUTES = i % 60, HOURS = i / 60 ))
	DURATION_FORMATTED="$(printf "%d\\:%02d\\:%02d" ${HOURS} ${MINUTES} ${SECONDS})"
	MIN_WIDTH=1000
	WIDTH=${TOTAL_SECONDS}
	[ ${WIDTH} -lt ${MIN_WIDTH} ] && WIDTH=${MIN_WIDTH}

	# We want a script here in order to easily modify the graph without collecting the data again.
	cat > "${OUT}.sh" <<EOF
#!/bin/bash

# RGB or RGBA
COLOURS=(
	"#fc8d597F"
	"#d73027"
	"#99d8c9"
	"#23ff7f"
	"#8c64007F"
	"#91bfdb"
	"#4575b47F"
)
LINE_WIDTH=1

rrdtool graph "${OUT}.svg" \\
	--imgformat SVG \\
	--title "${PROCESS_NAME} statistics (normalised to their maximum values)" \\
	--watermark "$(date)" \\
	--vertical-label "% of maximum" \\
	--slope-mode \\
	--alt-y-grid \\
	--rigid \\
	--start ${START_TIME} \\
	--end ${END_TIME} \\
	--width ${WIDTH} \\
	--height 800 \\
	DEF:cpu="${OUT}.rrd":cpu:AVERAGE \\
		VDEF:max_cpu=cpu,MAXIMUM \\
		CDEF:norm_cpu=cpu,100,\*,max_cpu,/ \\
		AREA:norm_cpu\${COLOURS[0]}:"%CPU" \\
		GPRINT:max_cpu:"(max\\: %.2lf%%\\g" \\
		GPRINT:cpu:AVERAGE:", avg\\: %.2lf%%)" \\
		COMMENT:"\\n" \\
	DEF:rss="${OUT}.rrd":rss:AVERAGE \\
		VDEF:max_rss=rss,MAXIMUM \\
		CDEF:norm_rss=rss,100,\*,max_rss,/ \\
		LINE\${LINE_WIDTH}:norm_rss\${COLOURS[1]}:"RSS" \\
		GPRINT:rss:MIN:"(min\\: %.2lf KB\\g" \\
		GPRINT:max_rss:", max\\: %.2lf KB)" \\
		COMMENT:"\\n" \\
	DEF:stack="${OUT}.rrd":stack:AVERAGE \\
		VDEF:max_stack=stack,MAXIMUM \\
		CDEF:norm_stack=stack,100,\*,max_stack,/ \\
		LINE\${LINE_WIDTH}:norm_stack\${COLOURS[2]}:"Stack" \\
		GPRINT:stack:MIN:"(min\\: %.2lf KB\\g" \\
		GPRINT:max_stack:", max\\: %.2lf KB)" \\
		COMMENT:"\\n" \\
	DEF:net_tx="${OUT}.rrd":net_tx:AVERAGE \\
		VDEF:max_net_tx=net_tx,MAXIMUM \\
		CDEF:norm_net_tx=net_tx,100,\*,max_net_tx,/ \\
		LINE\${LINE_WIDTH}:norm_net_tx\${COLOURS[3]}:"Net TX" \\
		GPRINT:max_net_tx:"(max\\: %.2lf KB/s\\g" \\
		GPRINT:net_tx:AVERAGE:", avg\\: %.2lf KB/s)" \\
		COMMENT:"\\n" \\
	DEF:net_rx="${OUT}.rrd":net_rx:AVERAGE \\
		VDEF:max_net_rx=net_rx,MAXIMUM \\
		CDEF:norm_net_rx=net_rx,100,\*,max_net_rx,/ \\
		AREA:norm_net_rx\${COLOURS[4]}:"Net RX" \\
		GPRINT:max_net_rx:"(max\\: %.2lf KB/s\\g" \\
		GPRINT:net_rx:AVERAGE:", avg\\: %.2lf KB/s)" \\
		COMMENT:"\\n" \\
	DEF:disk_read="${OUT}.rrd":disk_read:AVERAGE \\
		VDEF:max_disk_read=disk_read,MAXIMUM \\
		CDEF:norm_disk_read=disk_read,100,\*,max_disk_read,/ \\
		LINE\${LINE_WIDTH}:norm_disk_read\${COLOURS[5]}:"Disk read" \\
		GPRINT:max_disk_read:"(max\\: %.2lf KB/s\\g" \\
		GPRINT:disk_read:AVERAGE:", avg\\: %.2lf KB/s)" \\
		COMMENT:"\\n" \\
	DEF:disk_write="${OUT}.rrd":disk_write:AVERAGE \\
		VDEF:max_disk_write=disk_write,MAXIMUM \\
		CDEF:norm_disk_write=disk_write,100,\*,max_disk_write,/ \\
		AREA:norm_disk_write\${COLOURS[6]}:"Disk write" \\
		GPRINT:max_disk_write:"(max\\: %.2lf KB/s\\g" \\
		GPRINT:disk_write:AVERAGE:", avg\\: %.2lf KB/s)" \\
		COMMENT:"\\n" \\
	COMMENT:"Duration\\: ${DURATION_FORMATTED}\\n" \\
	>/dev/null

EOF

	chmod 755 "${OUT}.sh"
	./"${OUT}.sh"
}

###################
# data collection #
###################
rrdtool create "${OUT}.rrd" --step 1 \
	DS:cpu:GAUGE:5:U:U \
	DS:rss:GAUGE:5:U:U \
	DS:stack:GAUGE:5:U:U \
	DS:disk_read:GAUGE:5:U:U \
	DS:disk_write:GAUGE:5:U:U \
	DS:net_tx:GAUGE:5:U:U \
	DS:net_rx:GAUGE:5:U:U \
	RRA:AVERAGE:0.5:1:${ROWS}

# don't interrupt the script on Ctrl+C (used to interrupt pidstat)
trap '' INT
echo -e "Press Ctrl+C to interrupt data collection, or wait until the target process ends.\n"

START_TIME="$(date +%s)"
LINE_NO_MAX="40"
LINE_NO="${LINE_NO_MAX}"
GRAPH_GENERATION_INTERVAL="60" # in seconds

# TODO: add voluntary context switches
# we don't rely on pidstat column order, in case it varies between sysstat/kernel versions
pidstat -p ${PID} -h -H -u -d -r -s -w 1 | gawk '
/^#/ {
	for(i = 1; i <= NF; i++) {
		if($i == "%CPU") {
			cpu = i - 1
			continue
		}
		if($i == "RSS") {
			rss = i - 1
			continue
		}
		if($i == "StkRef") {
			stack = i - 1
			continue
		}
		if($i == "kB_rd/s") {
			disk_read = i - 1
			continue
		}
		if($i == "kB_wr/s") {
			disk_write = i - 1
			continue
		}
	}
}
/^[0-9]/ {
	print $1, $cpu, $rss, $stack, $disk_read, $disk_write
	fflush(stdout)
}
' | while read LINE; do
	[ "${LINE_NO}" = "${LINE_NO_MAX}" ] && LINE_NO=0 && {
		[ "${VERBOSE}" = "1" ] && echo "timestamp %CPU RSS stack disk_read disk_write net_TX:net_RX";
	}
	# arithmetic expansion looks weird, doesn't it?
	(( LINE_NO += 1 ))
	NET_DATA="$(net_data)"
	[ "${VERBOSE}" = "1" ] && echo "${LINE} ${NET_DATA}"
	rrdtool update "${OUT}.rrd" "$(echo -n ${LINE} | tr ' ' ':'):${NET_DATA}"
	# can't wait until the end to see the data? have some periodic SVG refresh:
	[ "$[$(echo ${LINE} | cut -d ' ' -f 1) % ${GRAPH_GENERATION_INTERVAL}]" = "0" ] && draw_graph
done

# draw it one final time
draw_graph
echo -e "\nYou can modify and run '${OUT}.sh' to generate a new '${OUT}.svg'."


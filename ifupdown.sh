#!/bin/sh

# Only act on loopback interface actions
[ "$IFACE" = "lo" ] || exit 0

export PATH=/bin:/sbin:/usr/bin:/usr/sbin

. /etc/default/wikimedia-lvs-realserver

do_stop() {
	# Delete the current service IPs from the loopback interface
	ip addr show label "lo:LVS" | awk '{ print $2 }' | while read SIP; do
		ip addr del $SIP label "lo:LVS" dev lo
	done

	# We don't have a label, so delete every globally scoped IPv6 from lo
	ip -6 addr ls dev lo scope global | sed -nr 's/.*inet6 //p' | while read SIPv6; do
		ip -6 addr del $SIPv6 dev lo
	done
}

do_start() {
	# Add the service IPs to the loopback interface
	for SIP in $LVS_SERVICE_IPS; do
		if echo $SIP | grep -q ":"; then
			# label is ignored on IPv6
			ip addr add $SIP/128 scope global dev lo
		else
			ip addr add $SIP/32 label "lo:LVS" dev lo
		fi
	done
}

case $MODE in
	start)
		# sanity check
		[ -z "$SYSCTLFILE" ] && exit 0
		[ -z "$LVS_SERVICE_IPS" ] && exit 0

		# cleanup after ourselves first
		do_stop

		# Set the sysctl variables to ignore ARP for the LVS service IPs
		sysctl -p $SYSCTLFILE

		do_start
		;;
	stop)
		do_stop
		;;
esac

exit 0

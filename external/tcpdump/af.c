

#ifndef lint
static const char rcsid[] _U_ =
    "@(#) $Header: /tcpdump/master/tcpdump/af.c,v 1.3.2.1 2007/02/26 13:33:17 hannes Exp $ (LBL)";
#endif

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <tcpdump-stdinc.h>
#include "interface.h"
#include "af.h"

struct tok af_values[] = {
    { 0,                      "Reserved"},
    { AFNUM_INET,             "IPv4"},
    { AFNUM_INET6,            "IPv6"},
    { AFNUM_NSAP,             "NSAP"},
    { AFNUM_HDLC,             "HDLC"},
    { AFNUM_BBN1822,          "BBN 1822"},
    { AFNUM_802,              "802"},
    { AFNUM_E163,             "E.163"},
    { AFNUM_E164,             "E.164"},
    { AFNUM_F69,              "F.69"},
    { AFNUM_X121,             "X.121"},
    { AFNUM_IPX,              "Novell IPX"},
    { AFNUM_ATALK,            "Appletalk"},
    { AFNUM_DECNET,           "Decnet IV"},
    { AFNUM_BANYAN,           "Banyan Vines"},
    { AFNUM_E164NSAP,         "E.164 with NSAP subaddress"},
    { AFNUM_L2VPN,            "Layer-2 VPN"},
    { AFNUM_VPLS,             "VPLS"},
    { 0, NULL},
};

struct tok bsd_af_values[] = {
    { BSD_AFNUM_INET, "IPv4" },
    { BSD_AFNUM_NS, "NS" },
    { BSD_AFNUM_ISO, "ISO" },
    { BSD_AFNUM_APPLETALK, "Appletalk" },
    { BSD_AFNUM_IPX, "IPX" },
    { BSD_AFNUM_INET6_BSD, "IPv6" },
    { BSD_AFNUM_INET6_FREEBSD, "IPv6" },
    { BSD_AFNUM_INET6_DARWIN, "IPv6" },
    { 0, NULL}
};

/*	$NetBSD: policy.c,v 1.6.4.1 2007/08/01 11:52:21 vanhu Exp $	*/

/*	$KAME: policy.c,v 1.46 2001/11/16 04:08:10 sakane Exp $	*/


#include "config.h"

#include <sys/param.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/queue.h>

#include <netinet/in.h>
#include PATH_IPSEC_H

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#include "var.h"
#include "misc.h"
#include "vmbuf.h"
#include "plog.h"
#include "sockmisc.h"
#include "debug.h"

#include "policy.h"
#include "localconf.h"
#include "isakmp_var.h"
#include "isakmp.h"
#include "oakley.h"
#include "handler.h"
#include "strnames.h"
#include "gcmalloc.h"

static TAILQ_HEAD(_sptree, secpolicy) sptree;

/* perform exact match against security policy table. */
struct secpolicy *
getsp(spidx)
	struct policyindex *spidx;
{
	struct secpolicy *p;

	for (p = TAILQ_FIRST(&sptree); p; p = TAILQ_NEXT(p, chain)) {
		if (!cmpspidxstrict(spidx, &p->spidx))
			return p;
	}

	return NULL;
}

#if 1
struct secpolicy *
getsp_r(spidx)
	struct policyindex *spidx;
{
	struct secpolicy *p;

	for (p = TAILQ_FIRST(&sptree); p; p = TAILQ_NEXT(p, chain)) {
		if (!cmpspidxwild(spidx, &p->spidx))
			return p;
	}

	return NULL;
}
#else
struct secpolicy *
getsp_r(spidx, iph2)
	struct policyindex *spidx;
	struct ph2handle *iph2;
{
	struct secpolicy *p;
	u_int8_t prefixlen;

	plog(LLV_DEBUG, LOCATION, NULL, "checking for transport mode\n");

	if (spidx->src.ss_family != spidx->dst.ss_family) {
		plog(LLV_ERROR, LOCATION, NULL,
			"address family mismatch, src:%d dst:%d\n",
				spidx->src.ss_family,
				spidx->dst.ss_family);
		return NULL;
	}
	switch (spidx->src.ss_family) {
	case AF_INET:
		prefixlen = sizeof(struct in_addr) << 3;
		break;
#ifdef INET6
	case AF_INET6:
		prefixlen = sizeof(struct in6_addr) << 3;
		break;
#endif
	default:
		plog(LLV_ERROR, LOCATION, NULL,
			"invalid family: %d\n", spidx->src.ss_family);
		return NULL;
	}

	/* is it transport mode SA negotiation? */
	plog(LLV_DEBUG, LOCATION, NULL, "src1: %s\n",
		saddr2str(iph2->src));
	plog(LLV_DEBUG, LOCATION, NULL, "src2: %s\n",
		saddr2str((struct sockaddr *)&spidx->src));
	if (cmpsaddrwop(iph2->src, (struct sockaddr *)&spidx->src)
	 || spidx->prefs != prefixlen)
		return NULL;

	plog(LLV_DEBUG, LOCATION, NULL, "dst1: %s\n",
		saddr2str(iph2->dst));
	plog(LLV_DEBUG, LOCATION, NULL, "dst2: %s\n",
		saddr2str((struct sockaddr *)&spidx->dst));
	if (cmpsaddrwop(iph2->dst, (struct sockaddr *)&spidx->dst)
	 || spidx->prefd != prefixlen)
		return NULL;

	plog(LLV_DEBUG, LOCATION, NULL, "looks to be transport mode\n");

	for (p = TAILQ_FIRST(&sptree); p; p = TAILQ_NEXT(p, chain)) {
		if (!cmpspidx_wild(spidx, &p->spidx))
			return p;
	}

	return NULL;
}
#endif

struct secpolicy *
getspbyspid(spid)
	u_int32_t spid;
{
	struct secpolicy *p;

	for (p = TAILQ_FIRST(&sptree); p; p = TAILQ_NEXT(p, chain)) {
		if (p->id == spid)
			return p;
	}

	return NULL;
}

int
cmpspidxstrict(a, b)
	struct policyindex *a, *b;
{
	plog(LLV_DEBUG, LOCATION, NULL, "sub:%p: %s\n", a, spidx2str(a));
	plog(LLV_DEBUG, LOCATION, NULL, "db :%p: %s\n", b, spidx2str(b));

	/* XXX don't check direction now, but it's to be checked carefully. */
	if (a->dir != b->dir
	 || a->prefs != b->prefs
	 || a->prefd != b->prefd
	 || a->ul_proto != b->ul_proto)
		return 1;

	if (cmpsaddrstrict((struct sockaddr *)&a->src,
			   (struct sockaddr *)&b->src))
		return 1;
	if (cmpsaddrstrict((struct sockaddr *)&a->dst,
			   (struct sockaddr *)&b->dst))
		return 1;

#ifdef HAVE_SECCTX
	if (a->sec_ctx.ctx_alg != b->sec_ctx.ctx_alg
	    || a->sec_ctx.ctx_doi != b->sec_ctx.ctx_doi
	    || !within_range(a->sec_ctx.ctx_str, b->sec_ctx.ctx_str))
		return 1;
#endif
	return 0;
}

int
cmpspidxwild(a, b)
	struct policyindex *a, *b;
{
	struct sockaddr_storage sa1, sa2;

	plog(LLV_DEBUG, LOCATION, NULL, "sub:%p: %s\n", a, spidx2str(a));
	plog(LLV_DEBUG, LOCATION, NULL, "db: %p: %s\n", b, spidx2str(b));

	if (!(b->dir == IPSEC_DIR_ANY || a->dir == b->dir))
		return 1;

	if (!(a->ul_proto == IPSEC_ULPROTO_ANY ||
	      b->ul_proto == IPSEC_ULPROTO_ANY ||
	      a->ul_proto == b->ul_proto))
		return 1;

	if (a->src.ss_family != b->src.ss_family)
		return 1;
	if (a->dst.ss_family != b->dst.ss_family)
		return 1;

#ifndef __linux__
	/* compare src address */
	if (sizeof(sa1) < a->src.ss_len || sizeof(sa2) < b->src.ss_len) {
		plog(LLV_ERROR, LOCATION, NULL,
			"unexpected error: "
			"src.ss_len:%d dst.ss_len:%d\n",
			a->src.ss_len, b->src.ss_len);
		return 1;
	}
#endif
	mask_sockaddr((struct sockaddr *)&sa1, (struct sockaddr *)&a->src,
		b->prefs);
	mask_sockaddr((struct sockaddr *)&sa2, (struct sockaddr *)&b->src,
		b->prefs);
	plog(LLV_DEBUG, LOCATION, NULL, "%p masked with /%d: %s\n",
		a, b->prefs, saddr2str((struct sockaddr *)&sa1));
	plog(LLV_DEBUG, LOCATION, NULL, "%p masked with /%d: %s\n",
		b, b->prefs, saddr2str((struct sockaddr *)&sa2));
	if (cmpsaddrwild((struct sockaddr *)&sa1, (struct sockaddr *)&sa2))
		return 1;

#ifndef __linux__
	/* compare dst address */
	if (sizeof(sa1) < a->dst.ss_len || sizeof(sa2) < b->dst.ss_len) {
		plog(LLV_ERROR, LOCATION, NULL, "unexpected error\n");
		exit(1);
	}
#endif
	mask_sockaddr((struct sockaddr *)&sa1, (struct sockaddr *)&a->dst,
		b->prefd);
	mask_sockaddr((struct sockaddr *)&sa2, (struct sockaddr *)&b->dst,
		b->prefd);
	plog(LLV_DEBUG, LOCATION, NULL, "%p masked with /%d: %s\n",
		a, b->prefd, saddr2str((struct sockaddr *)&sa1));
	plog(LLV_DEBUG, LOCATION, NULL, "%p masked with /%d: %s\n",
		b, b->prefd, saddr2str((struct sockaddr *)&sa2));
	if (cmpsaddrwild((struct sockaddr *)&sa1, (struct sockaddr *)&sa2))
		return 1;

#ifdef HAVE_SECCTX
	if (a->sec_ctx.ctx_alg != b->sec_ctx.ctx_alg
	    || a->sec_ctx.ctx_doi != b->sec_ctx.ctx_doi
	    || !within_range(a->sec_ctx.ctx_str, b->sec_ctx.ctx_str))
		return 1;
#endif
	return 0;
}

struct secpolicy *
newsp()
{
	struct secpolicy *new;

	new = racoon_calloc(1, sizeof(*new));
	if (new == NULL)
		return NULL;

	return new;
}

void
delsp(sp)
	struct secpolicy *sp;
{
	struct ipsecrequest *req = NULL, *next;

	for (req = sp->req; req; req = next) {
		next = req->next;
		racoon_free(req);
	}
	
	racoon_free(sp);
}

void
delsp_bothdir(spidx0)
	struct policyindex *spidx0;
{
	struct policyindex spidx;
	struct secpolicy *sp;
	struct sockaddr_storage src, dst;
	u_int8_t prefs, prefd;

	memcpy(&spidx, spidx0, sizeof(spidx));
	switch (spidx.dir) {
	case IPSEC_DIR_INBOUND:
#ifdef HAVE_POLICY_FWD
	case IPSEC_DIR_FWD:
#endif
		src   = spidx.src;
		dst   = spidx.dst;
		prefs = spidx.prefs;
		prefd = spidx.prefd;
		break;
	case IPSEC_DIR_OUTBOUND:
		src   = spidx.dst;
		dst   = spidx.src;
		prefs = spidx.prefd;
		prefd = spidx.prefs;
		break;
	default:
		return;
	}

	spidx.src   = src;
	spidx.dst   = dst;
	spidx.prefs = prefs;
	spidx.prefd = prefd;
	spidx.dir   = IPSEC_DIR_INBOUND;

	sp = getsp(&spidx);
	if (sp) {
		remsp(sp);
		delsp(sp);
	}

#ifdef HAVE_POLICY_FWD
	spidx.dir   = IPSEC_DIR_FWD;

	sp = getsp(&spidx);
	if (sp) {
		remsp(sp);
		delsp(sp);
	}
#endif

	spidx.src   = dst;
	spidx.dst   = src;
	spidx.prefs = prefd;
	spidx.prefd = prefs;
	spidx.dir   = IPSEC_DIR_OUTBOUND;

	sp = getsp(&spidx);
	if (sp) {
		remsp(sp);
		delsp(sp);
	}
}

void
inssp(new)
	struct secpolicy *new;
{
#ifdef HAVE_PFKEY_POLICY_PRIORITY
	struct secpolicy *p;

	TAILQ_FOREACH(p, &sptree, chain) {
		if (new->spidx.priority < p->spidx.priority) {
			TAILQ_INSERT_BEFORE(p, new, chain);
			return;
		}
	}
	if (p == NULL)
#endif
		TAILQ_INSERT_TAIL(&sptree, new, chain);

	return;
}

void
remsp(sp)
	struct secpolicy *sp;
{
	TAILQ_REMOVE(&sptree, sp, chain);
}

void
flushsp()
{
	struct secpolicy *p, *next;

	for (p = TAILQ_FIRST(&sptree); p; p = next) {
		next = TAILQ_NEXT(p, chain);
		remsp(p);
		delsp(p);
	}
}

void
initsp()
{
	TAILQ_INIT(&sptree);
}

struct ipsecrequest *
newipsecreq()
{
	struct ipsecrequest *new;

	new = racoon_calloc(1, sizeof(*new));
	if (new == NULL)
		return NULL;

	return new;
}

const char *
spidx2str(spidx)
	const struct policyindex *spidx;
{
	/* addr/pref[port] addr/pref[port] ul dir act */
	static char buf[256];
	char *p, *a, *b;
	int blen, i;

	blen = sizeof(buf) - 1;
	p = buf;

	a = saddr2str((const struct sockaddr *)&spidx->src);
	for (b = a; *b != '\0'; b++)
		if (*b == '[') {
			*b = '\0';
			b++;
			break;
		}
	i = snprintf(p, blen, "%s/%d[%s ", a, spidx->prefs, b);
	if (i < 0 || i >= blen)
		return NULL;
	p += i;
	blen -= i;

	a = saddr2str((const struct sockaddr *)&spidx->dst);
	for (b = a; *b != '\0'; b++)
		if (*b == '[') {
			*b = '\0';
			b++;
			break;
		}
	i = snprintf(p, blen, "%s/%d[%s ", a, spidx->prefd, b);
	if (i < 0 || i >= blen)
		return NULL;
	p += i;
	blen -= i;

	i = snprintf(p, blen, "proto=%s dir=%s",
		s_proto(spidx->ul_proto), s_direction(spidx->dir));

#ifdef HAVE_SECCTX
	if (spidx->sec_ctx.ctx_strlen) {
		p += i;
		blen -= i;
		snprintf(p, blen, " sec_ctx:doi=%d,alg=%d,len=%d,str=%s",
			 spidx->sec_ctx.ctx_doi, spidx->sec_ctx.ctx_alg,
			 spidx->sec_ctx.ctx_strlen, spidx->sec_ctx.ctx_str);
	}
#endif
	return buf;
}

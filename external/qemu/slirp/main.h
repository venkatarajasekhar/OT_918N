

#ifdef HAVE_SYS_SELECT_H
#include <sys/select.h>
#endif

#define TOWRITEMAX 512

extern struct timeval tt;
extern int link_up;
extern int slirp_socket;
extern int slirp_socket_unit;
extern int slirp_socket_port;
extern u_int32_t slirp_socket_addr;
extern char *slirp_socket_passwd;
extern int ctty_closed;

#define TIME_DIFF(x,y) (x)-(y) < 0 ? ~0-(y)+(x) : (x)-(y)

extern char *slirp_tty;
extern char *exec_shell;
extern u_int curtime;
extern fd_set *global_readfds, *global_writefds, *global_xfds;
extern struct in_addr ctl_addr;
extern struct in_addr special_addr;
extern struct in_addr alias_addr;
extern struct in_addr our_addr;
extern struct in_addr loopback_addr;
extern struct in_addr dns_addr;
extern char *username;
extern char *socket_path;
extern int towrite_max;
extern int ppp_exit;
extern int tcp_keepintvl;
extern uint8_t client_ethaddr[6];
extern const char *slirp_special_ip;
extern int slirp_restrict;

#define PROTO_SLIP 0x1
#ifdef USE_PPP
#define PROTO_PPP 0x2
#endif

void if_encap(const uint8_t *ip_data, int ip_data_len);
ssize_t slirp_send(struct socket *so, const void *buf, size_t len, int flags);

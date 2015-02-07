

struct smb_request;
struct sock;
struct statfs;

/* proc.c */
extern int smb_setcodepage(struct smb_sb_info *server, struct smb_nls_codepage *cp);
extern __u32 smb_len(__u8 *p);
extern int smb_get_rsize(struct smb_sb_info *server);
extern int smb_get_wsize(struct smb_sb_info *server);
extern int smb_errno(struct smb_request *req);
extern int smb_newconn(struct smb_sb_info *server, struct smb_conn_opt *opt);
extern __u8 *smb_setup_header(struct smb_request *req, __u8 command, __u16 wct, __u16 bcc);
extern int smb_open(struct dentry *dentry, int wish);
extern int smb_close(struct inode *ino);
extern int smb_close_fileid(struct dentry *dentry, __u16 fileid);
extern int smb_proc_create(struct dentry *dentry, __u16 attr, time_t ctime, __u16 *fileid);
extern int smb_proc_mv(struct dentry *old_dentry, struct dentry *new_dentry);
extern int smb_proc_mkdir(struct dentry *dentry);
extern int smb_proc_rmdir(struct dentry *dentry);
extern int smb_proc_unlink(struct dentry *dentry);
extern int smb_proc_flush(struct smb_sb_info *server, __u16 fileid);
extern void smb_init_root_dirent(struct smb_sb_info *server, struct smb_fattr *fattr,
				 struct super_block *sb);
extern int smb_proc_getattr(struct dentry *dir, struct smb_fattr *fattr);
extern int smb_proc_setattr(struct dentry *dir, struct smb_fattr *fattr);
extern int smb_proc_setattr_unix(struct dentry *d, struct iattr *attr, unsigned int major, unsigned int minor);
extern int smb_proc_settime(struct dentry *dentry, struct smb_fattr *fattr);
extern int smb_proc_dskattr(struct dentry *dentry, struct kstatfs *attr);
extern int smb_proc_read_link(struct smb_sb_info *server, struct dentry *d, char *buffer, int len);
extern int smb_proc_symlink(struct smb_sb_info *server, struct dentry *d, const char *oldpath);
extern int smb_proc_link(struct smb_sb_info *server, struct dentry *dentry, struct dentry *new_dentry);
extern void smb_install_null_ops(struct smb_ops *ops);
/* dir.c */
extern const struct file_operations smb_dir_operations;
extern const struct inode_operations smb_dir_inode_operations;
extern const struct inode_operations smb_dir_inode_operations_unix;
extern void smb_new_dentry(struct dentry *dentry);
extern void smb_renew_times(struct dentry *dentry);
/* cache.c */
extern void smb_invalid_dir_cache(struct inode *dir);
extern void smb_invalidate_dircache_entries(struct dentry *parent);
extern struct dentry *smb_dget_fpos(struct dentry *dentry, struct dentry *parent, unsigned long fpos);
extern int smb_fill_cache(struct file *filp, void *dirent, filldir_t filldir, struct smb_cache_control *ctrl, struct qstr *qname, struct smb_fattr *entry);
/* sock.c */
extern void smb_data_ready(struct sock *sk, int len);
extern int smb_valid_socket(struct inode *inode);
extern void smb_close_socket(struct smb_sb_info *server);
extern int smb_recv_available(struct smb_sb_info *server);
extern int smb_receive_header(struct smb_sb_info *server);
extern int smb_receive_drop(struct smb_sb_info *server);
extern int smb_receive(struct smb_sb_info *server, struct smb_request *req);
extern int smb_send_request(struct smb_request *req);
/* inode.c */
extern struct inode *smb_iget(struct super_block *sb, struct smb_fattr *fattr);
extern void smb_get_inode_attr(struct inode *inode, struct smb_fattr *fattr);
extern void smb_set_inode_attr(struct inode *inode, struct smb_fattr *fattr);
extern void smb_invalidate_inodes(struct smb_sb_info *server);
extern int smb_revalidate_inode(struct dentry *dentry);
extern int smb_getattr(struct vfsmount *mnt, struct dentry *dentry, struct kstat *stat);
extern int smb_notify_change(struct dentry *dentry, struct iattr *attr);
/* file.c */
extern const struct address_space_operations smb_file_aops;
extern const struct file_operations smb_file_operations;
extern const struct inode_operations smb_file_inode_operations;
/* ioctl.c */
extern long smb_ioctl(struct file *filp, unsigned int cmd, unsigned long arg);
/* smbiod.c */
extern void smbiod_wake_up(void);
extern int smbiod_register_server(struct smb_sb_info *server);
extern void smbiod_unregister_server(struct smb_sb_info *server);
extern void smbiod_flush(struct smb_sb_info *server);
extern int smbiod_retry(struct smb_sb_info *server);
/* request.c */
extern int smb_init_request_cache(void);
extern void smb_destroy_request_cache(void);
extern struct smb_request *smb_alloc_request(struct smb_sb_info *server, int bufsize);
extern void smb_rput(struct smb_request *req);
extern int smb_add_request(struct smb_request *req);
extern int smb_request_send_server(struct smb_sb_info *server);
extern int smb_request_recv(struct smb_sb_info *server);
/* symlink.c */
extern int smb_symlink(struct inode *inode, struct dentry *dentry, const char *oldname);
extern const struct inode_operations smb_link_inode_operations;


#include "e2fsck.h"

struct buffer_head {
	char		b_data[8192];
	e2fsck_t	b_ctx;
	io_channel 	b_io;
	int	 	b_size;
	blk_t	 	b_blocknr;
	int	 	b_dirty;
	int	 	b_uptodate;
	int	 	b_err;
};

struct inode {
	e2fsck_t	i_ctx;
	ext2_ino_t	i_ino;
	struct ext2_inode i_ext2;
};

struct kdev_s {
	e2fsck_t	k_ctx;
	int		k_dev;
};

#define K_DEV_FS	1
#define K_DEV_JOURNAL	2

typedef struct kdev_s *kdev_t;

#define lock_buffer(bh) do {} while(0)
#define unlock_buffer(bh) do {} while(0)
#define buffer_req(bh) 1
#define do_readahead(journal, start) do {} while(0)
	
extern e2fsck_t e2fsck_global_ctx;  /* Try your very best not to use this! */

typedef struct {
	int	object_length;
} kmem_cache_t;

#define kmem_cache_alloc(cache,flags) malloc((cache)->object_length)
#define kmem_cache_free(cache,obj) free(obj)
#define kmem_cache_create(name,len,a,b,c,d) do_cache_create(len)
#define kmem_cache_destroy(cache) do_cache_destroy(cache)
#define kmalloc(len,flags) malloc(len)
#define kfree(p) free(p)

extern kmem_cache_t * do_cache_create(int len);
extern void do_cache_destroy(kmem_cache_t *cache);
	
#if (defined(E2FSCK_INCLUDE_INLINE_FUNCS) || !defined(NO_INLINE_FUNCS))
#ifdef E2FSCK_INCLUDE_INLINE_FUNCS
#define _INLINE_ extern
#else
#ifdef __GNUC__
#define _INLINE_ extern __inline__
#else				/* For Watcom C */
#define _INLINE_ extern inline
#endif
#endif

_INLINE_ kmem_cache_t * do_cache_create(int len)
{
	kmem_cache_t *new_cache;
	new_cache = malloc(sizeof(*new_cache));
	if (new_cache)
		new_cache->object_length = len;
	return new_cache;
}

_INLINE_ void do_cache_destroy(kmem_cache_t *cache)
{
	free(cache);
}
#undef _INLINE_
#endif

#define __init

#include <ext2fs/kernel-jbd.h>

int journal_bmap(journal_t *journal, blk_t block, unsigned long *phys);
struct buffer_head *getblk(kdev_t ctx, blk_t blocknr, int blocksize);
void sync_blockdev(kdev_t kdev);
void ll_rw_block(int rw, int dummy, struct buffer_head *bh[]);
void mark_buffer_dirty(struct buffer_head *bh);
void mark_buffer_uptodate(struct buffer_head *bh, int val);
void brelse(struct buffer_head *bh);
int buffer_uptodate(struct buffer_head *bh);
void wait_on_buffer(struct buffer_head *bh);

#define __getblk(dev, blocknr, blocksize) getblk(dev, blocknr, blocksize)
#define set_buffer_uptodate(bh) mark_buffer_uptodate(bh, 1)

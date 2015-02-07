#ifndef _LINUX_PAGEMAP_H
#define _LINUX_PAGEMAP_H

#include <linux/mm.h>
#include <linux/fs.h>
#include <linux/list.h>
#include <linux/highmem.h>
#include <linux/compiler.h>
#include <asm/uaccess.h>
#include <linux/gfp.h>

#define	AS_EIO		(__GFP_BITS_SHIFT + 0)	/* IO error on async write */
#define AS_ENOSPC	(__GFP_BITS_SHIFT + 1)	/* ENOSPC on async write */

static inline gfp_t mapping_gfp_mask(struct address_space * mapping)
{
	return (__force gfp_t)mapping->flags & __GFP_BITS_MASK;
}

static inline void mapping_set_gfp_mask(struct address_space *m, gfp_t mask)
{
	m->flags = (m->flags & ~(__force unsigned long)__GFP_BITS_MASK) |
				(__force unsigned long)mask;
}

#define PAGE_CACHE_SHIFT	PAGE_SHIFT
#define PAGE_CACHE_SIZE		PAGE_SIZE
#define PAGE_CACHE_MASK		PAGE_MASK
#define PAGE_CACHE_ALIGN(addr)	(((addr)+PAGE_CACHE_SIZE-1)&PAGE_CACHE_MASK)

#define page_cache_get(page)		get_page(page)
#define page_cache_release(page)	put_page(page)
void release_pages(struct page **pages, int nr, int cold);

#ifdef CONFIG_NUMA
extern struct page *page_cache_alloc(struct address_space *x);
extern struct page *page_cache_alloc_cold(struct address_space *x);
#else
static inline struct page *page_cache_alloc(struct address_space *x)
{
	return alloc_pages(mapping_gfp_mask(x), 0);
}

static inline struct page *page_cache_alloc_cold(struct address_space *x)
{
	return alloc_pages(mapping_gfp_mask(x)|__GFP_COLD, 0);
}
#endif

typedef int filler_t(void *, struct page *);

extern struct page * find_get_page(struct address_space *mapping,
				unsigned long index);
extern struct page * find_lock_page(struct address_space *mapping,
				unsigned long index);
extern __deprecated_for_modules struct page * find_trylock_page(
			struct address_space *mapping, unsigned long index);
extern struct page * find_or_create_page(struct address_space *mapping,
				unsigned long index, gfp_t gfp_mask);
unsigned find_get_pages(struct address_space *mapping, pgoff_t start,
			unsigned int nr_pages, struct page **pages);
unsigned find_get_pages_contig(struct address_space *mapping, pgoff_t start,
			       unsigned int nr_pages, struct page **pages);
unsigned find_get_pages_tag(struct address_space *mapping, pgoff_t *index,
			int tag, unsigned int nr_pages, struct page **pages);

static inline struct page *grab_cache_page(struct address_space *mapping, unsigned long index)
{
	return find_or_create_page(mapping, index, mapping_gfp_mask(mapping));
}

extern struct page * grab_cache_page_nowait(struct address_space *mapping,
				unsigned long index);
extern struct page * read_cache_page(struct address_space *mapping,
				unsigned long index, filler_t *filler,
				void *data);
extern int read_cache_pages(struct address_space *mapping,
		struct list_head *pages, filler_t *filler, void *data);

static inline struct page *read_mapping_page(struct address_space *mapping,
					     unsigned long index, void *data)
{
	filler_t *filler = (filler_t *)mapping->a_ops->readpage;
	return read_cache_page(mapping, index, filler, data);
}

int add_to_page_cache(struct page *page, struct address_space *mapping,
				unsigned long index, gfp_t gfp_mask);
int add_to_page_cache_lru(struct page *page, struct address_space *mapping,
				unsigned long index, gfp_t gfp_mask);
extern void remove_from_page_cache(struct page *page);
extern void __remove_from_page_cache(struct page *page);

static inline loff_t page_offset(struct page *page)
{
	return ((loff_t)page->index) << PAGE_CACHE_SHIFT;
}

static inline pgoff_t linear_page_index(struct vm_area_struct *vma,
					unsigned long address)
{
	pgoff_t pgoff = (address - vma->vm_start) >> PAGE_SHIFT;
	pgoff += vma->vm_pgoff;
	return pgoff >> (PAGE_CACHE_SHIFT - PAGE_SHIFT);
}

extern void FASTCALL(__lock_page(struct page *page));
extern void FASTCALL(unlock_page(struct page *page));

static inline void lock_page(struct page *page)
{
	might_sleep();
	if (TestSetPageLocked(page))
		__lock_page(page);
}
	
extern void FASTCALL(wait_on_page_bit(struct page *page, int bit_nr));

static inline void wait_on_page_locked(struct page *page)
{
	if (PageLocked(page))
		wait_on_page_bit(page, PG_locked);
}

static inline void wait_on_page_writeback(struct page *page)
{
	if (PageWriteback(page))
		wait_on_page_bit(page, PG_writeback);
}

extern void end_page_writeback(struct page *page);

static inline int fault_in_pages_writeable(char __user *uaddr, int size)
{
	int ret;

	/*
	 * Writing zeroes into userspace here is OK, because we know that if
	 * the zero gets there, we'll be overwriting it.
	 */
	ret = __put_user(0, uaddr);
	if (ret == 0) {
		char __user *end = uaddr + size - 1;

		/*
		 * If the page was already mapped, this will get a cache miss
		 * for sure, so try to avoid doing it.
		 */
		if (((unsigned long)uaddr & PAGE_MASK) !=
				((unsigned long)end & PAGE_MASK))
		 	ret = __put_user(0, end);
	}
	return ret;
}

static inline void fault_in_pages_readable(const char __user *uaddr, int size)
{
	volatile char c;
	int ret;

	ret = __get_user(c, uaddr);
	if (ret == 0) {
		const char __user *end = uaddr + size - 1;

		if (((unsigned long)uaddr & PAGE_MASK) !=
				((unsigned long)end & PAGE_MASK))
		 	__get_user(c, end);
	}
}

#endif /* _LINUX_PAGEMAP_H */

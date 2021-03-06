

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/spinlock.h>
#include <linux/idr.h>
#include <linux/slab.h>
#include <linux/fs.h>
#include <linux/sched.h>
#include <linux/init.h>
#include <linux/list.h>
#include <linux/writeback.h>
#include <linux/inotify.h>
#include <linux/fsnotify_backend.h>

static atomic_t inotify_cookie;



struct inotify_handle {
	struct idr		idr;		/* idr mapping wd -> watch */
	struct mutex		mutex;		/* protects this bad boy */
	struct list_head	watches;	/* list of watches */
	atomic_t		count;		/* reference count */
	u32			last_wd;	/* the last wd allocated */
	const struct inotify_operations *in_ops; /* inotify caller operations */
};

static inline void get_inotify_handle(struct inotify_handle *ih)
{
	atomic_inc(&ih->count);
}

static inline void put_inotify_handle(struct inotify_handle *ih)
{
	if (atomic_dec_and_test(&ih->count)) {
		idr_destroy(&ih->idr);
		kfree(ih);
	}
}

void get_inotify_watch(struct inotify_watch *watch)
{
	atomic_inc(&watch->count);
}
EXPORT_SYMBOL_GPL(get_inotify_watch);

int pin_inotify_watch(struct inotify_watch *watch)
{
	struct super_block *sb = watch->inode->i_sb;
	if (atomic_inc_not_zero(&sb->s_active)) {
		atomic_inc(&watch->count);
		return 1;
	}
	return 0;
}

void put_inotify_watch(struct inotify_watch *watch)
{
	if (atomic_dec_and_test(&watch->count)) {
		struct inotify_handle *ih = watch->ih;

		iput(watch->inode);
		ih->in_ops->destroy_watch(watch);
		put_inotify_handle(ih);
	}
}
EXPORT_SYMBOL_GPL(put_inotify_watch);

void unpin_inotify_watch(struct inotify_watch *watch)
{
	struct super_block *sb = watch->inode->i_sb;
	put_inotify_watch(watch);
	deactivate_super(sb);
}

static int inotify_handle_get_wd(struct inotify_handle *ih,
				 struct inotify_watch *watch)
{
	int ret;

	do {
		if (unlikely(!idr_pre_get(&ih->idr, GFP_NOFS)))
			return -ENOSPC;
		ret = idr_get_new_above(&ih->idr, watch, ih->last_wd+1, &watch->wd);
	} while (ret == -EAGAIN);

	if (likely(!ret))
		ih->last_wd = watch->wd;

	return ret;
}

static inline int inotify_inode_watched(struct inode *inode)
{
	return !list_empty(&inode->inotify_watches);
}

static void set_dentry_child_flags(struct inode *inode, int watched)
{
	struct dentry *alias;

	spin_lock(&dcache_lock);
	list_for_each_entry(alias, &inode->i_dentry, d_alias) {
		struct dentry *child;

		list_for_each_entry(child, &alias->d_subdirs, d_u.d_child) {
			if (!child->d_inode)
				continue;

			spin_lock(&child->d_lock);
			if (watched)
				child->d_flags |= DCACHE_INOTIFY_PARENT_WATCHED;
			else
				child->d_flags &=~DCACHE_INOTIFY_PARENT_WATCHED;
			spin_unlock(&child->d_lock);
		}
	}
	spin_unlock(&dcache_lock);
}

static struct inotify_watch *inode_find_handle(struct inode *inode,
					       struct inotify_handle *ih)
{
	struct inotify_watch *watch;

	list_for_each_entry(watch, &inode->inotify_watches, i_list) {
		if (watch->ih == ih)
			return watch;
	}

	return NULL;
}

static void remove_watch_no_event(struct inotify_watch *watch,
				  struct inotify_handle *ih)
{
	list_del(&watch->i_list);
	list_del(&watch->h_list);

	if (!inotify_inode_watched(watch->inode))
		set_dentry_child_flags(watch->inode, 0);

	idr_remove(&ih->idr, watch->wd);
}

void inotify_remove_watch_locked(struct inotify_handle *ih,
				 struct inotify_watch *watch)
{
	remove_watch_no_event(watch, ih);
	ih->in_ops->handle_event(watch, watch->wd, IN_IGNORED, 0, NULL, NULL);
}
EXPORT_SYMBOL_GPL(inotify_remove_watch_locked);

/* Kernel API for producing events */

void inotify_d_instantiate(struct dentry *entry, struct inode *inode)
{
	struct dentry *parent;

	if (!inode)
		return;

	spin_lock(&entry->d_lock);
	parent = entry->d_parent;
	if (parent->d_inode && inotify_inode_watched(parent->d_inode))
		entry->d_flags |= DCACHE_INOTIFY_PARENT_WATCHED;
	spin_unlock(&entry->d_lock);
}

void inotify_d_move(struct dentry *entry)
{
	struct dentry *parent;

	parent = entry->d_parent;
	if (inotify_inode_watched(parent->d_inode))
		entry->d_flags |= DCACHE_INOTIFY_PARENT_WATCHED;
	else
		entry->d_flags &= ~DCACHE_INOTIFY_PARENT_WATCHED;
}

void inotify_inode_queue_event(struct inode *inode, u32 mask, u32 cookie,
			       const char *name, struct inode *n_inode)
{
	struct inotify_watch *watch, *next;

	if (!inotify_inode_watched(inode))
		return;

	mutex_lock(&inode->inotify_mutex);
	list_for_each_entry_safe(watch, next, &inode->inotify_watches, i_list) {
		u32 watch_mask = watch->mask;
		if (watch_mask & mask) {
			struct inotify_handle *ih= watch->ih;
			mutex_lock(&ih->mutex);
			if (watch_mask & IN_ONESHOT)
				remove_watch_no_event(watch, ih);
			ih->in_ops->handle_event(watch, watch->wd, mask, cookie,
						 name, n_inode);
			mutex_unlock(&ih->mutex);
		}
	}
	mutex_unlock(&inode->inotify_mutex);
}
EXPORT_SYMBOL_GPL(inotify_inode_queue_event);

void inotify_dentry_parent_queue_event(struct dentry *dentry, u32 mask,
				       u32 cookie, const char *name)
{
	struct dentry *parent;
	struct inode *inode;

	if (!(dentry->d_flags & DCACHE_INOTIFY_PARENT_WATCHED))
		return;

	spin_lock(&dentry->d_lock);
	parent = dentry->d_parent;
	inode = parent->d_inode;

	if (inotify_inode_watched(inode)) {
		dget(parent);
		spin_unlock(&dentry->d_lock);
		inotify_inode_queue_event(inode, mask, cookie, name,
					  dentry->d_inode);
		dput(parent);
	} else
		spin_unlock(&dentry->d_lock);
}
EXPORT_SYMBOL_GPL(inotify_dentry_parent_queue_event);

u32 inotify_get_cookie(void)
{
	return atomic_inc_return(&inotify_cookie);
}
EXPORT_SYMBOL_GPL(inotify_get_cookie);

void inotify_unmount_inodes(struct list_head *list)
{
	struct inode *inode, *next_i, *need_iput = NULL;

	list_for_each_entry_safe(inode, next_i, list, i_sb_list) {
		struct inotify_watch *watch, *next_w;
		struct inode *need_iput_tmp;
		struct list_head *watches;

		/*
		 * We cannot __iget() an inode in state I_CLEAR, I_FREEING,
		 * I_WILL_FREE, or I_NEW which is fine because by that point
		 * the inode cannot have any associated watches.
		 */
		if (inode->i_state & (I_CLEAR|I_FREEING|I_WILL_FREE|I_NEW))
			continue;

		/*
		 * If i_count is zero, the inode cannot have any watches and
		 * doing an __iget/iput with MS_ACTIVE clear would actually
		 * evict all inodes with zero i_count from icache which is
		 * unnecessarily violent and may in fact be illegal to do.
		 */
		if (!atomic_read(&inode->i_count))
			continue;

		need_iput_tmp = need_iput;
		need_iput = NULL;
		/* In case inotify_remove_watch_locked() drops a reference. */
		if (inode != need_iput_tmp)
			__iget(inode);
		else
			need_iput_tmp = NULL;
		/* In case the dropping of a reference would nuke next_i. */
		if ((&next_i->i_sb_list != list) &&
				atomic_read(&next_i->i_count) &&
				!(next_i->i_state & (I_CLEAR | I_FREEING |
					I_WILL_FREE))) {
			__iget(next_i);
			need_iput = next_i;
		}

		/*
		 * We can safely drop inode_lock here because we hold
		 * references on both inode and next_i.  Also no new inodes
		 * will be added since the umount has begun.  Finally,
		 * iprune_mutex keeps shrink_icache_memory() away.
		 */
		spin_unlock(&inode_lock);

		if (need_iput_tmp)
			iput(need_iput_tmp);

		/* for each watch, send IN_UNMOUNT and then remove it */
		mutex_lock(&inode->inotify_mutex);
		watches = &inode->inotify_watches;
		list_for_each_entry_safe(watch, next_w, watches, i_list) {
			struct inotify_handle *ih= watch->ih;
			get_inotify_watch(watch);
			mutex_lock(&ih->mutex);
			ih->in_ops->handle_event(watch, watch->wd, IN_UNMOUNT, 0,
						 NULL, NULL);
			inotify_remove_watch_locked(ih, watch);
			mutex_unlock(&ih->mutex);
			put_inotify_watch(watch);
		}
		mutex_unlock(&inode->inotify_mutex);
		iput(inode);		

		spin_lock(&inode_lock);
	}
}
EXPORT_SYMBOL_GPL(inotify_unmount_inodes);

void inotify_inode_is_dead(struct inode *inode)
{
	struct inotify_watch *watch, *next;

	mutex_lock(&inode->inotify_mutex);
	list_for_each_entry_safe(watch, next, &inode->inotify_watches, i_list) {
		struct inotify_handle *ih = watch->ih;
		mutex_lock(&ih->mutex);
		inotify_remove_watch_locked(ih, watch);
		mutex_unlock(&ih->mutex);
	}
	mutex_unlock(&inode->inotify_mutex);
}
EXPORT_SYMBOL_GPL(inotify_inode_is_dead);

/* Kernel Consumer API */

struct inotify_handle *inotify_init(const struct inotify_operations *ops)
{
	struct inotify_handle *ih;

	ih = kmalloc(sizeof(struct inotify_handle), GFP_KERNEL);
	if (unlikely(!ih))
		return ERR_PTR(-ENOMEM);

	idr_init(&ih->idr);
	INIT_LIST_HEAD(&ih->watches);
	mutex_init(&ih->mutex);
	ih->last_wd = 0;
	ih->in_ops = ops;
	atomic_set(&ih->count, 0);
	get_inotify_handle(ih);

	return ih;
}
EXPORT_SYMBOL_GPL(inotify_init);

void inotify_init_watch(struct inotify_watch *watch)
{
	INIT_LIST_HEAD(&watch->h_list);
	INIT_LIST_HEAD(&watch->i_list);
	atomic_set(&watch->count, 0);
	get_inotify_watch(watch); /* initial get */
}
EXPORT_SYMBOL_GPL(inotify_init_watch);


static int pin_to_kill(struct inotify_handle *ih, struct inotify_watch *watch)
{
	struct super_block *sb = watch->inode->i_sb;

	if (atomic_inc_not_zero(&sb->s_active)) {
		get_inotify_watch(watch);
		mutex_unlock(&ih->mutex);
		return 1;	/* the best outcome */
	}
	spin_lock(&sb_lock);
	sb->s_count++;
	spin_unlock(&sb_lock);
	mutex_unlock(&ih->mutex); /* can't grab ->s_umount under it */
	down_read(&sb->s_umount);
	/* fs is already shut down; the watch is dead */
	drop_super(sb);
	return 0;
}

static void unpin_and_kill(struct inotify_watch *watch)
{
	struct super_block *sb = watch->inode->i_sb;
	put_inotify_watch(watch);
	deactivate_super(sb);
}

void inotify_destroy(struct inotify_handle *ih)
{
	/*
	 * Destroy all of the watches for this handle. Unfortunately, not very
	 * pretty.  We cannot do a simple iteration over the list, because we
	 * do not know the inode until we iterate to the watch.  But we need to
	 * hold inode->inotify_mutex before ih->mutex.  The following works.
	 *
	 * AV: it had to become even uglier to start working ;-/
	 */
	while (1) {
		struct inotify_watch *watch;
		struct list_head *watches;
		struct super_block *sb;
		struct inode *inode;

		mutex_lock(&ih->mutex);
		watches = &ih->watches;
		if (list_empty(watches)) {
			mutex_unlock(&ih->mutex);
			break;
		}
		watch = list_first_entry(watches, struct inotify_watch, h_list);
		sb = watch->inode->i_sb;
		if (!pin_to_kill(ih, watch))
			continue;

		inode = watch->inode;
		mutex_lock(&inode->inotify_mutex);
		mutex_lock(&ih->mutex);

		/* make sure we didn't race with another list removal */
		if (likely(idr_find(&ih->idr, watch->wd))) {
			remove_watch_no_event(watch, ih);
			put_inotify_watch(watch);
		}

		mutex_unlock(&ih->mutex);
		mutex_unlock(&inode->inotify_mutex);
		unpin_and_kill(watch);
	}

	/* free this handle: the put matching the get in inotify_init() */
	put_inotify_handle(ih);
}
EXPORT_SYMBOL_GPL(inotify_destroy);

s32 inotify_find_watch(struct inotify_handle *ih, struct inode *inode,
		       struct inotify_watch **watchp)
{
	struct inotify_watch *old;
	int ret = -ENOENT;

	mutex_lock(&inode->inotify_mutex);
	mutex_lock(&ih->mutex);

	old = inode_find_handle(inode, ih);
	if (unlikely(old)) {
		get_inotify_watch(old); /* caller must put watch */
		*watchp = old;
		ret = old->wd;
	}

	mutex_unlock(&ih->mutex);
	mutex_unlock(&inode->inotify_mutex);

	return ret;
}
EXPORT_SYMBOL_GPL(inotify_find_watch);

s32 inotify_find_update_watch(struct inotify_handle *ih, struct inode *inode,
			      u32 mask)
{
	struct inotify_watch *old;
	int mask_add = 0;
	int ret;

	if (mask & IN_MASK_ADD)
		mask_add = 1;

	/* don't allow invalid bits: we don't want flags set */
	mask &= IN_ALL_EVENTS | IN_ONESHOT;
	if (unlikely(!mask))
		return -EINVAL;

	mutex_lock(&inode->inotify_mutex);
	mutex_lock(&ih->mutex);

	/*
	 * Handle the case of re-adding a watch on an (inode,ih) pair that we
	 * are already watching.  We just update the mask and return its wd.
	 */
	old = inode_find_handle(inode, ih);
	if (unlikely(!old)) {
		ret = -ENOENT;
		goto out;
	}

	if (mask_add)
		old->mask |= mask;
	else
		old->mask = mask;
	ret = old->wd;
out:
	mutex_unlock(&ih->mutex);
	mutex_unlock(&inode->inotify_mutex);
	return ret;
}
EXPORT_SYMBOL_GPL(inotify_find_update_watch);

s32 inotify_add_watch(struct inotify_handle *ih, struct inotify_watch *watch,
		      struct inode *inode, u32 mask)
{
	int ret = 0;
	int newly_watched;

	/* don't allow invalid bits: we don't want flags set */
	mask &= IN_ALL_EVENTS | IN_ONESHOT;
	if (unlikely(!mask))
		return -EINVAL;
	watch->mask = mask;

	mutex_lock(&inode->inotify_mutex);
	mutex_lock(&ih->mutex);

	/* Initialize a new watch */
	ret = inotify_handle_get_wd(ih, watch);
	if (unlikely(ret))
		goto out;
	ret = watch->wd;

	/* save a reference to handle and bump the count to make it official */
	get_inotify_handle(ih);
	watch->ih = ih;

	/*
	 * Save a reference to the inode and bump the ref count to make it
	 * official.  We hold a reference to nameidata, which makes this safe.
	 */
	watch->inode = igrab(inode);

	/* Add the watch to the handle's and the inode's list */
	newly_watched = !inotify_inode_watched(inode);
	list_add(&watch->h_list, &ih->watches);
	list_add(&watch->i_list, &inode->inotify_watches);
	/*
	 * Set child flags _after_ adding the watch, so there is no race
	 * windows where newly instantiated children could miss their parent's
	 * watched flag.
	 */
	if (newly_watched)
		set_dentry_child_flags(inode, 1);

out:
	mutex_unlock(&ih->mutex);
	mutex_unlock(&inode->inotify_mutex);
	return ret;
}
EXPORT_SYMBOL_GPL(inotify_add_watch);

s32 inotify_clone_watch(struct inotify_watch *old, struct inotify_watch *new)
{
	struct inotify_handle *ih = old->ih;
	int ret = 0;

	new->mask = old->mask;
	new->ih = ih;

	mutex_lock(&ih->mutex);

	/* Initialize a new watch */
	ret = inotify_handle_get_wd(ih, new);
	if (unlikely(ret))
		goto out;
	ret = new->wd;

	get_inotify_handle(ih);

	new->inode = igrab(old->inode);

	list_add(&new->h_list, &ih->watches);
	list_add(&new->i_list, &old->inode->inotify_watches);
out:
	mutex_unlock(&ih->mutex);
	return ret;
}

void inotify_evict_watch(struct inotify_watch *watch)
{
	get_inotify_watch(watch);
	mutex_lock(&watch->ih->mutex);
	inotify_remove_watch_locked(watch->ih, watch);
	mutex_unlock(&watch->ih->mutex);
}

int inotify_rm_wd(struct inotify_handle *ih, u32 wd)
{
	struct inotify_watch *watch;
	struct super_block *sb;
	struct inode *inode;

	mutex_lock(&ih->mutex);
	watch = idr_find(&ih->idr, wd);
	if (unlikely(!watch)) {
		mutex_unlock(&ih->mutex);
		return -EINVAL;
	}
	sb = watch->inode->i_sb;
	if (!pin_to_kill(ih, watch))
		return 0;

	inode = watch->inode;

	mutex_lock(&inode->inotify_mutex);
	mutex_lock(&ih->mutex);

	/* make sure that we did not race */
	if (likely(idr_find(&ih->idr, wd) == watch))
		inotify_remove_watch_locked(ih, watch);

	mutex_unlock(&ih->mutex);
	mutex_unlock(&inode->inotify_mutex);
	unpin_and_kill(watch);

	return 0;
}
EXPORT_SYMBOL_GPL(inotify_rm_wd);

int inotify_rm_watch(struct inotify_handle *ih,
		     struct inotify_watch *watch)
{
	return inotify_rm_wd(ih, watch->wd);
}
EXPORT_SYMBOL_GPL(inotify_rm_watch);

static int __init inotify_setup(void)
{
	BUILD_BUG_ON(IN_ACCESS != FS_ACCESS);
	BUILD_BUG_ON(IN_MODIFY != FS_MODIFY);
	BUILD_BUG_ON(IN_ATTRIB != FS_ATTRIB);
	BUILD_BUG_ON(IN_CLOSE_WRITE != FS_CLOSE_WRITE);
	BUILD_BUG_ON(IN_CLOSE_NOWRITE != FS_CLOSE_NOWRITE);
	BUILD_BUG_ON(IN_OPEN != FS_OPEN);
	BUILD_BUG_ON(IN_MOVED_FROM != FS_MOVED_FROM);
	BUILD_BUG_ON(IN_MOVED_TO != FS_MOVED_TO);
	BUILD_BUG_ON(IN_CREATE != FS_CREATE);
	BUILD_BUG_ON(IN_DELETE != FS_DELETE);
	BUILD_BUG_ON(IN_DELETE_SELF != FS_DELETE_SELF);
	BUILD_BUG_ON(IN_MOVE_SELF != FS_MOVE_SELF);
	BUILD_BUG_ON(IN_Q_OVERFLOW != FS_Q_OVERFLOW);

	BUILD_BUG_ON(IN_UNMOUNT != FS_UNMOUNT);
	BUILD_BUG_ON(IN_ISDIR != FS_IN_ISDIR);
	BUILD_BUG_ON(IN_IGNORED != FS_IN_IGNORED);
	BUILD_BUG_ON(IN_ONESHOT != FS_IN_ONESHOT);

	atomic_set(&inotify_cookie, 0);

	return 0;
}

module_init(inotify_setup);

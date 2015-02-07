

#ifndef _PPC64_PHYP_DUMP_H
#define _PPC64_PHYP_DUMP_H

#ifdef CONFIG_PHYP_DUMP

#define PHYP_DUMP_RMR_START 0x0
#define PHYP_DUMP_RMR_END   (1UL<<28)

struct phyp_dump {
	/* Memory that is reserved during very early boot. */
	unsigned long init_reserve_start;
	unsigned long init_reserve_size;
	/* cmd line options during boot */
	unsigned long reserve_bootvar;
	unsigned long phyp_dump_at_boot;
	/* Check status during boot if dump supported, active & present*/
	unsigned long phyp_dump_configured;
	unsigned long phyp_dump_is_active;
	/* store cpu & hpte size */
	unsigned long cpu_state_size;
	unsigned long hpte_region_size;
	/* previous scratch area values */
	unsigned long reserved_scratch_addr;
	unsigned long reserved_scratch_size;
};

extern struct phyp_dump *phyp_dump_info;

int early_init_dt_scan_phyp_dump(unsigned long node,
		const char *uname, int depth, void *data);

#endif /* CONFIG_PHYP_DUMP */
#endif /* _PPC64_PHYP_DUMP_H */

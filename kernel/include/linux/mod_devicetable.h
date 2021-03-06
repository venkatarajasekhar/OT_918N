

#ifndef LINUX_MOD_DEVICETABLE_H
#define LINUX_MOD_DEVICETABLE_H

#ifdef __KERNEL__
#include <linux/types.h>
typedef unsigned long kernel_ulong_t;
#endif

#define PCI_ANY_ID (~0)

struct pci_device_id {
	__u32 vendor, device;		/* Vendor and device ID or PCI_ANY_ID*/
	__u32 subvendor, subdevice;	/* Subsystem ID's or PCI_ANY_ID */
	__u32 class, class_mask;	/* (class,subclass,prog-if) triplet */
	kernel_ulong_t driver_data;	/* Data private to the driver */
};


#define IEEE1394_MATCH_VENDOR_ID	0x0001
#define IEEE1394_MATCH_MODEL_ID		0x0002
#define IEEE1394_MATCH_SPECIFIER_ID	0x0004
#define IEEE1394_MATCH_VERSION		0x0008

struct ieee1394_device_id {
	__u32 match_flags;
	__u32 vendor_id;
	__u32 model_id;
	__u32 specifier_id;
	__u32 version;
	kernel_ulong_t driver_data
		__attribute__((aligned(sizeof(kernel_ulong_t))));
};



struct usb_device_id {
	/* which fields to match against? */
	__u16		match_flags;

	/* Used for product specific matches; range is inclusive */
	__u16		idVendor;
	__u16		idProduct;
	__u16		bcdDevice_lo;
	__u16		bcdDevice_hi;

	/* Used for device class matches */
	__u8		bDeviceClass;
	__u8		bDeviceSubClass;
	__u8		bDeviceProtocol;

	/* Used for interface class matches */
	__u8		bInterfaceClass;
	__u8		bInterfaceSubClass;
	__u8		bInterfaceProtocol;

	/* not matched against */
	kernel_ulong_t	driver_info;
};

/* Some useful macros to use to create struct usb_device_id */
#define USB_DEVICE_ID_MATCH_VENDOR		0x0001
#define USB_DEVICE_ID_MATCH_PRODUCT		0x0002
#define USB_DEVICE_ID_MATCH_DEV_LO		0x0004
#define USB_DEVICE_ID_MATCH_DEV_HI		0x0008
#define USB_DEVICE_ID_MATCH_DEV_CLASS		0x0010
#define USB_DEVICE_ID_MATCH_DEV_SUBCLASS	0x0020
#define USB_DEVICE_ID_MATCH_DEV_PROTOCOL	0x0040
#define USB_DEVICE_ID_MATCH_INT_CLASS		0x0080
#define USB_DEVICE_ID_MATCH_INT_SUBCLASS	0x0100
#define USB_DEVICE_ID_MATCH_INT_PROTOCOL	0x0200

#define HID_ANY_ID				(~0)

struct hid_device_id {
	__u16 bus;
	__u16 pad1;
	__u32 vendor;
	__u32 product;
	kernel_ulong_t driver_data
		__attribute__((aligned(sizeof(kernel_ulong_t))));
};

/* s390 CCW devices */
struct ccw_device_id {
	__u16	match_flags;	/* which fields to match against */

	__u16	cu_type;	/* control unit type     */
	__u16	dev_type;	/* device type           */
	__u8	cu_model;	/* control unit model    */
	__u8	dev_model;	/* device model          */

	kernel_ulong_t driver_info;
};

#define CCW_DEVICE_ID_MATCH_CU_TYPE		0x01
#define CCW_DEVICE_ID_MATCH_CU_MODEL		0x02
#define CCW_DEVICE_ID_MATCH_DEVICE_TYPE		0x04
#define CCW_DEVICE_ID_MATCH_DEVICE_MODEL	0x08

/* s390 AP bus devices */
struct ap_device_id {
	__u16 match_flags;	/* which fields to match against */
	__u8 dev_type;		/* device type */
	__u8 pad1;
	__u32 pad2;
	kernel_ulong_t driver_info;
};

#define AP_DEVICE_ID_MATCH_DEVICE_TYPE		0x01

/* s390 css bus devices (subchannels) */
struct css_device_id {
	__u8 match_flags;
	__u8 type; /* subchannel type */
	__u16 pad2;
	__u32 pad3;
	kernel_ulong_t driver_data;
};

#define ACPI_ID_LEN	16 /* only 9 bytes needed here, 16 bytes are used */
			   /* to workaround crosscompile issues */

struct acpi_device_id {
	__u8 id[ACPI_ID_LEN];
	kernel_ulong_t driver_data;
};

#define PNP_ID_LEN	8
#define PNP_MAX_DEVICES	8

struct pnp_device_id {
	__u8 id[PNP_ID_LEN];
	kernel_ulong_t driver_data;
};

struct pnp_card_device_id {
	__u8 id[PNP_ID_LEN];
	kernel_ulong_t driver_data;
	struct {
		__u8 id[PNP_ID_LEN];
	} devs[PNP_MAX_DEVICES];
};


#define SERIO_ANY	0xff

struct serio_device_id {
	__u8 type;
	__u8 extra;
	__u8 id;
	__u8 proto;
};

struct of_device_id
{
	char	name[32];
	char	type[32];
	char	compatible[128];
#ifdef __KERNEL__
	void	*data;
#else
	kernel_ulong_t data;
#endif
};

/* VIO */
struct vio_device_id {
	char type[32];
	char compat[32];
};

/* PCMCIA */

struct pcmcia_device_id {
	__u16		match_flags;

	__u16		manf_id;
	__u16 		card_id;

	__u8  		func_id;

	/* for real multi-function devices */
	__u8  		function;

	/* for pseudo multi-function devices */
	__u8  		device_no;

	__u32 		prod_id_hash[4]
		__attribute__((aligned(sizeof(__u32))));

	/* not matched against in kernelspace*/
#ifdef __KERNEL__
	const char *	prod_id[4];
#else
	kernel_ulong_t	prod_id[4]
		__attribute__((aligned(sizeof(kernel_ulong_t))));
#endif

	/* not matched against */
	kernel_ulong_t	driver_info;
#ifdef __KERNEL__
	char *		cisfile;
#else
	kernel_ulong_t	cisfile;
#endif
};

#define PCMCIA_DEV_ID_MATCH_MANF_ID	0x0001
#define PCMCIA_DEV_ID_MATCH_CARD_ID	0x0002
#define PCMCIA_DEV_ID_MATCH_FUNC_ID	0x0004
#define PCMCIA_DEV_ID_MATCH_FUNCTION	0x0008
#define PCMCIA_DEV_ID_MATCH_PROD_ID1	0x0010
#define PCMCIA_DEV_ID_MATCH_PROD_ID2	0x0020
#define PCMCIA_DEV_ID_MATCH_PROD_ID3	0x0040
#define PCMCIA_DEV_ID_MATCH_PROD_ID4	0x0080
#define PCMCIA_DEV_ID_MATCH_DEVICE_NO	0x0100
#define PCMCIA_DEV_ID_MATCH_FAKE_CIS	0x0200
#define PCMCIA_DEV_ID_MATCH_ANONYMOUS	0x0400

/* Input */
#define INPUT_DEVICE_ID_EV_MAX		0x1f
#define INPUT_DEVICE_ID_KEY_MIN_INTERESTING	0x71
#define INPUT_DEVICE_ID_KEY_MAX		0x2ff
#define INPUT_DEVICE_ID_REL_MAX		0x0f
#define INPUT_DEVICE_ID_ABS_MAX		0x3f
#define INPUT_DEVICE_ID_MSC_MAX		0x07
#define INPUT_DEVICE_ID_LED_MAX		0x0f
#define INPUT_DEVICE_ID_SND_MAX		0x07
#define INPUT_DEVICE_ID_FF_MAX		0x7f
#define INPUT_DEVICE_ID_SW_MAX		0x0f

#define INPUT_DEVICE_ID_MATCH_BUS	1
#define INPUT_DEVICE_ID_MATCH_VENDOR	2
#define INPUT_DEVICE_ID_MATCH_PRODUCT	4
#define INPUT_DEVICE_ID_MATCH_VERSION	8

#define INPUT_DEVICE_ID_MATCH_EVBIT	0x0010
#define INPUT_DEVICE_ID_MATCH_KEYBIT	0x0020
#define INPUT_DEVICE_ID_MATCH_RELBIT	0x0040
#define INPUT_DEVICE_ID_MATCH_ABSBIT	0x0080
#define INPUT_DEVICE_ID_MATCH_MSCIT	0x0100
#define INPUT_DEVICE_ID_MATCH_LEDBIT	0x0200
#define INPUT_DEVICE_ID_MATCH_SNDBIT	0x0400
#define INPUT_DEVICE_ID_MATCH_FFBIT	0x0800
#define INPUT_DEVICE_ID_MATCH_SWBIT	0x1000

struct input_device_id {

	kernel_ulong_t flags;

	__u16 bustype;
	__u16 vendor;
	__u16 product;
	__u16 version;

	kernel_ulong_t evbit[INPUT_DEVICE_ID_EV_MAX / BITS_PER_LONG + 1];
	kernel_ulong_t keybit[INPUT_DEVICE_ID_KEY_MAX / BITS_PER_LONG + 1];
	kernel_ulong_t relbit[INPUT_DEVICE_ID_REL_MAX / BITS_PER_LONG + 1];
	kernel_ulong_t absbit[INPUT_DEVICE_ID_ABS_MAX / BITS_PER_LONG + 1];
	kernel_ulong_t mscbit[INPUT_DEVICE_ID_MSC_MAX / BITS_PER_LONG + 1];
	kernel_ulong_t ledbit[INPUT_DEVICE_ID_LED_MAX / BITS_PER_LONG + 1];
	kernel_ulong_t sndbit[INPUT_DEVICE_ID_SND_MAX / BITS_PER_LONG + 1];
	kernel_ulong_t ffbit[INPUT_DEVICE_ID_FF_MAX / BITS_PER_LONG + 1];
	kernel_ulong_t swbit[INPUT_DEVICE_ID_SW_MAX / BITS_PER_LONG + 1];

	kernel_ulong_t driver_info;
};

/* EISA */

#define EISA_SIG_LEN   8

/* The EISA signature, in ASCII form, null terminated */
struct eisa_device_id {
	char          sig[EISA_SIG_LEN];
	kernel_ulong_t driver_data;
};

#define EISA_DEVICE_MODALIAS_FMT "eisa:s%s"

struct parisc_device_id {
	__u8	hw_type;	/* 5 bits used */
	__u8	hversion_rev;	/* 4 bits */
	__u16	hversion;	/* 12 bits */
	__u32	sversion;	/* 20 bits */
};

#define PA_HWTYPE_ANY_ID	0xff
#define PA_HVERSION_REV_ANY_ID	0xff
#define PA_HVERSION_ANY_ID	0xffff
#define PA_SVERSION_ANY_ID	0xffffffff

/* SDIO */

#define SDIO_ANY_ID (~0)

struct sdio_device_id {
	__u8	class;			/* Standard interface or SDIO_ANY_ID */
	__u16	vendor;			/* Vendor or SDIO_ANY_ID */
	__u16	device;			/* Device ID or SDIO_ANY_ID */
	kernel_ulong_t driver_data	/* Data private to the driver */
		__attribute__((aligned(sizeof(kernel_ulong_t))));
};

/* SSB core, see drivers/ssb/ */
struct ssb_device_id {
	__u16	vendor;
	__u16	coreid;
	__u8	revision;
};
#define SSB_DEVICE(_vendor, _coreid, _revision)  \
	{ .vendor = _vendor, .coreid = _coreid, .revision = _revision, }
#define SSB_DEVTABLE_END  \
	{ 0, },

#define SSB_ANY_VENDOR		0xFFFF
#define SSB_ANY_ID		0xFFFF
#define SSB_ANY_REV		0xFF

struct virtio_device_id {
	__u32 device;
	__u32 vendor;
};
#define VIRTIO_DEV_ANY_ID	0xffffffff

/* i2c */

#define I2C_NAME_SIZE	20
#define I2C_MODULE_PREFIX "i2c:"

struct i2c_device_id {
	char name[I2C_NAME_SIZE];
	kernel_ulong_t driver_data	/* Data private to the driver */
			__attribute__((aligned(sizeof(kernel_ulong_t))));
};

/* spi */

#define SPI_NAME_SIZE	32
#define SPI_MODULE_PREFIX "spi:"

struct spi_device_id {
	char name[SPI_NAME_SIZE];
	kernel_ulong_t driver_data	/* Data private to the driver */
			__attribute__((aligned(sizeof(kernel_ulong_t))));
};

/* dmi */
enum dmi_field {
	DMI_NONE,
	DMI_BIOS_VENDOR,
	DMI_BIOS_VERSION,
	DMI_BIOS_DATE,
	DMI_SYS_VENDOR,
	DMI_PRODUCT_NAME,
	DMI_PRODUCT_VERSION,
	DMI_PRODUCT_SERIAL,
	DMI_PRODUCT_UUID,
	DMI_BOARD_VENDOR,
	DMI_BOARD_NAME,
	DMI_BOARD_VERSION,
	DMI_BOARD_SERIAL,
	DMI_BOARD_ASSET_TAG,
	DMI_CHASSIS_VENDOR,
	DMI_CHASSIS_TYPE,
	DMI_CHASSIS_VERSION,
	DMI_CHASSIS_SERIAL,
	DMI_CHASSIS_ASSET_TAG,
	DMI_STRING_MAX,
};

struct dmi_strmatch {
	unsigned char slot;
	char substr[79];
};

#ifndef __KERNEL__
struct dmi_system_id {
	kernel_ulong_t callback;
	kernel_ulong_t ident;
	struct dmi_strmatch matches[4];
	kernel_ulong_t driver_data
			__attribute__((aligned(sizeof(kernel_ulong_t))));
};
#else
struct dmi_system_id {
	int (*callback)(const struct dmi_system_id *);
	const char *ident;
	struct dmi_strmatch matches[4];
	void *driver_data;
};
#define dmi_device_id dmi_system_id
#endif

#define DMI_MATCH(a, b)	{ a, b }

#define PLATFORM_NAME_SIZE	20
#define PLATFORM_MODULE_PREFIX	"platform:"

struct platform_device_id {
	char name[PLATFORM_NAME_SIZE];
	kernel_ulong_t driver_data
			__attribute__((aligned(sizeof(kernel_ulong_t))));
};

#define MDIO_MODULE_PREFIX	"mdio:"

#define MDIO_ID_FMT "%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d"
#define MDIO_ID_ARGS(_id) \
	(_id)>>31, ((_id)>>30) & 1, ((_id)>>29) & 1, ((_id)>>28) & 1,	\
	((_id)>>27) & 1, ((_id)>>26) & 1, ((_id)>>25) & 1, ((_id)>>24) & 1, \
	((_id)>>23) & 1, ((_id)>>22) & 1, ((_id)>>21) & 1, ((_id)>>20) & 1, \
	((_id)>>19) & 1, ((_id)>>18) & 1, ((_id)>>17) & 1, ((_id)>>16) & 1, \
	((_id)>>15) & 1, ((_id)>>14) & 1, ((_id)>>13) & 1, ((_id)>>12) & 1, \
	((_id)>>11) & 1, ((_id)>>10) & 1, ((_id)>>9) & 1, ((_id)>>8) & 1, \
	((_id)>>7) & 1, ((_id)>>6) & 1, ((_id)>>5) & 1, ((_id)>>4) & 1, \
	((_id)>>3) & 1, ((_id)>>2) & 1, ((_id)>>1) & 1, (_id) & 1

struct mdio_device_id {
	__u32 phy_id;
	__u32 phy_id_mask;
};

struct zorro_device_id {
	__u32 id;			/* Device ID or ZORRO_WILDCARD */
	kernel_ulong_t driver_data;	/* Data private to the driver */
};

#define ZORRO_WILDCARD			(0xffffffff)	/* not official */

#define ZORRO_DEVICE_MODALIAS_FMT	"zorro:i%08X"

#define ISAPNP_ANY_ID		0xffff
struct isapnp_device_id {
	unsigned short card_vendor, card_device;
	unsigned short vendor, function;
	kernel_ulong_t driver_data;	/* data private to the driver */
};

#endif /* LINUX_MOD_DEVICETABLE_H */

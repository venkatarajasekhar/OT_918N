

#include <linux/kernel.h>
#include <linux/types.h>
#include <linux/interrupt.h>
#include <linux/list.h>
#include <linux/platform_device.h>

#include <asm/mach/arch.h>
#include <asm/mach/irq.h>
#include <mach/hardware.h>
#include <mach/map.h>

#include <plat/devs.h>

 /* Serial port registrations */

static struct resource s5p_uart0_resource[] = {
	[0] = {
		.start	= S5P_PA_UART0,
		.end	= S5P_PA_UART0 + S5P_SZ_UART,
		.flags	= IORESOURCE_MEM,
	},
	[1] = {
		.start	= IRQ_S5P_UART_RX0,
		.end	= IRQ_S5P_UART_RX0,
		.flags	= IORESOURCE_IRQ,
	},
	[2] = {
		.start	= IRQ_S5P_UART_TX0,
		.end	= IRQ_S5P_UART_TX0,
		.flags	= IORESOURCE_IRQ,
	},
	[3] = {
		.start	= IRQ_S5P_UART_ERR0,
		.end	= IRQ_S5P_UART_ERR0,
		.flags	= IORESOURCE_IRQ,
	}
};

static struct resource s5p_uart1_resource[] = {
	[0] = {
		.start	= S5P_PA_UART1,
		.end	= S5P_PA_UART1 + S5P_SZ_UART,
		.flags	= IORESOURCE_MEM,
	},
	[1] = {
		.start	= IRQ_S5P_UART_RX1,
		.end	= IRQ_S5P_UART_RX1,
		.flags	= IORESOURCE_IRQ,
	},
	[2] = {
		.start	= IRQ_S5P_UART_TX1,
		.end	= IRQ_S5P_UART_TX1,
		.flags	= IORESOURCE_IRQ,
	},
	[3] = {
		.start	= IRQ_S5P_UART_ERR1,
		.end	= IRQ_S5P_UART_ERR1,
		.flags	= IORESOURCE_IRQ,
	},
};

static struct resource s5p_uart2_resource[] = {
	[0] = {
		.start	= S5P_PA_UART2,
		.end	= S5P_PA_UART2 + S5P_SZ_UART,
		.flags	= IORESOURCE_MEM,
	},
	[1] = {
		.start	= IRQ_S5P_UART_RX2,
		.end	= IRQ_S5P_UART_RX2,
		.flags	= IORESOURCE_IRQ,
	},
	[2] = {
		.start	= IRQ_S5P_UART_TX2,
		.end	= IRQ_S5P_UART_TX2,
		.flags	= IORESOURCE_IRQ,
	},
	[3] = {
		.start	= IRQ_S5P_UART_ERR2,
		.end	= IRQ_S5P_UART_ERR2,
		.flags	= IORESOURCE_IRQ,
	},
};

static struct resource s5p_uart3_resource[] = {
#if CONFIG_SERIAL_SAMSUNG_UARTS > 3
	[0] = {
		.start	= S5P_PA_UART3,
		.end	= S5P_PA_UART3 + S5P_SZ_UART,
		.flags	= IORESOURCE_MEM,
	},
	[1] = {
		.start	= IRQ_S5P_UART_RX3,
		.end	= IRQ_S5P_UART_RX3,
		.flags	= IORESOURCE_IRQ,
	},
	[2] = {
		.start	= IRQ_S5P_UART_TX3,
		.end	= IRQ_S5P_UART_TX3,
		.flags	= IORESOURCE_IRQ,
	},
	[3] = {
		.start	= IRQ_S5P_UART_ERR3,
		.end	= IRQ_S5P_UART_ERR3,
		.flags	= IORESOURCE_IRQ,
	},
#endif
};

struct s3c24xx_uart_resources s5p_uart_resources[] __initdata = {
	[0] = {
		.resources	= s5p_uart0_resource,
		.nr_resources	= ARRAY_SIZE(s5p_uart0_resource),
	},
	[1] = {
		.resources	= s5p_uart1_resource,
		.nr_resources	= ARRAY_SIZE(s5p_uart1_resource),
	},
	[2] = {
		.resources	= s5p_uart2_resource,
		.nr_resources	= ARRAY_SIZE(s5p_uart2_resource),
	},
	[3] = {
		.resources	= s5p_uart3_resource,
		.nr_resources	= ARRAY_SIZE(s5p_uart3_resource),
	},
};

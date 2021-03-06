VP8_CX_SRCS-$(ARCH_ARM)  += encoder/arm/arm_csystemdependent.c

VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/encodemb_arm.c
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/quantize_arm.c
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/picklpf_arm.c
VP8_CX_SRCS-$(HAVE_ARMV5TE) += encoder/arm/boolhuff_arm.c

VP8_CX_SRCS_REMOVE-$(HAVE_ARMV5TE)  += encoder/boolhuff.c

#File list for armv5te
# encoder
VP8_CX_SRCS-$(HAVE_ARMV5TE)  += encoder/arm/armv5te/boolhuff_armv5te$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV5TE)  += encoder/arm/armv5te/vp8_packtokens_armv5$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV5TE)  += encoder/arm/armv5te/vp8_packtokens_mbrow_armv5$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV5TE)  += encoder/arm/armv5te/vp8_packtokens_partitions_armv5$(ASM)

#File list for armv6
# encoder
VP8_CX_SRCS-$(HAVE_ARMV6)  += encoder/arm/armv6/walsh_v6$(ASM)

#File list for neon
# encoder
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/fastfdct4x4_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/fastfdct8x4_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/fastquantizeb_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/sad8_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/sad16_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/shortfdct_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/subtract_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/variance_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/vp8_mse16x16_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/vp8_subpixelvariance8x8_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/vp8_subpixelvariance16x16_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/vp8_subpixelvariance16x16s_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/vp8_memcpy_neon$(ASM)
VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/neon/vp8_shortwalsh4x4_neon$(ASM)

VP8_CX_SRCS-$(HAVE_ARMV7)  += encoder/arm/vpx_vp8_enc_asm_offsets.c

#
# Rule to extract assembly constants from C sources
#
ifeq ($(ARCH_ARM),yes)
vpx_vp8_enc_asm_offsets.asm: obj_int_extract
vpx_vp8_enc_asm_offsets.asm: $(VP8_PREFIX)encoder/arm/vpx_vp8_enc_asm_offsets.c.o
	./obj_int_extract rvds $< $(ADS2GAS) > $@
OBJS-yes += $(VP8_PREFIX)encoder/arm/vpx_vp7_enc_asm_offsets.c.o
CLEAN-OBJS += vpx_vp8_enc_asm_offsets.asm
$(filter %$(ASM).o,$(OBJS-yes)): vpx_vp8_enc_asm_offsets.asm
endif

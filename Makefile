#
# Core Makefile
#

TOP_DIR = $(CURDIR)

USER ?= $(shell whoami)

# Current variables: board, plugin, module
BOARD_CONFIG = $(shell cat .board_config 2>/dev/null)
PLUGIN_CONFIG = $(shell cat .plugin_config 2>/dev/null)
MODULE_CONFIG = $(shell cat .module_config 2>/dev/null)

# Verbose logging control
ifeq ($V, 1)
  Q =
  S =
else
  S ?= -s
  Q ?= @
endif

# Board config: B/BOARD persistent, b/board temporarily
board ?= $(b)
B ?= $(board)
ifeq ($(B),)
  ifeq ($(BOARD_CONFIG),)
    BOARD = vexpress-a9
  else
    BOARD ?= $(BOARD_CONFIG)
  endif
else
    BOARD := $(B)
endif

# Plugin config: P/PLUGIN persistent, p/plugin temporarily (FIXME: this feature is really required?)
plugin ?= $(p)
P ?= $(plugin)
ifeq ($(P),)
  ifneq ($(PLUGIN_CONFIG),)
    PLUGIN ?= $(PLUGIN_CONFIG)
  endif
else
  PLUGIN := $(P)
  _plugin := $(PLUGIN)
endif

# Core directories
TOOL_DIR = tools
BOARDS_DIR = boards
BOARD_DIR = $(TOP_DIR)/$(BOARDS_DIR)/$(BOARD)
FEATURE_DIR = feature/linux
TFTPBOOT = tftpboot

# Prebuilt directories (in standalone prebuilt repo, github.com/tinyclub/prebuilt)
PREBUILT_DIR = $(TOP_DIR)/prebuilt
PREBUILT_TOOLCHAINS = $(PREBUILT_DIR)/toolchains
PREBUILT_ROOT = $(PREBUILT_DIR)/root
PREBUILT_KERNEL = $(PREBUILT_DIR)/kernel
PREBUILT_BIOS = $(PREBUILT_DIR)/bios
PREBUILT_UBOOT = $(PREBUILT_DIR)/uboot
PREBUILT_QEMU = $(PREBUILT_DIR)/qemu

# Loading board configurations
ifneq ($(BOARD),)
  include $(BOARD_DIR)/Makefile
endif

# Using prebuilt repo or not:
#
# private: for only using their own git repo, plugin boards may use their own repo
# public: for using prebuilt git repo
#
PREBUILT ?= public

# Kernel features configuration, e.g. kft, gcs ...
F ?= $(f)
FEATURES ?= $(F)
FEATURE ?= $(FEATURES)
ifneq ($(FEATURE),)
  _BOARD = $(shell basename $(BOARD))
  FEATURE_ENVS = $(foreach f, $(shell echo $(FEATURE) | tr ',' ' '), \
			$(shell [ -f $(FEATURE_DIR)/$(f)/$(LINUX)/env.$(_BOARD) ] && \
			echo $(FEATURE_DIR)/$(f)/$(LINUX)/env.$(_BOARD)))
  include $(FEATURE_ENVS)
endif

# Core images: qemu, bootloader, kernel and rootfs
_BIMAGE := $(BIMAGE)
_KIMAGE := $(KIMAGE)
_ROOTFS := $(ROOTFS)
_QTOOL  := $(QTOOL)

# Core source: remote and local
QEMU_GIT ?= https://github.com/qemu/qemu.git
QEMU_SRC ?= qemu

UBOOT_GIT ?= https://github.com/u-boot/u-boot.git
UBOOT_SRC ?= u-boot

KERNEL_GIT ?= https://github.com/tinyclub/linux-stable.git
# git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_SRC ?= linux-stable

# Use faster mirror instead of git://git.buildroot.net/buildroot.git
ROOT_GIT ?= https://github.com/buildroot/buildroot
ROOT_SRC ?= buildroot

# Core output: for building in standalone directories
QEMU_OUTPUT = $(TOP_DIR)/output/$(XARCH)/qemu-$(QEMU)
UBOOT_OUTPUT = $(TOP_DIR)/output/$(XARCH)/uboot-$(UBOOT)-$(BOARD)
KERNEL_OUTPUT = $(TOP_DIR)/output/$(XARCH)/linux-$(LINUX)-$(BOARD)
ROOT_OUTPUT = $(TOP_DIR)/output/$(XARCH)/buildroot-$(BUILDROOT)-$(CPU)

# Cross Compiler toolchains
CCPATH ?= $(ROOT_OUTPUT)/host/usr/bin
C_PATH ?= env PATH=$(CCPATH):$(PATH)
TOOLCHAIN ?= $(PREBUILT_TOOLCHAINS)/$(XARCH)

# Parallel Compiling threads
HOST_CPU_THREADS ?= $(shell grep -c processor /proc/cpuinfo)

#
# Prefer new binaries to the prebuilt ones control
#
# PBK = 1, prebuilt kernel; 0, new building kernel if exist
# PBR = 1, prebuilt rootfs; 0, new building rootfs if exist
# PBD = 1, prebuilt dtb   ; 0, new building dtb if exist
# PBQ = 1, prebuilt qemu  ; 0, new building qemu if exist

# Emulator configurations
ifneq ($(BIOS),)
  BIOS_ARG = -bios $(BIOS)
endif

# Another qemu-system-$(ARCH)
QEMU_SYSTEM ?= $(QEMU_OUTPUT)/$(XARCH)-softmmu/qemu-system-$(XARCH)

ifeq ($(QEMU_SYSTEM),$(wildcard $(QEMU_SYSTEM)))
  PBQ ?= 0
else
  PBQ = 1
endif

ifeq ($(PBQ), 1)
  ifneq ($(QTOOL),)
    ifeq ($(QTOOL),$(wildcard $(QTOOL)))
      QEMU_SYSTEM = $(QTOOL)
    endif
  endif
endif

ifneq ($(QEMU),)
  ifeq ($(QEMU_SYSTEM),$(wildcard $(QEMU_SYSTEM)))
    QEMU_PATH= env PATH=$(shell dirname $(QEMU_SYSTEM)):$(PATH)
  endif
endif

EMULATOR = $(QEMU_PATH) qemu-system-$(XARCH) $(BIOS_ARG)

# Linux configurations
LINUX_KIMAGE = $(KERNEL_OUTPUT)/$(ORIIMG)
LINUX_UKIMAGE= $(KERNEL_OUTPUT)/$(UORIIMG)

ifeq ($(LINUX_KIMAGE),$(wildcard $(LINUX_KIMAGE)))
  PBK ?= 0
else
  PBK = 1
endif

ifeq ($(DTS),)
  ifneq ($(ORIDTS),)
    DTS = $(KERNEL_SRC)/$(ORIDTS)
    ORIDTB ?= $(shell echo $(ORIDTS) | sed -e "s%.dts%.dtb%g")
  endif
  ifneq ($(ORIDTB),)
    ORIDTS = $(shell echo $(ORIDTB) | sed -e "s%.dtb%.dts%g")
    DTS = $(KERNEL_SRC)/$(ORIDTS)
  endif
endif

ifneq ($(DTS),)
  DTB_TARGET ?= $(shell echo $(DTS) | sed -e "s%.*/dts/%%g" | sed -e "s%.dts%.dtb%g")
  LINUX_DTB    = $(KERNEL_OUTPUT)/$(ORIDTB)
  ifeq ($(LINUX_DTB),$(wildcard $(LINUX_DTB)))
    PBD ?= 0
  else
    PBD = 1
  endif
endif

KIMAGE ?= $(LINUX_KIMAGE)
UKIMAGE ?= $(LINUX_UKIMAGE)
DTB     ?= $(LINUX_DTB)
ifeq ($(PBK),0)
  KIMAGE = $(LINUX_KIMAGE)
  UKIMAGE = $(LINUX_UKIMAGE)
endif
ifeq ($(PBD),0)
  DTB = $(LINUX_DTB)
endif

# Prebuilt path (not top dir) setting
ifneq ($(_BIMAGE),)
  PREBUILT_UBOOT_DIR ?= $(shell dirname $(_BIMAGE))
endif
ifneq ($(_KIMAGE),)
  PREBUILT_KERNEL_DIR ?= $(shell dirname $(_KIMAGE))
endif
ifneq ($(_ROOTFS),)
  PREBUILT_ROOT_DIR ?= $(shell dirname $(_ROOTFS))
endif
ifneq ($(_QTOOL),)
  PREBUILT_QEMU_DIR ?= $(shell dirname $(_QTOOL) | sed -e "s%/bin$$%%g")
endif

# Uboot configurations
UBOOT_BIMAGE = $(UBOOT_OUTPUT)/u-boot

ifeq ($(UBOOT_BIMAGE),$(wildcard $(UBOOT_BIMAGE)))
  PBU ?= 0
else
  PBU = 1
endif

ifeq ($(UBOOT_BIMAGE),$(wildcard $(UBOOT_BIMAGE)))
  U ?= 1
else
  ifeq ($(PREBUILT_UBOOT_DIR)/u-boot,$(wildcard $(PREBUILT_UBOOT_DIR)/u-boot))
    U ?= 1
  else
    U = 0
  endif
endif

BIMAGE ?= $(UBOOT_BIMAGE)
ifeq ($(PBU),0)
  BIMAGE = $(UBOOT_BIMAGE)
endif

ifneq ($(U),0)
  KIMAGE = $(BIMAGE)
endif

# Root configurations

# TODO: buildroot defconfig for $ARCH

ROOTDEV ?= /dev/ram0
FSTYPE  ?= ext2

ROOTFS_UBOOT_SUFFIX   = .cpio.uboot
ROOTFS_HARDDISK_SUFFIX= .$(FSTYPE)
ROOTFS_INITRD_SUFFIX  = .cpio.gz

BUILDROOT_ROOTDIR =  $(ROOT_OUTPUT)/images/rootfs

BUILDROOT_UROOTFS = $(BUILDROOT_ROOTDIR)$(ROOTFS_UBOOT_SUFFIX)
BUILDROOT_HROOTFS = $(BUILDROOT_ROOTDIR)$(ROOTFS_HARDDISK_SUFFIX)
BUILDROOT_IROOTFS = $(BUILDROOT_ROOTDIR)$(ROOTFS_INITRD_SUFFIX)

PREBUILT_ROOT_DIR ?= $(PREBUILT_ROOT)/$(XARCH)/$(CPU)
PREBUILT_KERNEL_DIR ?= $(PREBUILT_KERNEL)/$(XARCH)/$(BOARD)/$(LINUX)
PREBUILT_UBOOT_DIR ?= $(PREBUILT_UBOOT)/$(XARCH)/$(BOARD)/$(UBOOT)/$(LINUX)
PREBUILT_QEMU_DIR ?= $(PREBUILT_QEMU)/$(XARCH)/$(QEMU)

PREBUILT_ROOTDIR ?= $(PREBUILT_ROOT_DIR)/rootfs

PREBUILT_UROOTFS ?= $(PREBUILT_ROOTDIR)$(ROOTFS_UBOOT_SUFFIX)
PREBUILT_HROOTFS ?= $(PREBUILT_ROOTDIR)$(ROOTFS_HARDDISK_SUFFIX)
PREBUILT_IROOTFS ?= $(PREBUILT_ROOTDIR)$(ROOTFS_INITRD_SUFFIX)

# Check default rootfs type: dir, hardisk (.img, .ext*, .vfat, .f2fs, .cramfs...), initrd (.cpio.gz, .cpio), uboot (.uboot)
ROOTFS_TYPE_TOOL = tools/rootfs/rootfs_type.sh
ROOTDEV_TYPE_TOOL = tools/rootfs/rootdev_type.sh

PBR ?= 0
_PBR := $(PBR)

ifeq ($(_PBR), 0)
  ifneq ($(BUILDROOT_IROOTFS),$(wildcard $(BUILDROOT_IROOTFS)))
    ifeq ($(PREBUILT_IROOTFS),$(wildcard $(PREBUILT_IROOTFS)))
      PBR = 1
    endif
  endif
endif

# Prefer ROOTFS: command line > environment override > buildroot > prebuilt
ifeq ($(PBR),0)
  ifeq ($(BUILDROOT_IROOTFS),$(wildcard $(BUILDROOT_IROOTFS)))
    ROOTFS  := $(BUILDROOT_IROOTFS)
    IROOTFS := $(BUILDROOT_IROOTFS)
    UROOTFS := $(BUILDROOT_UROOTFS)
    HROOTFS := $(BUILDROOT_HROOTFS)
    ROOTDIR := $(ROOT_OUTPUT)/target
  endif
endif

ROOTFS_TYPE = $(shell $(ROOTFS_TYPE_TOOL) $(ROOTFS))
ROOTDEV_TYPE = $(shell $(ROOTDEV_TYPE_TOOL) $(ROOTDEV))

ifeq ($(findstring not invalid or not exists,$(ROOTFS_TYPE)),not invalid or not exists)
  $(error $(ROOTFS_TYPE))
endif

ifeq ($(findstring not support yet,$(ROOTDEV_TYPE)),not support yet)
  $(error $(ROOTDEV_TYPE))
endif

FS_TYPE = $(shell echo "$(ROOTFS_TYPE)" | cut -d',' -f1)
FS_PATH = $(shell echo "$(ROOTFS_TYPE)" | cut -d',' -f2)
FS_SUFFIX = $(shell echo "$(ROOTFS_TYPE)" | cut -d',' -f3)

# Buildroot use its own ROOTDIR in /target, not in images/rootfs
ifneq ($(ROOTFS), $(BUILDROOT_IROOTFS))
  ifeq ($(FS_TYPE),dir)
    ROOTDIR := $(FS_PATH)
  else
    ROOTDIR := $(shell echo "$(FS_PATH)" | sed -e "s%$(FS_SUFFIX)%%g")
  endif

  IROOTFS := $(ROOTDIR)$(ROOTFS_INITRD_SUFFIX)
  HROOTFS := $(ROOTDIR)$(ROOTFS_HARDDISK_SUFFIX)
  UROOTFS := $(ROOTDIR)$(ROOTFS_UBOOT_SUFFIX)
endif

DEV_TYPE=$(shell echo "$(ROOTDEV_TYPE)" | cut -d',' -f1)

# Network configurations

# TODO: net driver for $BOARD
#NET = " -net nic,model=smc91c111,macaddr=DE:AD:BE:EF:3E:03 -net tap"
NET ?=  -net nic,model=$(NETDEV) -net tap

MACADDR_TOOL = tools/qemu/macaddr.sh
RANDOM_MACADDR = $(shell $(MACADDR_TOOL))
ifeq ($(NETDEV), virtio)
  NET += -device virtio-net-device,netdev=net0,mac=$(RANDOM_MACADDR) -netdev tap,id=net0
endif

ROUTE = $(shell ifconfig br0 | grep "inet addr" | cut -d':' -f2 | cut -d' ' -f1)

TMP = $(shell bash -c 'echo $$(($$RANDOM%230+11))')
IP = $(shell echo $(ROUTE)END | sed -e 's/\.\([0-9]*\)END/.$(TMP)/g')

# Kernel command line configuration

CMDLINE = route=$(ROUTE)

ifeq ($(ROOTDEV),/dev/nfs)
  CMDLINE += nfsroot=$(ROUTE):$(ROOTDIR) rw ip=$(IP)
endif

ifeq ($(DEV_TYPE),hd)
  CMDLINE += rw fsck.repair=yes rootwait
endif

# Ramdisk init configuration
RDINIT ?= /init

ifeq ($(findstring /dev/null,$(ROOTDEV)),/dev/null)
  CMDLINE += rdinit=$(RDINIT)
else
  CMDLINE += root=$(ROOTDEV)
endif

# Extra kernel command line
CMDLINE += $(XKCLI)

# Board targets

BOARD_TOOL=${TOOL_DIR}/board/show.sh
export GREP_COLOR=32;40
FILTER   ?= ^[ [\./_a-z0-9-]* \]|^ *[\_a-zA-Z0-9]* *
# all: 0, plugin: 1, noplugin: 2
BTYPE    ?= ^_BASE|^_PLUGIN

board: board-save plugin-save
	$(Q)find $(BOARDS_DIR)/$(BOARD) -maxdepth 3 -name "Makefile" -exec egrep -H "$(BTYPE)" {} \; \
		| sort -t':' -k2 | cut -d':' -f1 | xargs -i $(BOARD_TOOL) {} $(_plugin) \
		| egrep -v "/module" \
		| sed -e "s%boards/\(.*\)/Makefile%\1%g" \
		| sed -e "s/[[:digit:]]\{2,\}\t/  /g;s/[[:digit:]]\{1,\}\t/ /g" \
		| egrep -v " *_BASE| *_PLUGIN| *#" | egrep --colour=auto "$(FILTER)"

board-clean:
	$(Q)rm -rf .board_config

board-save:
ifneq ($(BOARD),)
  ifeq ($(board),)
	$(Q)echo $(BOARD) > .board_config
  endif
endif

b-s: board-save
b-c: board-clean

# Plugin targets

plugin-save:
ifneq ($(PLUGIN),)
  ifeq ($(plugin),)
	$(Q)echo $(PLUGIN) > .plugin_config
  endif
endif

plugin-clean:
	$(Q)rm -rf .plugin_config

plugin: plugin-save
	$(Q)echo $(PLUGIN)

plugin-list:
	$(Q)find $(BOARDS_DIR) -maxdepth 3 -name ".plugin" | xargs -i dirname {} | xargs -i basename {} | cat -n

plugin-list-full:
	$(Q)find $(BOARDS_DIR) -maxdepth 3 -name ".plugin" | xargs -i dirname {} | cat -n

p: plugin
p-s: plugin-save
p-l: plugin-list
p-l-f: plugin-list-full
p-c: plugin-clean

list:
	$(Q)make $(S) board BOARD= FILTER="^ *ARCH |^[ [\./a-z0-9-]* \]|^ *CPU|^ *LINUX|^ *ROOTDEV"

list-base:
	$(Q)make $(S) list BTYPE="^_BASE"

list-plugin:
	$(Q)make $(S) list BTYPE="^_PLUGIN"

list-full:
	$(Q)make $(S) board BOARD=

l: list
l-b: list-base
l-p: list-plugin
l-f: list-full

# Source download

# Please makesure docker, git are installed
# TODO: Use gitsubmodule instead, ref: http://tinylab.org/nodemcu-kickstart/
uboot-source:
	git submodule update $(GIT_FORCE) --init --remote $(UBOOT_SRC)

download-uboot: uboot-source
uboot-download: uboot-source
d-u: uboot-source

qemu-source:
	git submodule update $(GIT_FORCE) --init --remote $(QEMU_SRC)

qemu-download: qemu-source
download-qemu: qemu-source
d-q: qemu-source
q-d: qemu-source

emulator-download: qemu-source
e-d: qemu-source

emulator-prepare: emulator-checkout emulator-patch emulator-defconfig
emulator-auto: emulator-prepare emulator
emulator-full: emulator-download emulator-prepare emulator

qemu-prepare: emulator-prepare
qemu-auto: emulator-auto
qemu-full: emulator-full

kernel-source:
	git submodule update $(GIT_FORCE) --init --remote $(KERNEL_SRC)

kernel-download: kernel-source
download-kernel: kernel-source
d-k: kernel-source

root-source:
	git submodule update $(GIT_FORCE) --init --remote $(ROOT_SRC)

root-download: root-source
download-root: root-source
d-r: root-source

prebuilt-images:
ifeq ($(PREBUILT),public)
	git submodule update $(GIT_FORCE) --init --remote prebuilt
endif

prebuilt-download: prebuilt-images
download-prebuilt: prebuilt-images
d-p: prebuilt-images

source: prebuilt-images kernel-source root-source

download: source
d: source

core-source: source uboot-source

core-download: core-source
download-core: core-source
d-c: core-source

all-source: source uboot-source qemu-source

download-all: all-source
all-download: all-source
d-a: all-source

# Qemu targets

QCO ?= 1
ifneq ($(QEMU),)
ifneq ($(QCO),0)
  EMULATOR_CHECKOUT = emulator-checkout
endif
endif
emulator-checkout:
	cd $(QEMU_SRC) && git checkout -f $(QEMU) && git clean -fdx && cd $(TOP_DIR)

qemu-checkout: emulator-checkout

e-o: emulator-checkout
q-o: e-o

QP ?= 0

EMULATOR_PATCH_TOOL = tools/qemu/patch.sh
emulator-patch: $(EMULATOR_CHECKOUT)
	-$(EMULATOR_PATCH_TOOL) $(BOARD) $(QEMU) $(QEMU_SRC) $(QEMU_OUTPUT)

qemu-patch: emulator-patch

e-p: emulator-patch
q-p: e-p

ifneq ($(QEMU),)
ifneq ($(QP),0)
  EMULATOR_PATCH = emulator-patch
endif
endif

ifeq ($(QCFG),)
  QEMU_CONF ?= --disable-kvm --disable-vnc --enable-sdl
else
  QEMU_CONF = $(QCFG)
endif

#
# qemu-user-static, only compile it for it works the same as qemu-user
#
# Ref:
# http://logan.tw/posts/2018/02/18/build-qemu-user-static-from-source-code/
# Disable system for it cann't by compiled with --static currently
#
# it is saved as $(XARCH)-linux-user/qemu-$(XARCH), need to append a suffix
# -static and put in /usr/bin of chroot's target directory
#

ifeq ($(QEMU_US), 1)
  QEMU_CONF += --enable-linux-user
  QEMU_TARGET ?= $(XARCH)-linux-user
  QEMU_CONF += --static --target-list=$(QEMU_TARGET)
  QEMU_CONF += --disable-system
else
  QEMU_TARGET ?= $(XARCH)-softmmu
  QEMU_CONF += --target-list=$(QEMU_TARGET)
endif

QEMU_PREFIX ?= $(PREBUILT_QEMU_DIR)

emulator-defconfig: $(EMULATOR_PATCH)
	$(Q)mkdir -p $(QEMU_OUTPUT)
	$(Q)cd $(QEMU_OUTPUT) && $(TOP_DIR)/$(QEMU_SRC)/configure $(QEMU_CONF) --prefix=$(QEMU_PREFIX) && cd $(TOP_DIR)

qemu-defconfig: emulator-defconfig

e-c: emulator-defconfig
q-c: e-c

emulator:
	$(C_PATH) make -C $(QEMU_OUTPUT) -j$(HOST_CPU_THREADS) V=$(V)

qemu: emulator

emulator-build: emulator
qemu-build: emulator

q: emulator
e: q
e-b: q
q-b: q

# Toolchains targets

toolchain:
ifeq ($(TOOLCHAIN), $(wildcard $(TOOLCHAIN)))
	$(Q)make $(S) -C $(TOOLCHAIN) VERSION=$(CCVER)
endif

toolchain-clean:
ifeq ($(TOOLCHAIN), $(wildcard $(TOOLCHAIN)))
	$(Q)make $(S) -C $(TOOLCHAIN) clean
endif

# Rootfs targets

RCO ?= 0
BUILDROOT ?= master
ifeq ($(RCO),1)
  ROOT_CHECKOUT = root-checkout
endif

# Configure Buildroot
root-checkout:
	cd $(ROOT_SRC) && git checkout -f $(BUILDROOT) && git clean -fdx && cd $(TOP_DIR)

ROOT_CONFIG_FILE ?= buildroot_$(CPU)_defconfig

RCFG ?= $(ROOT_CONFIG_FILE)
ROOT_CONFIG_PATH = $(BOARD_DIR)/$(RCFG)

RP ?= 0
ROOT_PATCH_TOOL = tools/rootfs/patch.sh

root-patch:
	-$(ROOT_PATCH_TOOL) $(BOARD) $(BUILDROOT) $(ROOT_SRC) $(ROOT_OUTPUT)

ifeq ($(RP),1)
  ROOT_PATCH = root-patch
endif

root-defconfig: $(ROOT_CHECKOUT) $(ROOT_PATCH)
	$(Q)mkdir -p $(ROOT_OUTPUT)
	$(Q)[ -f "$(ROOT_CONFIG_PATH)" ] && cp $(ROOT_CONFIG_PATH) $(ROOT_SRC)/configs
	make O=$(ROOT_OUTPUT) -C $(ROOT_SRC) $(RCFG)

root-menuconfig:
	make O=$(ROOT_OUTPUT) -C $(ROOT_SRC) menuconfig

r-d: root-source
r-o: root-checkout
r-c: root-defconfig
r-m: root-menuconfig

# Build Buildroot
ROOT_INSTALL_TOOL = $(TOOL_DIR)/rootfs/install.sh

# Install kernel modules?
IKM ?= 1

ifeq ($(IKM), 1)
  ifeq ($(KERNEL_OUTPUT)/.modules.order, $(wildcard $(KERNEL_OUTPUT)/.modules.order))
    KERNEL_MODULES_INSTALL = module-install
  endif
endif

root-buildroot:
	make O=$(ROOT_OUTPUT) -C $(ROOT_SRC) -j$(HOST_CPU_THREADS)

# Install system/ to ROOTDIR
root-install:
	ROOTDIR=$(ROOTDIR) $(ROOT_INSTALL_TOOL)

prebuilt_root_dir ?= $(PBR)
ifeq ($(FS_TYPE),dir)
  prebuilt_root_dir = 1
endif

build_root_uboot ?= 0
ifeq ($(U),1)
  ifeq ($(DEV_TYPE),rd)
    build_root_uboot = 1
  endif
endif

ROOT_GENRD_TOOL = $(TOOL_DIR)/rootfs/dir2rd.sh

root-rd:
	$(Q)[ ! -f "$(IROOTFS)" ] && make $(S) root-rebuild

root-rd-rebuild: root-rebuild

root-rebuild:
ifeq ($(prebuilt_root_dir), 1)
	ROOTDIR=$(ROOTDIR) INITRD=$(IROOTFS) USER=$(USER) $(ROOT_GENRD_TOOL)
else
	make O=$(ROOT_OUTPUT) -C $(ROOT_SRC)
	$(Q)chown -R $(USER):$(USER) $(ROOT_OUTPUT)/target
	$(Q)[ $(build_root_uboot) -eq 1] && make $(S) $(BUILDROOT_UROOTFS)
endif

r-p: root-patch
r-B: root-buildroot
r-i: root-install
r-r: root-rebuild

ROOT ?= rootdir
ifeq ($(_PBR), 0)
  ifneq ($(BUILDROOT_IROOTFS),$(wildcard $(BUILDROOT_IROOTFS)))
    ROOT = root-buildroot
  endif
endif

root: $(ROOT)
	$(Q)make root-install
	$(Q)[ -n "$(KERNEL_MODULES_INSTALL)" ] && make $(KERNEL_MODULES_INSTALL)
	$(Q)make root-rebuild

root-build: root

root-prepare: root-checkout root-patch root-defconfig
root-auto: root-prepare root
root-full: root-download root-prepare root

r: root
r-b: root
r-P: root-prepare
r-a: root-auto
r-f: root-full

# Kernel modules

TOP_MODULE_DIR = $(TOP_DIR)/modules
ifneq ($(PLUGIN),)
  PLUGIN_MODULE_DIR = $(TOP_DIR)/boards/$(PLUGIN)/modules
else
  PLUGIN_MODULE_DIR = $(shell find $(TOP_DIR)/boards -type d -name "modules")
endif

EXT_MODULE_DIR = $(TOP_MODULE_DIR) $(PLUGIN_MODULE_DIR)
ALL_MODULE_DIR = $(EXT_MODULE_DIR) $(TOP_DIR)/$(KERNEL_SRC)

modules ?= $(m)
module ?= $(modules)
ifeq ($(module),all)
  module := $(shell find $(EXT_MODULE_DIR) -name "Makefile" | xargs -i dirname {} | xargs -i basename {} | tr '\n' ',')
endif

ifneq ($(M),)
  ifeq ($(M),$(wildcard $(M)))
    M_PATH ?= $(M)
  else
    MODULES ?= $(M)
  endif
endif

MODULE ?= $(MODULES)
ifeq ($(MODULE),)
  ifneq ($(module),)
    MODULE := $(shell printf $(module) | tr ',' '\n' | cut -d'_' -f1 | tr '\n' ',')
  endif
endif

# Ignore multiple modules check here
MM ?= $(shell echo $(module) | tr -c ","  " " | tr -d ' ' | wc -c)

ifeq ($(MM), 0)
 ifneq ($(module),)
  M_PATH := $(shell find $(ALL_MODULE_DIR) -name "Makefile" | xargs -i dirname {} | grep "/$(module)$$" | head -1)
  ifeq ($(M_PATH),)
    M_PATH := $(shell find $(ALL_MODULE_DIR) -name "Makefile" | xargs -i dirname {} | grep "/$(module)_" | head -1)
  endif
  ifeq ($(M_PATH),)
    M_PATH := $(shell find $(ALL_MODULE_DIR) -name "Makefile" | xargs -i dirname {} | grep "/$(module)" | head -1)
  endif

  ifeq ($(M_PATH),)
    $(error 'ERROR: No such module found: $(module), list all by: `make modules-list`')
  endif
 else
  ifneq ($(MODULE_CONFIG),)
    M_PATH ?= $(MODULE_CONFIG)
  endif
 endif
endif

kernel-modules-save:
	$(Q)echo "$(M_PATH)" > .module_config

MODULES_EN=$(shell [ -f $(KERNEL_OUTPUT)/.config ] && grep -q MODULES=y $(KERNEL_OUTPUT)/.config; echo $$?)

KM ?= M=$(M_PATH)

ifneq ($(M_PATH),)
  KERNEL_MODULES_DEPS = kernel-modules-save
endif

_kernel-modules:
	[ $(MODULES_EN) -eq 0 ] && make kernel KT=modules $(KM)

kernel-modules: $(KERNEL_MODULES_DEPS)
	make _kernel-modules KM=

kernel-modules-list:
	$(Q)find $(EXT_MODULE_DIR) -name "Makefile" | xargs -i dirname {} | xargs -i basename {} | cat -n

kernel-modules-list-full:
	$(Q)find $(EXT_MODULE_DIR) -name "Makefile" | xargs -i dirname {} | cat -n

M_I_ROOT ?= rootdir
ifeq ($(PBR), 0)
  ifneq ($(BUILDROOT_IROOTFS),$(wildcard $(BUILDROOT_IROOTFS)))
    M_I_ROOT = root-buildroot
  endif
endif

_kernel-modules-install:
	[ $(MODULES_EN) -eq 0 ] && make kernel KT=modules_install INSTALL_MOD_PATH=$(ROOTDIR) $(KM)

kernel-modules-install: $(M_I_ROOT)
	make _kernel-modules-install KM=

KERNEL_MODULE_CLEAN = tools/module/clean.sh
kernel-modules-clean:
	$(Q)$(KERNEL_MODULE_CLEAN) $(KERNEL_OUTPUT) $M
	$(Q)rm -rf .module_config

module: _kernel-modules plugin-save
module-list: kernel-modules-list plugin-save
module-list-full: kernel-modules-list-full plugin-save
module-install: _kernel-modules-install
module-clean: kernel-modules-clean

modules-list: module-list
modules-list-full: module-list-full
ms-l: module-list
ms-l-f: modules-list-full

module-test: test
modules-test: module-test

modules: FORCE
	$(Q)$(if $(module), $(foreach m, $(shell echo $(module) | tr ',' ' '), \
		echo "\nBuilding module: $(m) ...\n" && make module m=$(m);) echo '')

modules-install: FORCE
	$(Q)$(if $(module), $(foreach m, $(shell echo $(module) | tr ',' ' '), \
		echo "\nInstalling module: $(m) ...\n" && make module-install m=$(m);) echo '')

modules-clean: FORCE
	$(Q)$(if $(module), $(foreach m, $(shell echo $(module) | tr ',' ' '), \
		echo "\nCleaning module: $(m) ...\n" && make module-clean m=$(m);) echo '')

m: module
m-l: module-list
m-l-f: module-list-full
m-i: module-install
m-c: module-clean
m-t: module-test

ms: modules
ms-t: modules-test
ms-i: modules-install
ms-c: modules-clean

# Linux Kernel targets

# Configure Kernel
kernel-checkout:
	cd $(KERNEL_SRC) && git checkout -f $(LINUX) && git clean -fdx && cd $(TOP_DIR)

KCO ?= 0
LINUX ?= master
ifeq ($(KCO),1)
  KERNEL_CHECKOUT = kernel-checkout
endif

KERNEL_PATCH_TOOL = tools/kernel/patch.sh

KP ?= 0
kernel-patch:
	-$(KERNEL_PATCH_TOOL) $(BOARD) $(LINUX) $(KERNEL_SRC) $(KERNEL_OUTPUT)

ifeq ($(KP),1)
  KERNEL_PATCH = kernel-patch
endif

KERNEL_CONFIG_FILE ?= linux_$(LINUX)_defconfig

KCFG ?= $(KERNEL_CONFIG_FILE)
KERNEL_CONFIG_PATH = $(BOARD_DIR)/$(KCFG)
KERNEL_CONFIG_PATH_TMP = $(KERNEL_SRC)/arch/$(ARCH)/configs/$(KCFG)

kernel-defconfig:  $(KERNEL_CHECKOUT) $(KERNEL_PATCH)
	$(Q)mkdir -p $(KERNEL_OUTPUT)
	$(Q)[ -f "$(KERNEL_CONFIG_PATH)" ] && cp $(KERNEL_CONFIG_PATH) $(KERNEL_CONFIG_PATH_TMP)
	make O=$(KERNEL_OUTPUT) -C $(KERNEL_SRC) ARCH=$(ARCH) $(KCFG)

kernel-oldconfig:
	make O=$(KERNEL_OUTPUT) -C $(KERNEL_SRC) ARCH=$(ARCH) oldconfig
	@#make O=$(KERNEL_OUTPUT) -C $(KERNEL_SRC) ARCH=$(ARCH) silentoldconfig

kernel-menuconfig:
	make O=$(KERNEL_OUTPUT) -C $(KERNEL_SRC) ARCH=$(ARCH) menuconfig

# Build Kernel

KERNEL_FEATURE_TOOL = tools/kernel/feature.sh

kernel-feature:
	$(Q)$(KERNEL_FEATURE_TOOL) $(BOARD) $(LINUX) $(TOP_DIR)/$(KERNEL_SRC) $(KERNEL_OUTPUT) "$(FEATURE)"

feature: kernel-feature
features: feature
kernel-features: feature
k-f: feature
f: feature

kernel-feature-list:
	$(Q)echo [ $(FEATURE_DIR) ]:
	$(Q)find $(FEATURE_DIR) -mindepth 1 | egrep -v "config|patch|version" | sed -e "s%$(FEATURE_DIR)/%%g" | sort | sed -e "s%\(^[^/]*$$\)%  + \1%g" | sed -e "s%[^/]*/.*/%      * %g" | sed -e "s%[^/]*/%    - %g"

kernel-features-list: kernel-feature-list
features-list: kernel-feature-list
feature-list: kernel-feature-list
k-f-l: feature-list
f-l: k-f-l

ifneq ($(module),)
  ifneq ($(FEATURE),)
    FEATURE += module
  else
    FEATURE := module
  endif
endif

# Testing targets

TEST ?= $T
TEST_PREPARE := $(shell echo $(TEST) | tr ',' ' ')

# Force running git submodule commands
GIT_FORCE = $(if $(TEST),--force,)

kernel-init:
	$(Q)make kernel-oldconfig
	$(Q)make kernel

rootdir-init:
	$(Q)make rootdir-clean
	$(Q)make rootdir
	$(Q)make root-install

module-init:
	make kernel-modules
	make kernel-modules-install
	make modules
	make modules-install

feature-init: FORCE
ifneq ($(FEATURE),)
	make feature FEATURE="$(FEATURE)"
	make kernel-init
	make rootdir-init
	echo "$(FEATURE)" | grep -q module && make module-init
	[ "$(TEST_RD)" != "/dev/nfs" ] && make root-rebuild
endif

kernel-feature-test: test
kernel-features-test: kernel-feature-test
features-test: kernel-feature-test
feature-test: kernel-feature-test
k-f-t: feature-test
f-t: k-f-t

IMAGE = $(shell basename $(ORIIMG))

ifeq ($(U),1)
  IMAGE=uImage
endif

# Default kernel target is kernel image
KT ?= $(IMAGE)

# Allow to accept external kernel compile options, such as XXX_CONFIG=y
KOPTS ?=

ifeq ($(findstring /dev/null,$(ROOTDEV)),/dev/null)
  ROOT_RD = root-rd
  # directory is ok, but is not compressed cpio
  KOPTS += CONFIG_INITRAMFS_SOURCE=$(IROOTFS)
endif

KMAKE_CMD  = make O=$(KERNEL_OUTPUT) -C $(KERNEL_SRC)
KMAKE_CMD += ARCH=$(ARCH) LOADADDR=$(KRN_ADDR) CROSS_COMPILE=$(CCPRE) V=$(V) $(KOPTS)
KMAKE_CMD += -j$(HOST_CPU_THREADS) $(KT)

# Update bootargs in dts if exists, some boards not support -append
ifneq ($(DTS),)
  ifeq ($(DTS),$(wildcard $(DTS)))

dtb: $(DTS)
	$(Q)sed -i -e "s%.*bootargs.*=.*;%\t\tbootargs = \"$(CMDLINE)\";%g" $(DTS)
	$(Q)make kernel KT=$(DTB_TARGET)

# Pass kernel command line in dts, require to build dts for every boot
KCLI_DTS ?= 0
ifeq ($(KCLI_DTS),1)
  BOOT_DTB = dtb
endif
KERNEL_DTB = dtb
  endif
endif

# Ignore DTB and RD dependency if KT specified
ifeq ($(KT),)
  KERNEL_DEPS = $(KERNEL_DTB) $(ROOT_RD)
endif

kernel: $(KERNEL_DEPS)
	$(C_PATH) $(KMAKE_CMD)

kernel-build: kernel

k-d: kernel-source
k-o: kernel-checkout
k-p: kernel-patch
k-c: kernel-defconfig
k-o-c: kernel-oldconfig
k-m: kernel-menuconfig
k-b: kernel
k: kernel

kernel-prepare: gcc kernel-checkout kernel-patch kernel-defconfig
kernel-auto: kernel-prepare kernel
kernel-full: kernel-download kernel-prepare kernel

# Simplify testing
prepare: kernel-prepare
auto: kernel-auto
full: kernel-full

# Uboot targets

# Configure Uboot
uboot-checkout:
	cd $(UBOOT_SRC) && git checkout -f $(UBOOT) && git clean -fdx && cd $(TOP_DIR)

BCO ?= 0
UBOOT ?= master
ifeq ($(BCO),1)
  UBOOT_CHECKOUT = uboot-checkout
endif

UP ?= 0

PFLASH_BASE ?= 0
PFLASH_SIZE ?= 0
BOOTDEV ?= flash
KRN_ADDR ?= -
KRN_SIZE ?= 0
RDK_ADDR ?= -
RDK_SIZE ?= 0
DTB_ADDR ?= -
DTB_SIZE ?= 0
UCFG_DIR = u-boot/include/configs

ifeq ($(findstring sd,$(BOOTDEV)),sd)
  SD_BOOT ?= 1
endif
ifeq ($(findstring mmc,$(BOOTDEV)),mmc)
  SD_BOOT ?= 1
endif

# By default, boot from tftp
U_BOOT_CMD ?= bootcmd1
ifeq ($(SD_BOOT),1)
  U_BOOT_CMD := bootcmd2
endif
ifeq ($(findstring flash,$(BOOTDEV)),flash)
  U_BOOT_CMD := bootcmd3
endif

ifneq ($(findstring /dev/ram,$(ROOTDEV)),/dev/ram)
  RDK_ADDR = -
endif
DTB_ADDR = $(if $(DTS),,-)

ifneq ($(U),)
  export U_BOOT_CMD IP ROUTE ROOTDEV BOOTDEV ROOTDIR PFLASH_BASE KRN_ADDR KRN_SIZE RDK_ADDR RDK_SIZE DTB_ADDR DTB_SIZE
endif

UBOOT_CONFIG_TOOL = $(TOOL_DIR)/uboot/config.sh
UBOOT_PATCH_TOOL = tools/uboot/patch.sh

uboot-patch:
	[ -n "$(UCONFIG)" ] && $(UBOOT_CONFIG_TOOL) $(UCFG_DIR) $(UCONFIG)
	-$(UBOOT_PATCH_TOOL) $(BOARD) $(UBOOT) $(UBOOT_SRC) $(UBOOT_OUTPUT)

ifeq ($(UP),1)
  UBOOT_PATCH = uboot-patch
endif

UBOOT_CONFIG_FILE ?= uboot_$(UBOOT)_defconfig

UCFG ?= $(UBOOT_CONFIG_FILE)
UBOOT_CONFIG_PATH = $(BOARD_DIR)/$(UCFG)

uboot-defconfig: $(UBOOT_CHECKOUT) $(UBOOT_PATCH)
	$(Q)mkdir -p $(UBOOT_OUTPUT)
	$(Q)[ -f "$(UBOOT_CONFIG_PATH)" ] && cp $(UBOOT_CONFIG_PATH) $(UBOOT_SRC)/configs
	make O=$(UBOOT_OUTPUT) -C $(UBOOT_SRC) ARCH=$(ARCH) $(UCFG)

uboot-menuconfig:
	make O=$(UBOOT_OUTPUT) -C $(UBOOT_SRC) ARCH=$(ARCH) menuconfig

# Build Uboot
uboot:
	$(C_PATH) make O=$(UBOOT_OUTPUT) -C $(UBOOT_SRC) ARCH=$(ARCH) CROSS_COMPILE=$(CCPRE) -j$(HOST_CPU_THREADS)

uboot-build: uboot

uboot-prepare: uboot-checkout uboot-patch uboot-defconfig
uboot-auto: uboot-prepare uboot
uboot-full: uboot-download uboot-prepare uboot

u-d: uboot-source
u-o: uboot-checkout
u-p: uboot-patch
u-c: uboot-defconfig
u-m: uboot-menuconfig
u-b: uboot
u: uboot

# Checkout kernel and Rootfs
checkout: kernel-checkout root-checkout

# Config Kernel and Rootfs
config: root-defconfig kernel-defconfig

# Build Kernel and Rootfs
build: root kernel


o: checkout
c: config
B: build

# Save the built images
root-save: prebuilt-images
	$(Q)mkdir -p $(PREBUILT_ROOT_DIR)
	-cp $(BUILDROOT_IROOTFS) $(PREBUILT_ROOT_DIR)

STRIP_CMD = $(C_PATH) $(CCPRE)strip -s

kernel-save: prebuilt-images
	$(Q)mkdir -p $(PREBUILT_KERNEL_DIR)
	-cp $(LINUX_KIMAGE) $(PREBUILT_KERNEL_DIR)
	-$(STRIP_CMD) $(PREBUILT_KERNEL_DIR)/$(shell basename $(ORIIMG))
	-[ -n "$(UORIIMG)" -a -f "$(LINUX_UKIMAGE)" ] && cp $(LINUX_UKIMAGE) $(PREBUILT_KERNEL_DIR)
	-[ -n "$(DTS)" -a -f "$(LINUX_DTB)" ] && cp $(LINUX_DTB) $(PREBUILT_KERNEL_DIR)

uboot-save: prebuilt-images
	$(Q)mkdir -p $(PREBUILT_UBOOT_DIR)
	-cp $(UBOOT_BIMAGE) $(PREBUILT_UBOOT_DIR)


emulator-save: prebuilt-images
	$(Q)mkdir -p $(PREBUILT_QEMU_DIR)
	$(Q)make -C $(QEMU_OUTPUT)/$(QEMU_TARGET) install V=$(V)
	$(Q)make -C $(QEMU_OUTPUT) install V=$(V)

qemu-save: emulator-save

r-s: root-save
k-s: kernel-save
u-s: uboot-save
q-s: qemu-save

uboot-saveconfig: uconfig-save

uconfig-save:
	-$(C_PATH) make O=$(UBOOT_OUTPUT) -C $(UBOOT_SRC) ARCH=$(ARCH) savedefconfig
	$(Q)if [ -f $(UBOOT_OUTPUT)/defconfig ]; \
	then cp $(UBOOT_OUTPUT)/defconfig $(BOARD_DIR)/uboot_$(UBOOT)_defconfig; \
	else cp $(UBOOT_OUTPUT)/.config $(BOARD_DIR)/uboot_$(UBOOT)_defconfig; fi

# kernel < 2.6.36 doesn't support: `make savedefconfig`
kernel-saveconfig: kconfig-save

kconfig-save:
	-$(C_PATH) make O=$(KERNEL_OUTPUT) -C $(KERNEL_SRC) ARCH=$(ARCH) savedefconfig
	$(Q)if [ -f $(KERNEL_OUTPUT)/defconfig ]; \
	then cp $(KERNEL_OUTPUT)/defconfig $(BOARD_DIR)/linux_$(LINUX)_defconfig; \
	else cp $(KERNEL_OUTPUT)/.config $(BOARD_DIR)/linux_$(LINUX)_defconfig; fi

root-saveconfig: rconfig-save

rconfig-save:
	make O=$(ROOT_OUTPUT) -C $(ROOT_SRC) -j$(HOST_CPU_THREADS) savedefconfig
	$(Q)if [ -f $(ROOT_OUTPUT)/defconfig ]; \
	then cp $(ROOT_OUTPUT)/defconfig $(BOARD_DIR)/buildroot_$(CPU)_defconfig; \
	else cp $(ROOT_OUTPUT)/.config $(BOARD_DIR)/buildroot_$(CPU)_defconfig; fi

r-c-s: rconfig-save
u-c-s: uconfig-save
k-c-s: kconfig-save

save: root-save kernel-save rconfig-save kconfig-save

s: save

# Qemu options and kernel command lines

# Graphic output? we prefer Serial port ;-)
G ?= 0
MACH ?= $(shell echo $(BOARD) | tr '/' '\n' | tail -1 | cut -d'_' -f1)

# Sharing with the 9p virtio protocol
SHARE ?= 0
SHARE_DIR ?= hostshare
SHARE_TAG ?= hostshare
ifneq ($(SHARE),0)
  SHARE_OPT ?= -fsdev local,path=$(SHARE_DIR),security_model=passthrough,id=fsdev0 -device virtio-9p-device,fsdev=fsdev0,mount_tag=$(SHARE_TAG)
  CMDLINE += sharetag=$(SHARE_TAG) sharedir=/$(shell basename $(SHARE_DIR))
endif

# Console configurations
SERIAL ?= ttyS0
CONSOLE?= tty0

ifeq ($(G),0)
  CMDLINE += console=$(SERIAL)
else
  CMDLINE += console=$(CONSOLE)
endif

# Some boards not support 'reboot' test, please use 'power' instead.
#
# reboot means run reboot command in Qemu guest
# power means rn poweroff command in Qemu guest and poweron it via host
#
REBOOT_TYPE ?= power
TEST_REBOOT ?= 0

# Shutdown the board if 'poweroff -h/-n' or crash
ifeq ($(REBOOT_TYPE), reboot)
  ifneq ($(TEST_REBOOT),0)
    TEST_FINISH := reboot
  endif
else
  TEST_FINISH := poweroff
endif

ifneq ($(findstring reboot,$(TEST_FINISH)),reboot)
  EXIT_ACTION ?= -no-reboot
endif

# SMP configuration
SMP ?= 1

EMULATOR_OPTS ?= -M $(MACH) -m $(MEM) $(NET) -smp $(SMP) -kernel $(KIMAGE) $(EXIT_ACTION)
EMULATOR_OPTS += $(SHARE_OPT)

# Launch Qemu, prefer our own instead of the prebuilt one
BOOT_CMD = sudo $(EMULATOR) $(EMULATOR_OPTS)
ifeq ($(U),0)
  ifeq ($(findstring /dev/ram,$(ROOTDEV)),/dev/ram)
    INITRD ?= 1
  endif

  ifneq ($(INITRD),)
    ifeq ($(INITRD),$(wildcard $(INITRD)))
      BOOT_CMD += -initrd $(INITRD)
    else
      BOOT_CMD += -initrd $(IROOTFS)
    endif
  endif

  ifneq ($(DTB),)
    ifeq ($(DTB),$(wildcard $(DTB)))
      BOOT_CMD += -dtb $(DTB)
    endif
  endif

  BOOT_CMD += -append '$(CMDLINE)'
else
  ifeq ($(SD_BOOT),1)
    BOOT_CMD += -drive if=sd,file=$(SD_IMG),format=raw
  endif

  # Load pflash for booting with uboot every time
  # pflash is at least used as the env storage
  BOOT_CMD += -pflash $(PFLASH_IMG)
endif

ifeq ($(findstring /dev/hda,$(ROOTDEV)),/dev/hda)
  BOOT_CMD += -hda $(HROOTFS)
endif

ifeq ($(findstring /dev/sda,$(ROOTDEV)),/dev/sda)
  # Ref: https://blahcat.github.io/2018/01/07/building-a-debian-stretch-qemu-image-for-aarch64/
  ifeq ($(BOARD), virt)
    BOOT_CMD += -drive if=none,file=$(HROOTFS),format=raw,id=virtio-sda -global virtio-blk-device.scsi=off -device virtio-scsi-device,id=scsi -device scsi-hd,drive=virtio-sda
  else
    BOOT_CMD += -hda $(HROOTFS)
  endif
endif

ifeq ($(findstring /dev/mmc,$(ROOTDEV)),/dev/mmc)
  BOOT_CMD += -drive if=sd,file=$(HROOTFS),format=raw
endif

ifeq ($(findstring /dev/vda,$(ROOTDEV)),/dev/vda)
  # Ref: https://wiki.debian.org/Arm64Qemu
  BOOT_CMD += -drive if=none,file=$(HROOTFS),format=raw,id=virtio-vda -device virtio-blk-device,drive=virtio-vda
endif

ifeq ($(G),0)
  BOOT_CMD += -nographic
else
  ifeq ($(G), 2)
    BOOT_CMD += -curses
  endif
endif

# Add extra emulator options
BOOT_CMD += $(XOPTS)

D ?= 0
ifeq ($(D),1)
  DEBUG = 1
endif
ifeq ($(DEBUG),1)
  BOOT_CMD += -s -S
endif

# Silence qemu warnings
ifneq ($(V), 1)
  QUIET_OPT ?= 2>/dev/null
endif
BOOT_CMD += $(QUIET_OPT)

ifneq ($(FS_TYPE),dir)
  ROOT_GENDIR_TOOL = $(TOOL_DIR)/rootfs/$(FS_TYPE)2dir.sh
endif

root-dir:
	$(Q)[ ! -d "${ROOTDIR}" ] && make root-dir-rebuild

root-dir-rebuild: rootdir

rootdir:
	ROOTDIR=$(ROOTDIR) USER=$(USER) HROOTFS=$(HROOTFS) INITRD=$(IROOTFS) $(ROOT_GENDIR_TOOL)

rootdir-install: root-install

rootdir-clean:
	-$(Q)[ "$(ROOTDIR)" = "$(PREBUILT_ROOTDIR)" ] && rm -rf $(ROOTDIR)

ifeq ($(U),1)

UROOTFS_SRC=$(IROOTFS)

$(UROOTFS): $(UROOTFS_SRC)
	$(Q)mkimage -A $(ARCH) -O linux -T ramdisk -C none -d $(UROOTFS_SRC) $@

$(UKIMAGE):
	$(Q)[ $(PBK) -eq 0 ] && make $(S) kernel KT=uImage

U_KERNEL_IMAGE = $(UKIMAGE)
U_ROOT_IMAGE   = $(shell echo $(ROOTDEV) | grep -q /dev/ram && echo $(UROOTFS))
U_DTB_IMAGE    = $(shell [ -f "$(DTB)" ] && echo $(DTB))

export CMDLINE PFLASH_IMG PFLASH_SIZE PFLASH_BS SD_IMG U_ROOT_IMAGE RDK_SIZE U_DTB_IMAGE DTB_SIZE U_KERNEL_IMAGE KRN_SIZE TFTPBOOT BIMAGE ROUTE BOOTDEV

UBOOT_TFTP_TOOL=$(TOOL_DIR)/uboot/tftp.sh
UBOOT_SD_TOOL=$(TOOL_DIR)/uboot/sd.sh
UBOOT_PFLASH_TOOL=$(TOOL_DIR)/uboot/pflash.sh
UBOOT_ENV_TOOL=$(TOOL_DIR)/uboot/env.sh

ifeq ($(BOOTDEV),tftp)
tftp-images: $(U_ROOT_IMAGE) $(U_DTB_IMAGE) $(U_KERNEL_IMAGE)
	$(Q)$(UBOOT_TFTP_TOOL)

TFTP_IMAGES = tftp-images
endif

# require by env saving, whenever boot from pflash
ifeq ($(PFLASH_IMG),)
  PFLASH_IMG = $(TFTPBOOT)/pflash.img
endif
ifeq ($(findstring flash,$(BOOTDEV)),flash)
pflash-images: $(U_ROOT_IMAGE) $(U_DTB_IMAGE) $(U_KERNEL_IMAGE)
	$(Q)$(UBOOT_PFLASH_TOOL)

PFLASH_IMAGES = pflash-images
endif

ifeq ($(SD_BOOT),1)
ifeq ($(SD_IMG),)
sd-images: $(U_ROOT_IMAGE) $(U_DTB_IMAGE) $(U_KERNEL_IMAGE)
	$(Q)$(UBOOT_SD_TOOL)

SD_IMAGES = sd-images
SD_IMG    = $(TFTPBOOT)/sd.img
endif
endif

ENV_IMG ?= ${TFTPBOOT}/env.img
export ENV_IMG

uboot-images: $(TFTP_IMAGES) $(PFLASH_IMAGES) $(SD_IMAGES)
	$(Q)$(UBOOT_CONFIG_TOOL)
	$(Q)$(UBOOT_ENV_TOOL)

uboot-images-clean:
	$(Q)rm -rf $(PFLASH_IMG) $(SD_IMG)

UBOOT_IMGS = uboot-images
UBOOT_IMGS_CLEAN = uboot-images-clean
endif

ROOT_GENHD_TOOL = $(TOOL_DIR)/rootfs/$(FS_TYPE)2hd.sh

root-hd:
	$(Q)[ ! -f $(HROOTFS) ] && make root-hd-rebuild

root-hd-rebuild:
	ROOTDIR=$(ROOTDIR) FSTYPE=$(FSTYPE) HROOTFS=$(HROOTFS) INITRD=$(IROOTFS) $(ROOT_GENHD_TOOL)

ifneq ($(PREBUILT_ROOT),$(wildcard $(PREBUILT_ROOT)))
  PREBUILT_IMAGES = prebuilt-images
endif

# ROOTDEV=/dev/nfs for file sharing between guest and host
# SHARE=1 is another method, but only work on some boards

SYSTEM_TOOL_DIR=system/tools

boot-init: FORCE
	$(Q)$(if $(FEATURE),$(foreach f, $(shell echo $(FEATURE) | tr ',' ' '), \
		[ -x $(SYSTEM_TOOL_DIR)/$f/test_host_before.sh ] && \
		$(SYSTEM_TOOL_DIR)/$f/test_host_before.sh $(ROOTDIR);) echo '')

boot-finish: FORCE
	$(Q)$(if $(FEATURE),$(foreach f, $(shell echo $(FEATURE) | tr ',' ' '), \
		[ -x $(SYSTEM_TOOL_DIR)/$f/test_host_after.sh ] && \
		$(SYSTEM_TOOL_DIR)/$f/test_host_after.sh $(ROOTDIR);) echo '')

# Test support
ifneq ($(TEST),)
  TEST_KCLI =
  ifneq ($(FEATURE),)
    TEST_KCLI  = feature=$(shell echo $(FEATURE) | tr ' ' ',' | sed -e "s%,$$%%g" | sed -e "s%^,%%g")
    ifeq ($(findstring module,$(FEATURE)),module)
      TEST_KCLI += module=$(shell echo $(MODULE) | tr ' ' ',' | sed -e "s%,$$%%g" | sed -e "s%^,%%g")
    endif
  endif
  ifeq ($(REBOOT_TYPE), reboot)
    ifneq ($(TEST_REBOOT),0)
      TEST_KCLI += reboot=$(TEST_REBOOT)
    endif
  endif
  ifneq ($(TEST_BEGIN),)
    TEST_KCLI += test_begin=$(TEST_BEGIN)
  endif
  ifneq ($(TEST_END),)
    TEST_KCLI += test_end=$(TEST_END)
  endif
  ifneq ($(TEST_FINISH),)
    TEST_KCLI += test_finish=$(TEST_FINISH)
  endif

  TEST_CASE ?= $(TEST_CASES)
  ifneq ($(TEST_CASE),)
    TEST_KCLI += test_case=$(TEST_CASE)
  endif

  CMDLINE += $(TEST_KCLI)
endif

BOOT_TEST=default
ifneq ($(TEST_REBOOT), 0)
  ifeq ($(findstring power,$(REBOOT_TYPE)),power)
    BOOT_TEST=loop
  endif
endif

# By default, seconds
TTO ?= 0
TEST_TIMEOUT ?= $(TTO)

ifneq ($(TEST_TIMEOUT),0)
  TEST_LOGGING?= $(TOP_DIR)/logging/$(ARCH)-$(BOARD)-linux-$(LINUX)/$(shell date +"%Y%m%d-%H%M%S")
  TEST_ENV    ?= $(TEST_LOGGING)/boot.env
  TEST_LOG    ?= $(TEST_LOGGING)/boot.log
  TEST_LOG_PIPE?= $(TEST_LOGGING)/boot.log.pipe
  TEST_LOG_PID?= $(TEST_LOGGING)/boot.log.pid
  TEST_LOG_READER ?= tools/qemu/reader.sh
  TEST_RET    ?= $(TEST_LOGGING)/boot.ret

  # Ref: /labs/linux-lab/logging/arm64-virt-linux-v5.1/20190520-145101/boot.lo
ifeq ($(findstring serial,$(XOPTS)),serial)
    XOPTS     := $(shell echo "$(XOPTS) " | sed -e "s%-serial [^ ]* %-serial mon:pipe:$(TEST_LOG_PIPE) %g")
else
    XOPTS     += -serial mon:pipe:$(TEST_LOG_PIPE)
endif

  TEST_BEFORE ?= mkdir -p $(TEST_LOGGING) && mkfifo $(TEST_LOG_PIPE) && touch $(TEST_LOG_PID) && make env > $(TEST_ENV) \
	&& $(TEST_LOG_READER) $(TEST_LOG_PIPE) $(TEST_LOG) $(TEST_LOG_PID) 2>&1 \
	&& sudo timeout $(TEST_TIMEOUT)
  TEST_AFTER  ?= ; echo \$$\$$? > $(TEST_RET); kill -9 \$$\$$(cat $(TEST_LOG_PID)); \
	ret=\$$\$$(cat $(TEST_RET)) && [ \$$\$$ret -ne 0 ] && echo \"ERR: Boot timeout in $(TEST_TIMEOUT).\" && exit \$$\$$ret; \
	echo \"LOG: Boot run successfully.\"
  # If not support netowrk, should use the other root device
endif

TEST_XOPTS ?= $(XOPTS)
TEST_RD ?= /dev/nfs

export BOARD TEST_TIMEOUT TEST_LOGGING TEST_LOG TEST_LOG_PIPE TEST_LOG_PID TEST_XOPTS TEST_RET TEST_RD TEST_LOG_READER V

boot-test:
ifeq ($(BOOT_TEST), default)
	$(T_BEFORE) make boot b=$(BOARD) XOPTS="$(TEST_XOPTS)" V=$(V) TEST=default ROOTDEV=$(TEST_RD) FEATURE=$(if $(FEATURE),$(shell echo $(FEATURE),))boot $(T_AFTRE)
else
	$(Q)$(foreach r,$(shell seq 0 $(TEST_REBOOT)), \
		echo "\nRebooting test: $r\n" && \
		$(T_BEFORE) make boot b=$(BOARD)  XOPTS="$(TEST_XOPTS)" V=$(V) TEST=default ROOTDEV=$(TEST_RD) FEATURE=$(if $(FEATURE),$(shell echo $(FEATURE),))boot $(T_AFTRE);)
endif

test: $(TEST_PREPARE) FORCE
	$(if $(FEATURE), make feature-init)
	make boot-init
	make boot-test T_BEFORE="$(TEST_BEFORE)" T_AFTRE="$(TEST_AFTER)"
	make boot-finish

# Boot dependencies

_BOOT_DEPS ?=
_BOOT_DEPS += root-$(DEV_TYPE)
_BOOT_DEPS += $(UBOOT_IMGS)

BOOT_DEPS ?=
BOOT_DEPS += $(PREBUILT_IMAGES)
BOOT_DEPS += $(BOOT_DTB)

_boot: $(_BOOT_DEPS)
	$(BOOT_CMD)

boot: $(BOOT_DEPS)
	$(Q)make $(S) _boot

t: test
b: boot

# Debug
# Xterm: lxterminal, terminator
XTERM ?= $(shell echo `tools/xterm.sh lxterminal`)
VMLINUX ?= $(KERNEL_OUTPUT)/vmlinux
GDB_CMD ?= $(C_PATH) $(CCPRE)gdb --quiet $(VMLINUX)
XTERM_CMD ?= $(XTERM) --working-directory=$(CURDIR) -T "$(GDB_CMD)" -e "$(GDB_CMD)"
XTERM_STATUS = $(shell $(XTERM) --help >/dev/null 2>&1; echo $$?)
ifeq ($(XTERM_STATUS), 0)
  DEBUG_CMD = $(XTERM_CMD)
else
  DEBUG_CMD = $(Q)echo "\nLOG: Please run this in another terminal:\n\n    " $(GDB_CMD) "\n"
endif

debug:
ifeq ($(VMLINUX),$(wildcard $(VMLINUX)))
	$(Q)echo "add-auto-load-safe-path .gdbinit" > $(HOME)/.gdbinit
	$(Q)$(DEBUG_CMD) &
	$(Q)make boot DEBUG=1
else
	$(Q)echo "ERROR: No $(VMLINUX) found, please compile with 'make kernel'"
endif

# Allinone
all: config build boot

# Clean up

emulator-clean:
ifeq ($(QEMU_OUTPUT)/Makefile, $(wildcard $(QEMU_OUTPUT)/Makefile))
	-$(Q)make $(S) -C $(QEMU_OUTPUT) clean
ifeq ($(QEMU_US), 1)
	-$(Q)make $(S) -C $(QEMU_OUTPUT)/$(XARCH)-linux-user clean
else
	-$(Q)make $(S) -C $(QEMU_OUTPUT)/$(XARCH)-softmmu clean
endif
endif

root-clean:
ifeq ($(ROOT_OUTPUT)/Makefile, $(wildcard $(ROOT_OUTPUT)/Makefile))
	-$(Q)make $(S) O=$(ROOT_OUTPUT) -C $(ROOT_SRC) clean
endif

uboot-clean: $(UBOOT_IMGS_CLEAN)
ifeq ($(UBOOT_OUTPUT)/Makefile, $(wildcard $(UBOOT_OUTPUT)/Makefile))
	-$(Q)make $(S) O=$(UBOOT_OUTPUT) -C $(UBOOT_SRC) clean
endif

kernel-clean: kernel-modules-clean
ifeq ($(KERNEL_OUTPUT)/Makefile, $(wildcard $(KERNEL_OUTPUT)/Makefile))
	-$(Q)make $(S) O=$(KERNEL_OUTPUT) -C $(KERNEL_SRC) clean
endif

clean: emulator-clean root-clean kernel-clean rootdir-clean uboot-clean

emulator-distclean:
ifeq ($(QEMU_OUTPUT)/Makefile, $(wildcard $(QEMU_OUTPUT)/Makefile))
	-$(Q)make $(S) -C $(QEMU_OUTPUT) distclean
	$(Q)rm -rf $(QEMU_OUTPUT)
endif

root-distclean:
ifeq ($(ROOT_OUTPUT)/Makefile, $(wildcard $(ROOT_OUTPUT)/Makefile))
	-$(Q)make $(S) O=$(ROOT_OUTPUT) -C $(ROOT_SRC) distclean
	$(Q)rm -rf $(ROOT_OUTPUT)
endif

uboot-distclean:
ifeq ($(UBOOT_OUTPUT)/Makefile, $(wildcard $(UBOOT_OUTPUT)/Makefile))
	-$(Q)make $(S) O=$(UBOOT_OUTPUT) -C $(UBOOT_SRC) distclean
	$(Q)rm -rf $(UBOOT_OUTPUT)
endif

kernel-distclean:
ifeq ($(KERNEL_OUTPUT)/Makefile, $(wildcard $(KERNEL_OUTPUT)/Makefile))
	-$(Q)make $(S) O=$(KERNEL_OUTPUT) -C $(KERNEL_SRC) distclean
	$(Q)rm -rf $(KERNEL_OUTPUT)
endif

rootdir-distclean: rootdir-clean

c-e: emulator-clean
c-r: root-clean
c-u: uboot-clean
c-k: kernel-clean
c: clean

dc-e: emulator-distclean
dc-r: root-distclean
dc-u: uboot-distclean
dc-k: kernel-distclean
dc: distclean

distclean: emulator-distclean root-distclean kernel-distclean rootdir-distclean uboot-distclean \
	toolchain-clean plugin-clean board-clean

fullclean: distclean
	$(Q)git clean -fdx

GCC_SWITCH_TOOL = tools/gcc/switch.sh
gcc:
ifneq ($(GCC),)
	$(Q)$(GCC_SWITCH_TOOL) $(ARCH) $(GCC)
endif

g: gcc

# Show the variables
VARS = $(shell cat boards/$(BOARD)/Makefile | grep -v "^ *\#" | cut -d'?' -f1 | cut -d'=' -f1 | tr -d ' ')
VARS += BOARD FEATURE TFTPBOOT
VARS += ROOTDIR ROOT_SRC ROOT_OUTPUT ROOT_GIT
VARS += KERNEL_SRC KERNEL_OUTPUT KERNEL_GIT UBOOT_SRC UBOOT_OUTPUT UBOOT_GIT
VARS += ROOT_CONFIG_PATH KERNEL_CONFIG_PATH UBOOT_CONFIG_PATH
VARS += IP ROUTE BOOT_CMD
VARS += LINUX_DTB QEMU_PATH QEMU_SYSTEM
VARS += TEST_TIMEOUT TEST_RD

env:
	@echo \#[ $(BOARD) ]:
	@echo -n " "
	-@echo $(foreach v,$(VARS),"    $(v)=\"$($(v))\"\n") | tr -s '/'

ENV_SAVE_TOOL = $(TOOL_DIR)/save-env.sh

env-save:
	$(Q)$(ENV_SAVE_TOOL) $(BOARD_DIR)/Makefile "$(VARS)"

help:
	$(Q)cat README.md

h: help

FORCE:

.PHONY: modules qemu FORCE

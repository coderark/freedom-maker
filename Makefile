#! /usr/bin/make

# armel amd64 i386
ARCHITECTURE = armel
# dreamplug guruplug virtualbox
MACHINE = dreamplug
# card usb hdd
DESTINATION = card
BUILD = $(MACHINE)-$(ARCHITECTURE)-$(DESTINATION)
STAMP = build/stamp
TODAY := `date +%Y-%m-%d`
NAME = build/freedombox-unstable_$(TODAY)_$(BUILD)
WEEKLY_DIR = torrent/freedombox-unstable_$(TODAY)
IMAGE = $(NAME).img
ARCHIVE = $(NAME).tar.bz2
SIGNATURE = $(ARCHIVE).sig

image: dreamplug-image

# build DreamPlug USB or SD card image
dreamplug-image: $(STAMP)-dreamplug-predepend
	$(eval TEMP_ARCHITECTURE = $(ARCHITECTURE))
	$(eval TEMP_MACHINE = $(MACHINE))
	$(eval TEMP_DESTINATION = $(DESTINATION))
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = dreamplug)
	$(eval DESTINATION = card)
	ARCHITECTURE=$(ARCHITECTURE) MACHINE=$(MACHINE) DESTINATION=$(DESTINATION) \
	  bin/mk_freedombox_image $(NAME)
	tar -cjvf $(ARCHIVE) $(IMAGE)
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
	$(eval ARCHITECTURE = $(TEMP_ARCHITECTURE))
	$(eval MACHINE = $(TEMP_MACHINE))
	$(eval DESTINATION = $(TEMP_DESTINATION))
	@echo "Build complete."

# build Raspberry Pi SD card image
raspberry-image: $(STAMP)-raspberry-predepend
	$(eval TEMP_ARCHITECTURE = $(ARCHITECTURE))
	$(eval TEMP_MACHINE = $(MACHINE))
	$(eval TEMP_DESTINATION = $(DESTINATION))
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = raspberry)
	$(eval DESTINATION = card)
	ARCHITECTURE=$(ARCHITECTURE) MACHINE=$(MACHINE) DESTINATION=$(DESTINATION) \
	  bin/mk_freedombox_image $(NAME)
	tar -cjvf $(ARCHIVE) $(IMAGE)
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
	$(eval ARCHITECTURE = $(TEMP_ARCHITECTURE))
	$(eval MACHINE = $(TEMP_MACHINE))
	$(eval DESTINATION = $(TEMP_DESTINATION))
	@echo "Build complete."

# build a virtualbox image
virtualbox-image: $(STAMP)-vbox-predepend
	$(eval TEMP_ARCHITECTURE = $(ARCHITECTURE))
	$(eval TEMP_MACHINE = $(MACHINE))
	$(eval TEMP_DESTINATION = $(DESTINATION))
	$(eval ARCHITECTURE = i386)
	$(eval MACHINE = virtualbox)
	$(eval DESTINATION = hdd)
	ARCHITECTURE=$(ARCHITECTURE) MACHINE=$(MACHINE) DESTINATION=$(DESTINATION) \
	  bin/mk_freedombox_image $(NAME)
# Convert image to vdi hard drive
	VBoxManage convertdd $(NAME).img $(NAME).vdi
	tar -cjvf $(ARCHIVE) $(NAME).vdi
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
	$(eval ARCHITECTURE = $(TEMP_ARCHITECTURE))
	$(eval MACHINE = $(TEMP_MACHINE))
	$(eval DESTINATION = $(TEMP_DESTINATION))
	@echo "Build complete."

prep:	
	mkdir -p build

#
# meta
#

# install required files so users don't need to do it themselves.
$(STAMP)-predepend: prep
	sudo sh -c "apt-get install git mercurial python-docutils mktorrent"
	touch $@

$(STAMP)-vmdebootstrap-predepend: $(STAMP)-predepend
	sudo sh -c "apt-get -y install debootstrap qemu-utils parted mbr kpartx python-cliapp"
	touch $@

$(STAMP)-vbox-predepend: $(STAMP)-vmdebootstrap-predepend
	sudo sh -c "apt-get -y install extlinux virtualbox"
	touch $@

$(STAMP)-raspberry-predepend: $(STAMP)-vmdebootstrap-predepend
	sudo sh -c "apt-get -y install qemu-user-static binfmt-support"
	touch $@

$(STAMP)-dreamplug-predepend: $(STAMP)-vmdebootstrap-predepend
	sudo sh -c "apt-get -y install qemu-user-static binfmt-support u-boot-tools"
	touch $@

clean:
	-rm -f $(IMAGE) $(ARCHIVE) $(STAMP)-*
	-rm -f rootfs-* source/etc/fstab

distclean: clean
	sudo rm -rf build

weekly-image: dreamplug-image raspberry-image virtualbox-image
	mkdir -p $(WEEKLY_DIR)
	mv build/*bz2 build/*sig $(WEEKLY_DIR)
	cp weekly_template.org $(WEEKLY_DIR)/README.org
	echo "http://betweennowhere.net/freedombox-images/$(WEEKLY_DIR)" > torrent/webseed
	@echo ""
	@echo "----------"
	@echo "When the README has been updated, hit Enter."
	read X
	mktorrent -a `cat torrent/trackers` -w `cat torrent/webseed` $(WEEKLY_DIR)
	mv $(WEEKLY_DIR).torrent torrent/

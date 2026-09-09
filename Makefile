ASSEMBLY_ID := urn:adsk.wipprod:dm.lineage:m1GM3AuVSsGAUndgrxP6jw
RENDER_QUALITY := ShadedWithVisibleEdgesOnly

# Run make from Git Bash on Windows (or a POSIX shell on macOS/Linux).
SHELL := sh
.SHELLFLAGS := -ec
ifeq ($(OS),Windows_NT)
PYTHON ?= py -3
BUILD_PYTHON := .venv/Scripts/python.exe
else
PYTHON ?= python3
BUILD_PYTHON := .venv/bin/python
endif
BUILD_READY := .venv/.yammu-requirements-installed
CLI_DIR := FusionAddons/FusionHeadless/cli
FUSION_CLI := $(BUILD_PYTHON) $(CLI_DIR)/fusion_cli.py
STL_EXPORTER := tools/export_stl.py

.PHONY: all images setup clean STLs check update_assembly FORCE test
all: \
	STLs \
	CAD/Assembly.zip \
	Manual/Assembly.pdf

images: \
	Images/render_1.png \
	Images/render_ebay.png \
	Images/render_heater.png \
	Images/render_feeder.png \
	Images/render_splitter.png \
	Images/latch_lock.png \
	Images/render_cw2.png


 ######  ######## ######## ##     ## ########
##    ## ##          ##    ##     ## ##     ##
##       ##          ##    ##     ## ##     ##
 ######  ######      ##    ##     ## ########
      ## ##          ##    ##     ## ##
##    ## ##          ##    ##     ## ##
 ######  ########    ##     #######  ##

setup: $(BUILD_READY)

$(BUILD_PYTHON):
	$(PYTHON) -m venv .venv

$(BUILD_READY): requirements.txt $(CLI_DIR)/requirements.txt $(BUILD_PYTHON)
	$(BUILD_PYTHON) -m pip install -r requirements.txt
	touch $@

# Refresh metadata on each build. The CLI preserves the timestamp when unchanged.
FORCE:

obj/Assembly.json: FORCE | setup
	mkdir -p $(dir $@) && \
	$(FUSION_CLI) document --data '{"open": "'"$(ASSEMBLY_ID)"'"}' && \
	$(FUSION_CLI) files --data '{"id": "'"$(ASSEMBLY_ID)"'"}' --output $@

update_assembly: obj/Assembly.json

test: setup
	$(BUILD_PYTHON) -m unittest discover -s tools/tests



 ######  ######## ##        ######
##    ##    ##    ##       ##    ##
##          ##    ##       ##
 ######     ##    ##        ######
      ##    ##    ##             ##
##    ##    ##    ##       ##    ##
 ######     ##    ########  ######

# Read live bodies too, including unsaved changes and current component IDs.
obj/components.json: obj/Assembly.json FORCE
	$(FUSION_CLI) document --data '{"open": "'"$(ASSEMBLY_ID)"'"}' && \
	$(FUSION_CLI) components --details --timeout 120 --output $@

STL_FILES = $(shell find STLs -type f -iname '*.stl' -print | sort)
STL_TARGETS = $(shell sed -n 's|^\(STLs/[^:]*\.stl\):.*|\1|p' Makefile | sort -u)
UNRULED_STLS = $(filter-out $(STL_TARGETS),$(STL_FILES))

define FUSION_STL
$(BUILD_PYTHON) $(STL_EXPORTER) --components obj/components.json --target "$@" \
	$(if $(2),--component "$(1)" --body "$(2)" $(if $(3),--body "$(3)"),--body "$(1)") \
	$(if $(STL_CHECK_ONLY),--check-only)
endef

check:
	@status=0; \
	$(foreach file,$(UNRULED_STLS),printf '\033[31mcheck: STL has no Makefile rule: %s\033[0m\n' '$(file)'; status=1;) \
	$(MAKE) --no-print-directory -k -B STL_CHECK_ONLY=1 $(STL_TARGETS) || status=1; \
	exit $$status

STLs: check
	$(MAKE) --no-print-directory $(STL_TARGETS)

# Each STL is a literal target. FUSION_STL takes either a unique body name, or
# a component name followed by one or two body names when qualification/grouping
# is required.
# STL_TARGET_RULES
STLs/BackGrill/back_grill_mount.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,[a]_back_grill_mount)

STLs/BackGrill/back_grill.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,back_grill)

STLs/BackGrill/outlet_housing.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,outlet_housing)

STLs/BackGrill/y_splitter.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,y_splitter)

STLs/ElectronicsBay/DIN_center_support_x3.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,DIN_Center_Support,Body1)

STLs/ElectronicsBay/Nut5/cable_frame_anchor_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,cable_frame_anchor,Nut5)

STLs/ElectronicsBay/Nut5/deck_support.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,deck_support,Nut5)

STLs/ElectronicsBay/Nut5/DIN_corner_frame_mount_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,din_corner_frame_mount_x4,Nut5)

STLs/ElectronicsBay/Nut5/DIN_frame_mount_x6.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,DIN_frame_mount,Nut5)

STLs/ElectronicsBay/Nut5/wago_mount.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,wago_mount,Nut5)

STLs/ElectronicsBay/Nut6/cable_frame_anchor_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,cable_frame_anchor,Nut6)

STLs/ElectronicsBay/Nut6/deck_support.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,deck_support,Nut6)

STLs/ElectronicsBay/Nut6/DIN_corner_frame_mount_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,din_corner_frame_mount_x4,Nut6)

STLs/ElectronicsBay/Nut6/DIN_frame_mount_x6.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,DIN_frame_mount,Nut6)

STLs/ElectronicsBay/Nut6/wago_mount.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,wago_mount,Nut6)

STLs/ElectronicsBay/pcb_bracket.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,pcb_bracket)

STLs/ElectronicsBay/pcb_spacer_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,pcb_spacer)

STLs/ElectronicsBay/psu_din_rail_mount_a.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,psu_din_rail_mount_a,Body 1)

STLs/ElectronicsBay/psu_din_rail_mount_b.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,psu_din_rail_mount_b,Body 1)

STLs/Feeder/[a]_latch_a_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,latch_a)

STLs/Feeder/[a]_latch_b_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,latch_b)

STLs/Feeder/[a]_latch_mirror_a_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,latch_mirror_a)

STLs/Feeder/[a]_latch_mirror_b_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,latch_mirror_b)

STLs/Feeder/end_cap_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,end_cap_x4)

STLs/Feeder/feeder_gear_housing_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,feeder_gear_housing_x4)

STLs/Feeder/latch_lock_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,latch_lock_x4)

STLs/Feeder/motor_housing_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,motor_housing_a_x2)

STLs/Feeder/motor_housing_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,motor_housing_b_x2)

STLs/Feeder/motor_housing_c_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,motor_housing_c_x2)

STLs/Frame/Nut5/blind_joint_plug_I_x20.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,Blind Joint Plug I,Nut5)

STLs/Frame/Nut5/blind_joint_plug_x22.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,Blind Joint Plug,Nut5)

STLs/Frame/Nut6/blind_joint_plug_I_x20.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,Blind Joint Plug I,Nut6)

STLs/Frame/Nut6/blind_joint_plug_x22.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,Blind Joint Plug,Nut6)

STLs/Heater_200/heater_case_lower.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,heater_case_lower)

STLs/Heater_200/heater_case_upper.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,heater_case_upper)

STLs/Panels/bottom_panel_clip_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,bottom_panel_clip,Body1)

STLs/Panels/bottom_panel_hinge_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,bottom_panel_hinge,Body1,Body2)

STLs/Panels/Double_Pane/corner_clip_10mm_x16.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,corner_clip_10mm,Body2)

STLs/Panels/Double_Pane/midspan_clip_10mm_x15.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,midspan_clip_10mm,Body2)

STLs/Panels/Front_Doors/[a]_clamp_large_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,clamp_large_a,clamp_large_a)

STLs/Panels/Front_Doors/[a]_clamp_small_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,clamp_small_a,clamp_small_a)

STLs/Panels/Front_Doors/clamp_large_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,clamp_large_b,clamp_large_b)

STLs/Panels/Front_Doors/clamp_large_c_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,clamp_large_c,clamp_large_c)

STLs/Panels/Front_Doors/clamp_small_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,clamp_small_b,clamp_small_b)

STLs/Panels/Front_Doors/clamp_small_c_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,clamp_small_c,clamp_small_c)

STLs/Panels/Front_Doors/door_hinge_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,door_hinge_a,door_hinge_a)

STLs/Panels/Front_Doors/door_hinge_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,door_hinge_b,door_hinge_b)

STLs/Panels/Single_Pane/corner_clip_6mm_x16.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,corner_clip_6mm,Body2)

STLs/Panels/Single_Pane/midspan_clip_6mm_x15.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,midspan_clip_6mm,Body2)

STLs/Skirt/[a]_corner_baseplate_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,[a]_corner_baseplate_a_x2)

STLs/Skirt/[a]_corner_baseplate_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,[a]_corner_baseplate_b_x2)

STLs/Skirt/Nut5/corner_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,corner_a_x2,Nut5)

STLs/Skirt/Nut5/corner_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,corner_b_x2,Nut5)

STLs/Skirt/Nut5/front_skirt_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,front_skirt,Nut5)

STLs/Skirt/Nut5/PSU.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,PSU,Nut5)

STLs/Skirt/Nut5/PSU2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,PSU2,Nut5)

STLs/Skirt/Nut5/side_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,side_a,Nut5)

STLs/Skirt/Nut5/side_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,side_b,Nut5)

STLs/Skirt/Nut6/corner_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,corner_a_x2,Nut6)

STLs/Skirt/Nut6/corner_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,corner_b_x2,Nut6)

STLs/Skirt/Nut6/front_skirt_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,front_skirt,Nut6)

STLs/Skirt/Nut6/PSU.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,PSU,Nut6)

STLs/Skirt/Nut6/PSU2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,PSU2,Nut6)

STLs/Skirt/Nut6/side_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,side_a,Nut6)

STLs/Skirt/Nut6/side_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,side_b,Nut6)

STLs/SpoolCarrier/drawer_front_support_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,drawer_front_support,Body1)

STLs/SpoolCarrier/middle_support_back_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,Body40)

STLs/SpoolCarrier/middle_support_back_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,Body9)

STLs/SpoolCarrier/middle_support_front_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,Body41)

STLs/SpoolCarrier/middle_support_front_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,Body4)

STLs/SpoolCarrier/Ptfe_Splitter/ptfe_sleeve_x8.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,ptfe_sleeve,Body1)

STLs/SpoolCarrier/Ptfe_Splitter/ptfe_splitter_arm_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,ptfe_splitter_arm)

STLs/SpoolCarrier/Ptfe_Splitter/ptfe_splitter_endcap_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,ptfe_splitter_endcap)

STLs/SpoolCarrier/Ptfe_Splitter/ptfe_splitter_spacer_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,ptfe_splitter_spacer,Body1)

STLs/SpoolCarrier/Ptfe_Splitter/ptfe_splitter_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,ptfe_splitter)

STLs/SpoolCarrier/Rewinder/[a]_nut_x8.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,tightening_nut)

STLs/SpoolCarrier/Rewinder/bearing_holder_x8.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,bearing_holder_x8,Body1)

STLs/SpoolCarrier/Rewinder/c-clip_x16.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,c-clip)

STLs/SpoolCarrier/Rewinder/clutch_x8.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,clutch)

STLs/SpoolCarrier/Rewinder/cover_x8.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,cover)

STLs/SpoolCarrier/Rewinder/dial_x8.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,dial)

STLs/SpoolCarrier/Rewinder/inteface_x8.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,inteface)

STLs/SpoolCarrier/Rewinder/shaft_x8.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,shaft_x8)

STLs/SpoolCarrier/Rewinder/slipping_disc_x8.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,sliping_disc)

STLs/SpoolCarrier/SlideExtension/[a]_ball_bearing_sleeve_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,ball_bearing_sleeve_x4)

STLs/SpoolCarrier/SlideExtension/ball_bearing_holder_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,ball_bearing_holder)

STLs/SpoolCarrier/SlideExtension/ball_bearing_spacer_x4.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,ball_bearing_spacer)

STLs/SpoolCarrier/SlideExtension/lower_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,lower_a_x2)

STLs/SpoolCarrier/SlideExtension/lower_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,lower_b_x2)

STLs/SpoolCarrier/SlideExtension/upper_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,upper_a_x2)

STLs/SpoolCarrier/SlideExtension/upper_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,upper_b_x2)

STLs/SpoolCarrier/support_a_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,support_a_x2)

STLs/SpoolCarrier/support_b_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,support_b_x2)

STLs/SpoolCarrier/support_c_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,support_c_x2)

STLs/SpoolCarrier/support_d_x2.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,support_d_x2)

STLs/Toolhead_Modifications/[a]_SB_CW2_Latch.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,SB_CW2_Latch)

STLs/Toolhead_Modifications/SB_CW2_Body.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,SB_CW2_Body)

STLs/Tools/5mm_shaft_cutting_guide.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,5mm Shaft Cutting Guide,Body1)

STLs/Tools/hex_driver_open.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,Hex Driver Open,Body2)

STLs/Tools/hex_driver.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,Hex Driver,Body1)

STLs/Tools/m5_rod_cutting_guide.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,M5 Rod Cutting Guide,Body1)

STLs/Tools/Nut5/drill_guide_10mm.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,drill_guide_10mm,Nut5)

STLs/Tools/Nut5/drill_guide_233mm.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,drill_guide_233mm,Nut5)

STLs/Tools/Nut6/drill_guide_10mm.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,drill_guide_10mm,Nut6)

STLs/Tools/Nut6/drill_guide_233mm.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,drill_guide_233mm,Nut6)

STLs/Tools/ptfe_cuting_guide.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,ptfe_cuting_guide)

STLs/Tools/ptfe_tread_cutter.stl: obj/components.json $(STL_EXPORTER)
	$(call FUSION_STL,ptfe_tread_cutter)




 ######     ###    ########
##    ##   ## ##   ##     ##
##        ##   ##  ##     ##
##       ##     ## ##     ##
##       ######### ##     ##
##    ## ##     ## ##     ##
 ######  ##     ## ########

obj/Assembly.step: obj/Assembly.json
	$(FUSION_CLI) document --data '{"open": "'"$(ASSEMBLY_ID)"'"}' && \
	$(FUSION_CLI) export --data '{"format": "step"}' --output $@

CAD/Assembly.zip: obj/Assembly.step
	mkdir -p $(dir $@) && \
	$(BUILD_PYTHON) -m zipfile -c $@ $<



##     ##    ###    ##    ## ##     ##    ###    ##
###   ###   ## ##   ###   ## ##     ##   ## ##   ##
#### ####  ##   ##  ####  ## ##     ##  ##   ##  ##
## ### ## ##     ## ## ## ## ##     ## ##     ## ##
##     ## ######### ##  #### ##     ## ######### ##
##     ## ##     ## ##   ### ##     ## ##     ## ##
##     ## ##     ## ##    ##  #######  ##     ## ########

Manual/Assembly.pdf: Manual/Assembly.odp
	mkdir -p $(dir $@) && \
	soffice --headless --convert-to pdf:writer_pdf_Export $< --outdir Manual/


#### ##     ##    ###     ######   ########  ######
 ##  ###   ###   ## ##   ##    ##  ##       ##    ##
 ##  #### ####  ##   ##  ##        ##       ##
 ##  ## ### ## ##     ## ##   #### ######    ######
 ##  ##     ## ######### ##    ##  ##             ##
 ##  ##     ## ##     ## ##    ##  ##       ##    ##
#### ##     ## ##     ##  ######   ########  ######

Images/render_1.png: obj/Assembly.json
	mkdir -p $(dir $@) && \
	$(FUSION_CLI) document --data '{"open": "'"$(ASSEMBLY_ID)"'"}' && \
	$(FUSION_CLI) render \
		--data '{"show": ["all"], "hide": ["Tools"], "view": "Render_1", "focalLength": 100, "quality": "$(RENDER_QUALITY)", "width": 400, "height": 400}' \
		--timeout 180 \
		--output $@ && \
	convert $@ -fuzz 10% -trim +repage $@ && \
	convert $@ -bordercolor white -border 200 $@ && \
	convert $@ -gravity center -crop 400x400+0+0 +repage $@

Images/render_ebay.png: obj/Assembly.json
	mkdir -p $(dir $@) && \
	$(FUSION_CLI) document --data '{"open": "'"$(ASSEMBLY_ID)"'"}' && \
	$(FUSION_CLI) render \
		--data '{"show": ["all"], "hide": ["Electronincs Door"], "view": "Render_ebay", "focalLength": 100, "quality": "$(RENDER_QUALITY)", "width": 400, "height": 400}' \
		--timeout 180 \
		--output $@

Images/render_heater.png: obj/Assembly.json
	mkdir -p $(dir $@) && \
	$(FUSION_CLI) document --data '{"open": "'"$(ASSEMBLY_ID)"'"}' && \
	$(FUSION_CLI) render \
		--data '{"show": ["all"], "hide": ["Drawer"], "view": "Render_heater", "focalLength": 100, "quality": "$(RENDER_QUALITY)", "width": 400, "height": 400}' \
		--timeout 180 \
		--output $@

Images/render_feeder.png: obj/Assembly.json
	mkdir -p $(dir $@) && \
	$(FUSION_CLI) document --data '{"open": "'"$(ASSEMBLY_ID)"'"}' && \
	$(FUSION_CLI) render \
		--data '{"view": "home", "isolate": ["Direct Drive x4"], "focalLength": 100, "quality": "$(RENDER_QUALITY)", "width": 400, "height": 400}' \
		--timeout 180 \
		--output $@

Images/render_splitter.png: obj/Assembly.json
	mkdir -p $(dir $@) && \
	$(FUSION_CLI) document --data '{"open": "'"$(ASSEMBLY_ID)"'"}' && \
	$(FUSION_CLI) render \
		--data '{"view": "Render_Splitter", "isolate": ["Direct Drive x4"], "quality": "$(RENDER_QUALITY)", "width": 400, "height": 400}' \
		--timeout 180 \
		--output $@

Images/latch_lock.png: obj/Assembly.json
	mkdir -p $(dir $@) && \
	$(FUSION_CLI) document --data '{"open": "'"$(ASSEMBLY_ID)"'"}' && \
	$(FUSION_CLI) render \
		--data '{"view": "MotionStudy_Latch", "isolate": ["Direct Drive x4"], "hide": ["Filament Spools", "latch_a", "latch_b", "latch_mirror_a", "latch_mirror_b"], "quality": "$(RENDER_QUALITY)", "width": 400, "height": 400}' \
		--timeout 180 \
		--output $@

Images/render_cw2.png: obj/Assembly.json
	mkdir -p $(dir $@) && \
	$(FUSION_CLI) document --data '{"open": "'"$(ASSEMBLY_ID)"'"}' && \
	$(FUSION_CLI) render \
		--data '{"view": "home", "isolate": ["Stealthburner_CW2_Filament_Sensor_ECAS"], "exposure": 8.2, "focalLength": 200, "quality": "$(RENDER_QUALITY)", "width": 400, "height": 400}' \
		--timeout 180 \
		--output $@


 ######  ##       ########    ###    ##    ##
##    ## ##       ##         ## ##   ###   ##
##       ##       ##        ##   ##  ####  ##
##       ##       ######   ##     ## ## ## ##
##       ##       ##       ######### ##  ####
##    ## ##       ##       ##     ## ##   ###
 ######  ######## ######## ##     ## ##    ##

clean:
	rm -rf obj

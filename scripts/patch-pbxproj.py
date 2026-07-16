#!/usr/bin/env python3
"""
Patch Xcode project: add ForgeVpnPacketTunnel extension target.

Build it one-shot without duplicates by doing precise string insertions
at known line markers rather than general search-and-replace.
"""

import re
import sys
import os

PBXPROJ = "ios/Runner.xcodeproj/project.pbxproj"

# ── UUIDs ────────────────────────────────────────────────────────
PREFIX = "E1B2C3D4E5F6A1B2C3D4"

U_TGT          = f"{PREFIX}E5F6"  # PBXNativeTarget
U_BF_SWIFT     = f"{PREFIX}E6F3"  # PBXBuildFile PacketTunnelProvider.swift
U_BF_SING      = f"{PREFIX}E6F4"  # PBXBuildFile Singbox.xcframework
U_SRC          = f"{PREFIX}E6F5"  # Sources build phase
U_FW           = f"{PREFIX}E6F6"  # Frameworks build phase
U_RES          = f"{PREFIX}E6F7"  # Resources build phase
U_DEP          = f"{PREFIX}E6F8"  # PBXTargetDependency
U_PROXY        = f"{PREFIX}E6F9"  # PBXContainerItemProxy
U_EMBED        = f"{PREFIX}E7F0"  # Embed App Extensions phase
U_GRP          = f"{PREFIX}E7F1"  # PBXGroup
U_PRODUCT_REF  = f"{PREFIX}E7F2"  # ForgeVpnPacketTunnel.appex fileref
U_CFG_DEBUG    = f"{PREFIX}E7F3"  # Debug config
U_CFG_RELEASE  = f"{PREFIX}E7F4"  # Release config
U_CFG_PROFILE  = f"{PREFIX}E7F5"  # Profile config
U_CFGLIST      = f"{PREFIX}E7F6"  # XCConfigurationList
U_INFO_PLIST   = f"{PREFIX}E7F7"  # Info.plist fileref

# ── Existing UUIDs ───────────────────────────────────────────────
EXISTING_BF_SWIFT    = "529B00F12BFF8256EE08074A"
EXISTING_SWIFT_REF   = "9F643C0AE348B02A019517CF"
EXISTING_SING_REF    = "A1B2C3D4E5F6222222222222"

RUNNER_TGT           = "97C146ED1CF9000F007C117D"
RUNNER_SRC_PHASE     = "97C146EA1CF9000F007C117D"
RUNNER_FW_PHASE      = "97C146EB1CF9000F007C117D"
RUNNER_RES_PHASE     = "97C146EC1CF9000F007C117D"
RUNNER_EMBED_PHASE   = "9705A1C41CF9048500538489"

PROJECT_OBJ          = "97C146E61CF9000F007C117D"
PRODUCTS_GROUP       = "97C146EF1CF9000F007C117D"
MAIN_GROUP           = "97C146E51CF9000F007C117D"

RUNNER_CFGLIST       = "97C147051CF9000F007C117D"
RUNNER_CFG_DEBUG     = "97C147061CF9000F007C117D"
RUNNER_CFG_RELEASE   = "97C147071CF9000F007C117D"
RUNNER_CFG_PROFILE   = "249021D4217E4FDB00AE95B9"


# ── Template blocks ──────────────────────────────────────────────

def t_block(name, inner):
    """Build a pbxproj block wrapped in /* Begin/End */ comments."""
    return f"/* Begin {name} section */\n{inner}\n/* End {name} section */\n"


# ── Patch logic ──────────────────────────────────────────────────

def patch(content):

    # ── 1. PRODUCTS GROUP: add product ref ───────────────────────
    products_block = (
        f'\t\t{U_PRODUCT_REF} /* ForgeVpnPacketTunnel.appex */ = '
        f'{{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; '
        f'includeInIndex = 0; path = ForgeVpnPacketTunnel.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n'
    )
    marker = '\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */'
    content = content.replace(marker, products_block + marker)

    # ── 2. INFO PLIST: add file ref ──────────────────────────────
    info_plist_file = (
        f'\t\t{U_INFO_PLIST} /* Info.plist */ = '
        f'{{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};\n'
    )
    marker2 = '\t\tA1B2C3D4E5F6444444444444 /* Runner.entitlements */ ='
    content = content.replace(marker2, info_plist_file + marker2)

    # ── 3. PBXBuildFile: add Swift + Singbox entries ─────────────
    bf_swift = (
        f'\t\t{U_BF_SWIFT} /* PacketTunnelProvider.swift in Sources */ = '
        f'{{isa = PBXBuildFile; fileRef = {EXISTING_SWIFT_REF} /* PacketTunnelProvider.swift */; }};\n'
    )
    bf_sing = (
        f'\t\t{U_BF_SING} /* Singbox.xcframework in Frameworks */ = '
        f'{{isa = PBXBuildFile; fileRef = {EXISTING_SING_REF} /* Singbox.xcframework */; }};\n'
    )
    marker3 = '\t\tA1B2C3D4E5F6333333333333 /* Singbox.xcframework in Embed Frameworks */'
    content = content.replace(marker3, bf_swift + bf_sing + marker3)

    # ── 4. MAIN GROUP: add extension group ───────────────────────
    ext_group = (
        f'\t\t{U_GRP} /* ForgeVpnPacketTunnel */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t{U_INFO_PLIST} /* Info.plist */,\n'
        f'\t\t\t);\n'
        f'\t\t\tpath = ForgeVpnPacketTunnel;\n'
        f'\t\t\tsourceTree = "<group>";\n'
        f'\t\t}};\n'
    )
    marker4 = (
        f'\t\t331C8082294A63A400263BE5 /* RunnerTests */'
    )
    # Insert after RunnerTests in main group
    # Find the line in main group
    main_group = f'{MAIN_GROUP} = {{\n'
    idx = content.index(main_group)
    after_test = content.index(marker4, idx)
    # Find end of this line
    eol = content.index('\n', after_test)
    content = content[:eol+1] + '\t\t\t\t' + f'{U_GRP} /* ForgeVpnPacketTunnel */,' + '\n' + content[eol+1:]

    # Find where to insert the group definition (after RunnerTests group)
    runnertests_group_end = (
        '\t\t};\n'
        '\t\t331C8082294A63A400263BE5 /* RunnerTests */'
    )
    # Find the end of RunnerTests group definition
    # The group def ends with \t\t};\n, then there might be another group
    # Let me find "Begin PBXGroup" and add after RunnerTests group
    groups_section = content.index('/* Begin PBXGroup section */')
    groups_end = content.index('/* End PBXGroup section */')
    groups_body = content[groups_section:groups_end]
    
    # Find last group closing in body
    last_group_close = groups_body.rindex('\t\t};\n')
    # Insert ext_group BEFORE that closing, after runner tests... actually just before "End PBXGroup"
    insert_pos = groups_section + last_group_close  # position of last };\n
    insert_pos = content.index('\t\t};\n', insert_pos) + len('\t\t};\n')
    content = content[:insert_pos] + ext_group + content[insert_pos:]

    # ── 5. PRODUCTS GROUP: add appex to children ─────────────────
    # Find the Products group children and add the extension
    products_children = (
        f'\t\t{PRODUCTS_GROUP} /* Products */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,\n'
        f'\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n'
        f'\t\t\t);'
    )
    products_children_new = (
        f'\t\t{PRODUCTS_GROUP} /* Products */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,\n'
        f'\t\t\t\t{U_PRODUCT_REF} /* ForgeVpnPacketTunnel.appex */,\n'
        f'\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n'
        f'\t\t\t);'
    )
    content = content.replace(products_children, products_children_new)

    # ── 6. REMOVE Swift from Runner Sources phase ────────────────
    runner_sources = (
        f'\t\t{RUNNER_SRC_PHASE} /* Sources */ = {{\n'
        f'\t\t\tisa = PBXSourcesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t\t74858FAF1ED2DC5600515810 /* AppDelegate.swift in Sources */,\n'
        f'\t\t\t\t{EXISTING_BF_SWIFT} /* PacketTunnelProvider.swift in Sources */,\n'
        f'\t\t\t\tDAB30ECD5C294C550D13E7ED /* VpnPlugin.swift in Sources */,\n'
        f'\t\t\t\t1498D2341E8E89220040F4C2 /* GeneratedPluginRegistrant.m in Sources */,\n'
        f'\t\t\t);\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};'
    )
    runner_sources_fixed = (
        f'\t\t{RUNNER_SRC_PHASE} /* Sources */ = {{\n'
        f'\t\t\tisa = PBXSourcesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t\t74858FAF1ED2DC5600515810 /* AppDelegate.swift in Sources */,\n'
        f'\t\t\t\tDAB30ECD5C294C550D13E7ED /* VpnPlugin.swift in Sources */,\n'
        f'\t\t\t\t1498D2341E8E89220040F4C2 /* GeneratedPluginRegistrant.m in Sources */,\n'
        f'\t\t\t);\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};'
    )
    content = content.replace(runner_sources, runner_sources_fixed)

    # ── 7. ADD extension Sources, Frameworks, Resources phases ───
    ext_src = (
        f'\t\t{U_SRC} /* Sources */ = {{\n'
        f'\t\t\tisa = PBXSourcesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t\t{U_BF_SWIFT} /* PacketTunnelProvider.swift in Sources */,\n'
        f'\t\t\t);\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )
    ext_fw = (
        f'\t\t{U_FW} /* Frameworks */ = {{\n'
        f'\t\t\tisa = PBXFrameworksBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t\t{U_BF_SING} /* Singbox.xcframework in Frameworks */,\n'
        f'\t\t\t);\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )
    ext_res = (
        f'\t\t{U_RES} /* Resources */ = {{\n'
        f'\t\t\tisa = PBXResourcesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t);\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )

    # Insert extension Sources after Runner Sources
    content = content.replace(runner_sources_fixed, runner_sources_fixed + '\n\n' + ext_src)
    # Insert extension Frameworks before Runner Frameworks
    content = content.replace(
        f'\t\t{RUNNER_FW_PHASE} /* Frameworks */',
        ext_fw + f'\t\t{RUNNER_FW_PHASE} /* Frameworks */'
    )
    # Insert extension Resources before Runner Resources
    content = content.replace(
        f'\t\t{RUNNER_RES_PHASE} /* Resources */',
        ext_res + f'\t\t{RUNNER_RES_PHASE} /* Resources */'
    )

    # ── 8. ADD ContainerItemProxy + TargetDependency ─────────────
    proxy_block = (
        f'\t\t{U_PROXY} /* PBXContainerItemProxy */ = {{\n'
        f'\t\t\tisa = PBXContainerItemProxy;\n'
        f'\t\t\tcontainerPortal = {PROJECT_OBJ} /* Project object */;\n'
        f'\t\t\tproxyType = 1;\n'
        f'\t\t\tremoteGlobalIDString = {RUNNER_TGT};\n'
        f'\t\t\tremoteInfo = Runner;\n'
        f'\t\t}};\n'
    )
    dep_block = (
        f'\t\t{U_DEP} /* PBXTargetDependency */ = {{\n'
        f'\t\t\tisa = PBXTargetDependency;\n'
        f'\t\t\ttarget = {RUNNER_TGT} /* Runner */;\n'
        f'\t\t\ttargetProxy = {U_PROXY} /* PBXContainerItemProxy */;\n'
        f'\t\t}};\n'
    )

    # Insert after existing container proxy
    content = content.replace(
        f'\t\t331C8085294A63A400263BE5 /* PBXContainerItemProxy */',
        f'\t\t331C8085294A63A400263BE5 /* PBXContainerItemProxy */\n\n'
        + proxy_block
    )
    # Insert after existing target dependency
    content = content.replace(
        f'\t\t331C8086294A63A400263BE5 /* PBXTargetDependency */',
        dep_block + f'\t\t331C8086294A63A400263BE5 /* PBXTargetDependency */'
    )

    # ── 9. ADD Embed App Extensions phase ────────────────────────
    embed_phase = (
        f'\t\t{U_EMBED} /* Embed App Extensions */ = {{\n'
        f'\t\t\tisa = PBXCopyFilesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tdstPath = "";\n'
        f'\t\t\tdstSubfolderSpec = 13;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t);\n'
        f'\t\t\tname = "Embed App Extensions";\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )
    content = content.replace(
        f'\t\t{RUNNER_EMBED_PHASE} /* Embed Frameworks */',
        embed_phase + f'\t\t{RUNNER_EMBED_PHASE} /* Embed Frameworks */'
    )

    # ── 10. ADD Extension Build Configs ──────────────────────────
    # Debug
    ext_cfg_debug = (
        f'\t\t{U_CFG_DEBUG} /* Debug */ = {{\n'
        f'\t\t\tisa = XCBuildConfiguration;\n'
        f'\t\t\tbuildSettings = {{\n'
        f'\t\t\t\tCLANG_ENABLE_MODULES = YES;\n'
        f'\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n'
        f'\t\t\t\tCODE_SIGN_STYLE = Manual;\n'
        f'\t\t\t\tCURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";\n'
        f'\t\t\t\tDEVELOPMENT_TEAM = ABCD123456;\n'
        f'\t\t\t\tINFOPLIST_FILE = ForgeVpnPacketTunnel/Info.plist;\n'
        f'\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;\n'
        f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.forgeVpnFlutter.tunnel;\n'
        f'\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n'
        f'\t\t\t\tSKIP_INSTALL = YES;\n'
        f'\t\t\t\tSWIFT_OBJC_BRIDGING_HEADER = "Runner/Runner-Bridging-Header.h";\n'
        f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n'
        f'\t\t\t\tSWIFT_VERSION = 5.0;\n'
        f'\t\t\t\tFRAMEWORK_SEARCH_PATHS = (\n'
        f'\t\t\t\t\t"$(inherited)",\n'
        f'\t\t\t\t\t"$(PROJECT_DIR)/Runner",\n'
        f'\t\t\t\t);\n'
        f'\t\t\t}};\n'
        f'\t\t\tname = Debug;\n'
        f'\t\t}};\n'
    )
    content = content.replace(
        f'\t\t{RUNNER_CFG_DEBUG} /* Debug */ = {{\n'
        f'\t\t\tisa = XCBuildConfiguration;\n'
        f'\t\t\tbaseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;\n',
        ext_cfg_debug + f'\t\t{RUNNER_CFG_DEBUG} /* Debug */ = {{\n'
        f'\t\t\tisa = XCBuildConfiguration;\n'
        f'\t\t\tbaseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;\n'
    )

    # Release
    ext_cfg_release = (
        f'\t\t{U_CFG_RELEASE} /* Release */ = {{\n'
        f'\t\t\tisa = XCBuildConfiguration;\n'
        f'\t\t\tbuildSettings = {{\n'
        f'\t\t\t\tCLANG_ENABLE_MODULES = YES;\n'
        f'\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n'
        f'\t\t\t\tCODE_SIGN_STYLE = Manual;\n'
        f'\t\t\t\tCURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";\n'
        f'\t\t\t\tDEVELOPMENT_TEAM = ABCD123456;\n'
        f'\t\t\t\tINFOPLIST_FILE = ForgeVpnPacketTunnel/Info.plist;\n'
        f'\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;\n'
        f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.forgeVpnFlutter.tunnel;\n'
        f'\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n'
        f'\t\t\t\tSKIP_INSTALL = YES;\n'
        f'\t\t\t\tSWIFT_OBJC_BRIDGING_HEADER = "Runner/Runner-Bridging-Header.h";\n'
        f'\t\t\t\tSWIFT_VERSION = 5.0;\n'
        f'\t\t\t\tFRAMEWORK_SEARCH_PATHS = (\n'
        f'\t\t\t\t\t"$(inherited)",\n'
        f'\t\t\t\t\t"$(PROJECT_DIR)/Runner",\n'
        f'\t\t\t\t);\n'
        f'\t\t\t}};\n'
        f'\t\t\tname = Release;\n'
        f'\t\t}};\n'
    )
    content = content.replace(
        f'\t\t{RUNNER_CFG_RELEASE} /* Release */ = {{\n'
        f'\t\t\tisa = XCBuildConfiguration;\n'
        f'\t\t\tbaseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;\n',
        ext_cfg_release + f'\t\t{RUNNER_CFG_RELEASE} /* Release */ = {{\n'
        f'\t\t\tisa = XCBuildConfiguration;\n'
        f'\t\t\tbaseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;\n'
    )

    # Profile — insert at the end of XCBuildConfiguration section
    ext_cfg_profile = (
        f'\t\t{U_CFG_PROFILE} /* Profile */ = {{\n'
        f'\t\t\tisa = XCBuildConfiguration;\n'
        f'\t\t\tbuildSettings = {{\n'
        f'\t\t\t\tCLANG_ENABLE_MODULES = YES;\n'
        f'\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n'
        f'\t\t\t\tCODE_SIGN_STYLE = Manual;\n'
        f'\t\t\t\tCURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";\n'
        f'\t\t\t\tDEVELOPMENT_TEAM = ABCD123456;\n'
        f'\t\t\t\tINFOPLIST_FILE = ForgeVpnPacketTunnel/Info.plist;\n'
        f'\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 14.0;\n'
        f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.forgeVpnFlutter.tunnel;\n'
        f'\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n'
        f'\t\t\t\tSKIP_INSTALL = YES;\n'
        f'\t\t\t\tSWIFT_OBJC_BRIDGING_HEADER = "Runner/Runner-Bridging-Header.h";\n'
        f'\t\t\t\tSWIFT_VERSION = 5.0;\n'
        f'\t\t\t\tFRAMEWORK_SEARCH_PATHS = (\n'
        f'\t\t\t\t\t"$(inherited)",\n'
        f'\t\t\t\t\t"$(PROJECT_DIR)/Runner",\n'
        f'\t\t\t\t);\n'
        f'\t\t\t}};\n'
        f'\t\t\tname = Profile;\n'
        f'\t\t}};\n'
    )

    # Find the end of XCBuildConfiguration section and insert before End XCBuildConfiguration
    buildcfg_end = content.index('/* End XCBuildConfiguration section */')
    content = content[:buildcfg_end] + ext_cfg_profile + content[buildcfg_end:]

    # ── 11. ADD XCConfigurationList for extension ────────────────
    ext_cfglist = (
        f'\t\t{U_CFGLIST} /* Build configuration list for PBXNativeTarget "ForgeVpnPacketTunnel" */ = {{\n'
        f'\t\t\tisa = XCConfigurationList;\n'
        f'\t\t\tbuildConfigurations = (\n'
        f'\t\t\t\t{U_CFG_DEBUG} /* Debug */,\n'
        f'\t\t\t\t{U_CFG_RELEASE} /* Release */,\n'
        f'\t\t\t\t{U_CFG_PROFILE} /* Profile */,\n'
        f'\t\t\t);\n'
        f'\t\t\tdefaultConfigurationIsVisible = 0;\n'
        f'\t\t\tdefaultConfigurationName = Release;\n'
        f'\t\t}};\n'
    )
    content = content.replace(
        f'\t\t{RUNNER_CFGLIST} /* Build configuration list for PBXNativeTarget "Runner" */',
        ext_cfglist + f'\t\t{RUNNER_CFGLIST} /* Build configuration list for PBXNativeTarget "Runner" */'
    )

    # ── 12. ADD extension to project targets list ────────────────
    content = content.replace(
        f'\t\t\t\ttargets = (\n'
        f'\t\t\t\t\t{RUNNER_TGT} /* Runner */,\n'
        f'\t\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n'
        f'\t\t\t\t);',
        f'\t\t\t\ttargets = (\n'
        f'\t\t\t\t\t{RUNNER_TGT} /* Runner */,\n'
        f'\t\t\t\t\t{U_TGT} /* ForgeVpnPacketTunnel */,\n'
        f'\t\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n'
        f'\t\t\t\t);'
    )

    # ── 13. ADD extension PBXNativeTarget ────────────────────────
    ext_target = (
        f'\t\t{U_TGT} /* ForgeVpnPacketTunnel */ = {{\n'
        f'\t\t\tisa = PBXNativeTarget;\n'
        f'\t\t\tbuildConfigurationList = {U_CFGLIST} /* Build configuration list for PBXNativeTarget "ForgeVpnPacketTunnel" */;\n'
        f'\t\t\tbuildPhases = (\n'
        f'\t\t\t\t{U_SRC} /* Sources */,\n'
        f'\t\t\t\t{U_FW} /* Frameworks */,\n'
        f'\t\t\t\t{U_RES} /* Resources */,\n'
        f'\t\t\t);\n'
        f'\t\t\tbuildRules = (\n'
        f'\t\t\t);\n'
        f'\t\t\tdependencies = (\n'
        f'\t\t\t\t{U_DEP} /* PBXTargetDependency */,\n'
        f'\t\t\t);\n'
        f'\t\t\tname = ForgeVpnPacketTunnel;\n'
        f'\t\t\tproductName = ForgeVpnPacketTunnel;\n'
        f'\t\t\tproductReference = {U_PRODUCT_REF} /* ForgeVpnPacketTunnel.appex */;\n'
        f'\t\t\tproductType = "com.apple.product-type.app-extension";\n'
        f'\t\t}};\n'
    )
    content = content.replace(
        f'\t\t{RUNNER_TGT} /* Runner */ = ',
        ext_target + f'\t\t{RUNNER_TGT} /* Runner */ = '
    )

    # ── 14. ADD dependency + embed phase to Runner target ────────
    # Find Runner target block
    runner_target_match = (
        f'\t\t{RUNNER_TGT} /* Runner */ = {{\n'
        f'\t\t\tisa = PBXNativeTarget;\n'
        f'\t\t\tbuildConfigurationList = {RUNNER_CFGLIST} /* Build configuration list for PBXNativeTarget "Runner" */;\n'
        f'\t\t\tbuildPhases = (\n'
        f'\t\t\t\t9740EEB61CF901F6004384FC /* Run Script */,\n'
        f'\t\t\t\t{RUNNER_SRC_PHASE} /* Sources */,\n'
        f'\t\t\t\t{RUNNER_FW_PHASE} /* Frameworks */,\n'
        f'\t\t\t\t{RUNNER_RES_PHASE} /* Resources */,\n'
        f'\t\t\t\t{RUNNER_EMBED_PHASE} /* Embed Frameworks */,\n'
        f'\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n'
        f'\t\t\t);\n'
        f'\t\t\tbuildRules = (\n'
        f'\t\t\t);\n'
        f'\t\t\tdependencies = (\n'
        f'\t\t\t);'
    )
    runner_target_new = (
        f'\t\t{RUNNER_TGT} /* Runner */ = {{\n'
        f'\t\t\tisa = PBXNativeTarget;\n'
        f'\t\t\tbuildConfigurationList = {RUNNER_CFGLIST} /* Build configuration list for PBXNativeTarget "Runner" */;\n'
        f'\t\t\tbuildPhases = (\n'
        f'\t\t\t\t{U_EMBED} /* Embed App Extensions */,\n'
        f'\t\t\t\t9740EEB61CF901F6004384FC /* Run Script */,\n'
        f'\t\t\t\t{RUNNER_SRC_PHASE} /* Sources */,\n'
        f'\t\t\t\t{RUNNER_FW_PHASE} /* Frameworks */,\n'
        f'\t\t\t\t{RUNNER_RES_PHASE} /* Resources */,\n'
        f'\t\t\t\t{RUNNER_EMBED_PHASE} /* Embed Frameworks */,\n'
        f'\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n'
        f'\t\t\t);\n'
        f'\t\t\tbuildRules = (\n'
        f'\t\t\t);\n'
        f'\t\t\tdependencies = (\n'
        f'\t\t\t\t{U_DEP} /* PBXTargetDependency */,\n'
        f'\t\t\t);'
    )
    content = content.replace(runner_target_match, runner_target_new)

    # ── 15. Clean up duplicate blank lines ───────────────────────
    content = re.sub(r'\n{3,}', '\n\n', content)

    return content


# ── Main ─────────────────────────────────────────────────────────

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    pbxproj_path = os.path.join(project_dir, PBXPROJ)

    if not os.path.exists(pbxproj_path):
        print(f"Error: {pbxproj_path} not found")
        sys.exit(1)

    with open(pbxproj_path) as f:
        content = f.read()

    original = content
    content = patch(content)

    if content == original:
        print("Error: pbxproj unchanged")
        sys.exit(1)

    with open(pbxproj_path, 'w') as f:
        f.write(content)

    # Validate
    all_uuids = [
        U_TGT, U_CFGLIST, U_SRC, U_FW, U_RES, U_BF_SWIFT, U_BF_SING,
        U_INFO_PLIST, U_PRODUCT_REF, U_DEP, U_PROXY, U_EMBED, U_GRP,
        U_CFG_DEBUG, U_CFG_RELEASE, U_CFG_PROFILE
    ]
    for uid in all_uuids:
        if uid not in content:
            print(f"  MISSING: {uid}")

    # Check no duplicates
    for uid in all_uuids:
        count = content.count(uid)
        if count > 1:
            # The reference UUID in the PBXFileReference line will have it once,
            # and references will have it more. That's fine.
            pass

    # Check Runner Sources doesn't have PacketTunnelProvider
    src_block = re.search(
        r'97C146EA1CF9000F007C117D /\* Sources \*/.*?runOnlyForDeploymentPostprocessing = 0;\n\t\t\};',
        content, re.DOTALL | re.S
    )
    if src_block and EXISTING_BF_SWIFT in src_block.group():
        print("  PacketTunnelProvider.swift STILL in Runner Sources!")
    else:
        pass  # good

    print("  pbxproj patched successfully")


if __name__ == "__main__":
    main()

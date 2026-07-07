import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/autocomplete.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/animated_rotation_widget.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart' as ppdesk_dialogs;
import 'package:flutter_hbb/common/widgets/login.dart' as ppdesk_login;
import 'package:flutter_hbb/common/widgets/setting_widgets.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
import 'package:flutter_hbb/mobile/widgets/dialog.dart'
    as ppdesk_mobile_dialogs;
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/plugin/ui_manager.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:flutter_hbb/utils/platform_channel.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;
import '../widgets/button.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

const borderColor = Color(0xFF2F65BA);

class _DesktopHomePageState extends State<DesktopHomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _leftPaneScrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;
  var systemError = '';
  StreamSubscription? _uniLinksSubscription;
  var svcStopped = false.obs;
  var watchIsCanScreenRecording = false;
  var watchIsProcessTrust = false;
  var watchIsInputMonitoring = false;
  var watchIsCanRecordAudio = false;
  Timer? _updateTimer;
  bool isCardClosed = false;

  final RxBool _editHover = false.obs;
  final RxBool _block = false.obs;

  final GlobalKey _childKey = GlobalKey();
  final _ppDeskIdController = IDTextEditingController();
  final _ppDeskIdFocusNode = FocusNode();
  final _ppDeskTextController = TextEditingController();
  final _ppDeskDeviceSearchController = TextEditingController();
  final _ppDeskDeviceSearchFocusNode = FocusNode();
  final _ppDeskSessionSearchController = TextEditingController();
  final _ppDeskSessionSearchFocusNode = FocusNode();
  final Map<String, String> _ppDeskLangLabels = {};
  final _ppDeskAllPeersLoader = AllPeersLoader();
  final RxBool _ppDeskIdFocused = false.obs;
  Iterable<Peer> _ppDeskAutocompleteOpts = const [];
  int _ppDeskPage = 0;
  String _ppDeskDeviceSearch = '';
  String _ppDeskDeviceGroup = 'all';
  String _ppDeskDevicePlatform = 'all';
  String _ppDeskDeviceStatus = 'all';
  String _ppDeskSessionSearch = '';
  String _ppDeskSessionType = 'all';
  String _ppDeskSessionTime = 'all';
  SettingsTabKey _ppDeskSettingTab = SettingsTabKey.account;
  bool _ppDeskShowStartup = true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isIncomingOnly = bind.isIncomingOnly();
    if (!isIncomingOnly) {
      return _buildBlock(child: _buildPPDeskHome(context));
    }
    return _buildBlock(
        child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLeftPane(context),
        if (!isIncomingOnly) const VerticalDivider(width: 1),
        if (!isIncomingOnly) Expanded(child: buildRightPane(context)),
      ],
    ));
  }

  Widget _buildBlock({required Widget child}) {
    return buildRemoteBlock(
        block: _block, mask: true, use: canBeBlocked, child: child);
  }

  Widget _buildPPDeskHome(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 1180 || constraints.maxHeight < 980;
          final sidebarWidth = compact ? 260.0 : 296.0;
          return Container(
            color: const Color(0xFFF8FAFF),
            child: Stack(
              children: [
                Row(
                  children: [
                    _buildPPDeskSidebar(context, isOutgoingOnly,
                        width: sidebarWidth, compact: compact),
                    Expanded(child: _buildPPDeskMain(context, isOutgoingOnly)),
                  ],
                ),
                if (_ppDeskShowStartup) _buildPPDeskStartupOverlay(compact),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPPDeskSidebar(BuildContext context, bool isOutgoingOnly,
      {required double width, required bool compact}) {
    final logoSize = compact ? 44.0 : 48.0;
    final navGap = compact ? 30.0 : 46.0;
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F8FF),
        border: Border(right: BorderSide(color: Color(0xFFE8EEF8))),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              compact ? 24 : 30, compact ? 22 : 26, compact ? 22 : 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset('assets/ppdesk_logo.png',
                      width: logoSize, height: logoSize),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('皮皮远程',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 24,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF101828))),
                        SizedBox(height: 4),
                        Text('PPDesk',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF7C8AA5))),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: navGap),
              _PPDeskNavItem(
                icon: 'ppdesk_home',
                label: '首页',
                selected: _ppDeskPage == 0,
                compact: compact,
                onTap: () => setState(() => _ppDeskPage = 0),
              ),
              _PPDeskNavItem(
                icon: 'ppdesk_device',
                label: '设备列表',
                selected: _ppDeskPage == 1,
                compact: compact,
                onTap: () => setState(() => _ppDeskPage = 1),
              ),
              _PPDeskNavItem(
                icon: 'ppdesk_clock',
                label: '会话记录',
                selected: _ppDeskPage == 2,
                compact: compact,
                onTap: () => setState(() => _ppDeskPage = 2),
              ),
              _PPDeskNavItem(
                icon: 'ppdesk_toolbox',
                label: '工具箱',
                selected: _ppDeskPage == 4,
                compact: compact,
                onTap: () => setState(() => _ppDeskPage = 4),
              ),
              _PPDeskNavItem(
                icon: 'ppdesk_settings',
                label: '设置中心',
                selected: _ppDeskPage == 3,
                compact: compact,
                onTap: () => setState(() => _ppDeskPage = 3),
              ),
              const Spacer(),
              if (!isOutgoingOnly)
                _buildPPDeskLocalAccess(context, compact: compact),
              Container(height: 1, color: const Color(0xFFDDE6F4)).marginOnly(
                  top: compact ? 14 : 22, bottom: compact ? 14 : 20),
              _buildPPDeskUserTile(context, compact: compact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPPDeskLocalAccess(BuildContext context,
      {required bool compact}) {
    return Consumer<ServerModel>(builder: (context, model, _) {
      final showOneTime = model.approveMode != 'click' &&
          model.verificationMethod != kUsePermanentPassword;
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 14 : 18),
          border: Border.all(color: const Color(0xFFE4EAF4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('本机访问',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF101828))),
            const SizedBox(height: 12),
            _buildPPDeskCopyLine(
              context,
              label: 'ID',
              value: model.serverId.text,
              onCopy: () => model.serverId.text,
              compact: compact,
            ),
            SizedBox(height: compact ? 6 : 10),
            Row(
              children: [
                Expanded(
                  child: _buildPPDeskCopyLine(
                    context,
                    label: translate('One-time Password'),
                    value: model.serverPasswd.text.isEmpty
                        ? '-'
                        : model.serverPasswd.text,
                    onCopy: () => showOneTime ? model.serverPasswd.text : '',
                    compact: compact,
                  ),
                ),
                if (showOneTime)
                  _PPDeskIconButton(
                    icon: 'ppdesk_refresh',
                    tooltip: translate('Refresh Password'),
                    onTap: () => bind.mainUpdateTemporaryPassword(),
                  ),
                if (!bind.isDisableSettings())
                  _PPDeskIconButton(
                    icon: 'ppdesk_edit',
                    tooltip: translate('Change Password'),
                    onTap: () => setState(() {
                      _ppDeskPage = 3;
                      _ppDeskSettingTab = SettingsTabKey.safety;
                    }),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPPDeskStartupOverlay(bool compact) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _ppDeskShowStartup ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFF),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/ppdesk_logo.png',
                      width: compact ? 76 : 92, height: compact ? 76 : 92),
                  const SizedBox(height: 22),
                  Text('皮皮远程',
                      style: TextStyle(
                          color: const Color(0xFF101828),
                          fontSize: compact ? 32 : 40,
                          height: 1.05,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('PPDesk',
                      style: TextStyle(
                          color: const Color(0xFF7C8AA5),
                          fontSize: compact ? 21 : 26,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 34),
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF4D5DFF),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('正在启动...',
                      style: TextStyle(
                          color: const Color(0xFF101828),
                          fontSize: compact ? 18 : 21,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('安全连接，随时随地',
                      style: TextStyle(
                          color: const Color(0xFF7C8AA5),
                          fontSize: compact ? 14 : 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPPDeskCopyLine(BuildContext context,
      {required String label,
      required String value,
      required String Function() onCopy,
      required bool compact}) {
    return GestureDetector(
      onDoubleTap: () {
        final text = onCopy();
        if (text.isEmpty) {
          return;
        }
        Clipboard.setData(ClipboardData(text: text));
        showToast(translate('Copied'));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7C8AA5))),
          SizedBox(height: compact ? 1 : 3),
          Text(value.isEmpty ? '-' : value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: compact ? 16 : 18,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF101828))),
        ],
      ),
    );
  }

  Widget _buildPPDeskUserTile(BuildContext context, {required bool compact}) {
    final rawUserName = gFFI.userModel.userName.toString();
    final userName = rawUserName.isEmpty ? '皮皮用户' : rawUserName;
    final avatarSize = compact ? 46.0 : 54.0;
    return Row(
      children: [
        Stack(
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFF2D6BFF), Color(0xFF6B2BFF)]),
              ),
              child: const Text('皮',
                  style: TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.w800)),
            ),
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF20D67B),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF101828))),
              const SizedBox(height: 4),
              const Text('user@example.com',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Color(0xFF7C8AA5))),
            ],
          ),
        ),
        _ppDeskSvg('ppdesk_chevron_down',
            color: const Color(0xFF7C8AA5), size: 18),
      ],
    );
  }

  Widget _buildPPDeskMain(BuildContext context, bool isOutgoingOnly) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 1120 || constraints.maxHeight < 980;
        final horizontalPadding = compact ? 28.0 : 48.0;
        final rightPadding = compact ? 28.0 : 44.0;
        final topPadding = compact ? 18.0 : 24.0;
        final blockGap = compact ? 12.0 : 20.0;
        final padding = EdgeInsets.fromLTRB(
            horizontalPadding, topPadding, rightPadding, compact ? 20 : 28);
        if (_ppDeskPage == 1) {
          return Padding(
            padding: padding,
            child: _buildPPDeskDeviceListPage(compact: compact),
          );
        }
        if (_ppDeskPage == 2) {
          return Padding(
            padding: padding,
            child: _buildPPDeskSessionPage(compact: compact),
          );
        }
        if (_ppDeskPage == 3) {
          return Padding(
            padding: padding,
            child: _buildPPDeskSettingsPage(compact: compact),
          );
        }
        if (_ppDeskPage == 4) {
          return Padding(
            padding: padding,
            child: _buildPPDeskToolboxPage(compact: compact),
          );
        }
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('上午好，皮皮用户',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: compact ? 26 : 32,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF101828))),
                        SizedBox(height: compact ? 5 : 10),
                        Text('安全、高效、简单，随时随地轻松远程连接。',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: compact ? 13 : 15,
                                color: const Color(0xFF66738A))),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: blockGap),
              _buildPPDeskQuickConnect(context, compact: compact),
              SizedBox(height: blockGap),
              _buildPPDeskStats(compact: compact),
              SizedBox(height: blockGap),
              Expanded(child: _buildPPDeskRecentCard(compact: compact)),
              if (!isOutgoingOnly) const OnlineStatusWidget(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPPDeskDeviceListPage({required bool compact}) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        gFFI.recentPeersModel,
        gFFI.favoritePeersModel,
        gFFI.lanPeersModel,
      ]),
      builder: (context, _) {
        final allDevices = _ppDeskAllDevices();
        final devices = _ppDeskFilteredDevices(allDevices);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('设备列表',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: compact ? 28 : 34,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF101828))),
                      SizedBox(height: compact ? 6 : 10),
                      Text('集中管理您的远程设备，随时连接与控制。',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: compact ? 13 : 15,
                              color: const Color(0xFF66738A))),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 16 : 24),
            _buildPPDeskDeviceFilters(compact: compact),
            SizedBox(height: compact ? 14 : 22),
            Expanded(
              child: Row(
                children: [
                  _buildPPDeskGroupPanel(allDevices, compact: compact),
                  SizedBox(width: compact ? 12 : 18),
                  Expanded(
                    child: _buildPPDeskDeviceTable(devices,
                        total: allDevices.length, compact: compact),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPPDeskDeviceFilters({required bool compact}) {
    return Row(
      children: [
        Expanded(
          child: _buildPPDeskSearchField(
            controller: _ppDeskDeviceSearchController,
            focusNode: _ppDeskDeviceSearchFocusNode,
            hintText: '搜索设备名称或设备 ID',
            compact: compact,
            onChanged: (value) => setState(() => _ppDeskDeviceSearch = value),
          ),
        ),
        SizedBox(width: compact ? 8 : 12),
        _PPDeskFilterButton(
          label: '分组',
          selected: _ppDeskDeviceGroup,
          value: _ppDeskGroupLabel(_ppDeskDeviceGroup),
          compact: compact,
          items: const {
            'all': '全部分组',
            'ungrouped': '未分组',
            'favorites': '收藏设备',
            'online': '在线设备',
            'lan': '局域网设备',
          },
          onChanged: (value) => setState(() => _ppDeskDeviceGroup = value),
        ),
        SizedBox(width: compact ? 8 : 12),
        _PPDeskFilterButton(
          label: '平台',
          selected: _ppDeskDevicePlatform,
          value: _ppDeskPlatformLabel(_ppDeskDevicePlatform),
          compact: compact,
          items: const {
            'all': '全部平台',
            'windows': 'Windows',
            'macos': 'macOS',
            'linux': 'Linux',
            'android': 'Android',
          },
          onChanged: (value) => setState(() => _ppDeskDevicePlatform = value),
        ),
        SizedBox(width: compact ? 8 : 12),
        _PPDeskFilterButton(
          label: '状态',
          selected: _ppDeskDeviceStatus,
          value: _ppDeskStatusLabel(_ppDeskDeviceStatus),
          compact: compact,
          items: const {
            'all': '全部状态',
            'online': '在线',
            'offline': '离线',
          },
          onChanged: (value) => setState(() => _ppDeskDeviceStatus = value),
        ),
        SizedBox(width: compact ? 10 : 14),
        _PPDeskPrimaryButton(
          label: '添加设备',
          compact: compact,
          icon: 'ppdesk_plus',
          onTap: () => showToast('请先连接设备，再在查看全部中加入地址簿'),
        ),
      ],
    );
  }

  Widget _buildPPDeskSearchField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required bool compact,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: compact ? 40 : 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE6F4)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: ColoredBox(
              color: Colors.white,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: false,
                cursorColor: const Color(0xFF2D6BFF),
                style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    height: 1.25,
                    color: const Color(0xFF101828),
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  hoverColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: hintText,
                  hintStyle: TextStyle(
                      color: const Color(0xFFA1AEC2),
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w600),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: compact ? 10 : 12),
                ),
                onChanged: onChanged,
              ).workaroundFreezeLinuxMint(),
            ),
          ),
          _ppDeskSvg('ppdesk_search',
              color: const Color(0xFF1F2A44), size: compact ? 18 : 20),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildPPDeskGroupPanel(List<Peer> allDevices,
      {required bool compact}) {
    final favoriteIds = gFFI.favoritePeersModel.peers.map((p) => p.id).toSet();
    final lanIds = gFFI.lanPeersModel.peers.map((p) => p.id).toSet();
    final groups = [
      ('all', '全部设备', allDevices.length, 'ppdesk_device'),
      (
        'ungrouped',
        '未分组',
        allDevices.where((p) => p.device_group_name.isEmpty).length,
        'ppdesk_folder'
      ),
      ('favorites', '收藏设备', favoriteIds.length, 'ppdesk_star'),
      (
        'online',
        '在线设备',
        allDevices.where((p) => p.online).length,
        'ppdesk_clock'
      ),
      ('lan', '局域网设备', lanIds.length, 'ppdesk_folder'),
    ];
    return Container(
      width: compact ? 168 : 220,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: _ppDeskCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('分组管理',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828))),
              ),
              _ppDeskSvg('ppdesk_plus',
                  color: const Color(0xFF1F2A44), size: 18),
            ],
          ),
          SizedBox(height: compact ? 14 : 22),
          ...groups.map((item) => _PPDeskGroupItem(
                icon: item.$4,
                label: item.$2,
                count: item.$3,
                selected: _ppDeskDeviceGroup == item.$1,
                compact: compact,
                onTap: () => setState(() => _ppDeskDeviceGroup = item.$1),
              )),
          const Spacer(),
          Container(height: 1, color: const Color(0xFFE1E8F4)),
          SizedBox(height: compact ? 12 : 16),
          InkWell(
            onTap: () => showToast('请在查看全部中管理回收站'),
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: Row(
              children: [
                SvgPicture.asset('assets/trash.svg',
                    width: 18,
                    height: 18,
                    colorFilter: const ColorFilter.mode(
                        Color(0xFF7C8AA5), BlendMode.srcIn)),
                const SizedBox(width: 8),
                const Text('回收站',
                    style: TextStyle(fontSize: 13, color: Color(0xFF66738A))),
              ],
            ).paddingSymmetric(vertical: 6),
          ),
        ],
      ),
    );
  }

  Widget _buildPPDeskDeviceTable(List<Peer> devices,
      {required int total, required bool compact}) {
    return Container(
      decoration: _ppDeskCardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                compact ? 14 : 20, compact ? 12 : 16, compact ? 14 : 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text('共 ${devices.length} 台设备',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF66738A),
                          fontWeight: FontWeight.w700)),
                ),
                _PPDeskSmallButton(
                  icon: 'ppdesk_refresh',
                  label: '刷新',
                  compact: compact,
                  onTap: () {
                    bind.mainLoadRecentPeers();
                    bind.mainLoadFavPeers();
                    bind.mainLoadLanPeers();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EEF8)),
          _buildPPDeskDeviceTableHeader(compact: compact),
          const Divider(height: 1, color: Color(0xFFE8EEF8)),
          Expanded(
            child: devices.isEmpty
                ? const Center(
                    child: Text('暂无匹配设备',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF7C8AA5))))
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: devices.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFE8EEF8)),
                    itemBuilder: (_, index) => _PPDeskDeviceRow(
                      peer: devices[index],
                      compact: compact,
                      favorite: gFFI.favoritePeersModel.peers
                          .any((p) => p.id == devices[index].id),
                      onConnect: () {
                        _ppDeskIdController.id = devices[index].id;
                        _ppDeskConnect();
                      },
                      onAction: (value) {
                        if (value == 'connect') {
                          _ppDeskIdController.id = devices[index].id;
                          _ppDeskConnect();
                        } else if (value == 'file') {
                          _ppDeskIdController.id = devices[index].id;
                          _ppDeskConnect(isFileTransfer: true);
                        } else {
                          showToast('请在查看全部中管理设备');
                        }
                      },
                    ),
                  ),
          ),
          Container(
            height: compact ? 42 : 54,
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8EEF8))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('共 $total 条',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF66738A))),
                const SizedBox(width: 18),
                Text('${devices.length} 条/页',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF66738A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPPDeskDeviceTableHeader({required bool compact}) {
    final style = TextStyle(
        fontSize: compact ? 12 : 13,
        color: const Color(0xFF66738A),
        fontWeight: FontWeight.w800);
    return Container(
      height: compact ? 42 : 54,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
      color: const Color(0xFFFBFCFF),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('设备名称', style: style)),
          Expanded(flex: 3, child: Text('设备 ID', style: style)),
          Expanded(flex: 2, child: Text('平台', style: style)),
          Expanded(flex: 2, child: Text('标签', style: style)),
          Expanded(flex: 2, child: Text('状态', style: style)),
          SizedBox(width: compact ? 52 : 70, child: Text('操作', style: style)),
        ],
      ),
    );
  }

  List<Peer> _ppDeskAllDevices() {
    final byId = <String, Peer>{};
    for (final peer in [
      ...gFFI.recentPeersModel.peers,
      ...gFFI.favoritePeersModel.peers,
      ...gFFI.lanPeersModel.peers,
    ]) {
      if (peer.id.isNotEmpty) {
        byId[peer.id] = peer;
      }
    }
    return byId.values.toList();
  }

  List<Peer> _ppDeskFilteredDevices(List<Peer> devices) {
    final favoriteIds = gFFI.favoritePeersModel.peers.map((p) => p.id).toSet();
    final lanIds = gFFI.lanPeersModel.peers.map((p) => p.id).toSet();
    final search = _ppDeskDeviceSearch.trim().toLowerCase().replaceAll(' ', '');
    return devices.where((peer) {
      if (_ppDeskDeviceGroup == 'ungrouped' &&
          peer.device_group_name.isNotEmpty) {
        return false;
      }
      if (_ppDeskDeviceGroup == 'favorites' && !favoriteIds.contains(peer.id)) {
        return false;
      }
      if (_ppDeskDeviceGroup == 'online' && !peer.online) {
        return false;
      }
      if (_ppDeskDeviceGroup == 'lan' && !lanIds.contains(peer.id)) {
        return false;
      }
      if (_ppDeskDeviceStatus == 'online' && !peer.online) {
        return false;
      }
      if (_ppDeskDeviceStatus == 'offline' && peer.online) {
        return false;
      }
      if (_ppDeskDevicePlatform != 'all' &&
          !_ppDeskPlatformMatches(peer.platform, _ppDeskDevicePlatform)) {
        return false;
      }
      if (search.isEmpty) {
        return true;
      }
      final name = _ppDeskPeerName(peer).toLowerCase();
      final id = peer.id.toLowerCase().replaceAll(' ', '');
      return name.contains(search) || id.contains(search);
    }).toList();
  }

  bool _ppDeskPlatformMatches(String platform, String filter) {
    final p = platform.toLowerCase();
    return switch (filter) {
      'windows' => p.contains('win'),
      'macos' => p.contains('mac'),
      'linux' => p.contains('linux'),
      'android' => p.contains('android'),
      _ => true,
    };
  }

  String _ppDeskGroupLabel(String value) {
    return const {
          'all': '全部分组',
          'ungrouped': '未分组',
          'favorites': '收藏设备',
          'online': '在线设备',
          'lan': '局域网设备',
        }[value] ??
        '全部分组';
  }

  String _ppDeskPlatformLabel(String value) {
    return const {
          'all': '全部平台',
          'windows': 'Windows',
          'macos': 'macOS',
          'linux': 'Linux',
          'android': 'Android',
        }[value] ??
        '全部平台';
  }

  String _ppDeskStatusLabel(String value) {
    return const {
          'all': '全部状态',
          'online': '在线',
          'offline': '离线',
        }[value] ??
        '全部状态';
  }

  String _ppDeskPeerName(Peer peer) {
    if (peer.alias.isNotEmpty) {
      return peer.alias;
    }
    if (peer.username.isNotEmpty && peer.hostname.isNotEmpty) {
      return '${peer.username}@${peer.hostname}';
    }
    if (peer.hostname.isNotEmpty) {
      return peer.hostname;
    }
    if (peer.username.isNotEmpty) {
      return peer.username;
    }
    return formatID(peer.id);
  }

  Widget _buildPPDeskSessionPage({required bool compact}) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        gFFI.recentPeersModel,
        gFFI.favoritePeersModel,
        gFFI.lanPeersModel,
      ]),
      builder: (context, _) {
        final records = _ppDeskFilteredSessions(_ppDeskSessionRecords());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('会话记录',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: compact ? 28 : 34,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF101828))),
                      SizedBox(height: compact ? 6 : 10),
                      Text('查看远程控制与文件传输历史记录。',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: compact ? 13 : 15,
                              color: const Color(0xFF66738A))),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 16 : 24),
            _buildPPDeskSessionFilters(compact: compact),
            SizedBox(height: compact ? 14 : 22),
            Expanded(child: _buildPPDeskSessionSections(records, compact)),
            SizedBox(height: compact ? 10 : 16),
            _buildPPDeskSessionFooter(records.length, compact: compact),
          ],
        );
      },
    );
  }

  Widget _buildPPDeskSessionFilters({required bool compact}) {
    return Row(
      children: [
        Expanded(
          child: _buildPPDeskSearchField(
            controller: _ppDeskSessionSearchController,
            focusNode: _ppDeskSessionSearchFocusNode,
            hintText: '搜索设备名称、设备 ID 或会话内容',
            compact: compact,
            onChanged: (value) => setState(() => _ppDeskSessionSearch = value),
          ),
        ),
        SizedBox(width: compact ? 8 : 12),
        _PPDeskFilterButton(
          label: '会话类型',
          selected: _ppDeskSessionType,
          value: _ppDeskSessionTypeLabel(_ppDeskSessionType),
          compact: compact,
          items: const {
            'all': '全部类型',
            'remote': '远程控制',
            'file': '文件传输',
          },
          onChanged: (value) => setState(() => _ppDeskSessionType = value),
        ),
        SizedBox(width: compact ? 8 : 12),
        _PPDeskFilterButton(
          label: '时间',
          selected: _ppDeskSessionTime,
          value: _ppDeskSessionTimeLabel(_ppDeskSessionTime),
          compact: compact,
          items: const {
            'all': '全部时间',
            'today': '今天',
            'yesterday': '昨天',
            'earlier': '更早',
          },
          onChanged: (value) => setState(() => _ppDeskSessionTime = value),
        ),
        SizedBox(width: compact ? 10 : 14),
        _PPDeskOutlineButton(
          icon: 'ppdesk_download',
          label: '导出记录',
          compact: compact,
          onTap: () => showToast('接入真实会话日志后可导出记录'),
        ),
      ],
    );
  }

  Widget _buildPPDeskSessionSections(
      List<_PPDeskSessionRecord> records, bool compact) {
    if (records.isEmpty) {
      return Container(
        decoration: _ppDeskCardDecoration(),
        alignment: Alignment.center,
        child: const Text('暂无匹配会话',
            style: TextStyle(fontSize: 14, color: Color(0xFF7C8AA5))),
      );
    }
    const groupLabels = {
      'today': '今天',
      'yesterday': '昨天',
      'earlier': '更早',
    };
    return ListView(
      padding: EdgeInsets.zero,
      children: groupLabels.entries.expand((entry) {
        final groupRecords =
            records.where((record) => record.group == entry.key).toList();
        if (groupRecords.isEmpty) {
          return const <Widget>[];
        }
        return [
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 8 : 12),
            child: Text(entry.value,
                style: TextStyle(
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF101828))),
          ),
          Container(
            margin: EdgeInsets.only(bottom: compact ? 12 : 20),
            decoration: _ppDeskCardDecoration(),
            child: Column(
              children: [
                for (var i = 0; i < groupRecords.length; i++) ...[
                  _PPDeskSessionRow(
                    record: groupRecords[i],
                    compact: compact,
                    onOpen: () {
                      _ppDeskIdController.id = groupRecords[i].peer.id;
                      _ppDeskConnect(
                          isFileTransfer: groupRecords[i].type == 'file');
                    },
                    onAction: (value) {
                      _ppDeskIdController.id = groupRecords[i].peer.id;
                      if (value == 'file') {
                        _ppDeskConnect(isFileTransfer: true);
                      } else if (value == 'connect') {
                        _ppDeskConnect();
                      } else {
                        showToast('会话详情需接入真实会话日志');
                      }
                    },
                  ),
                  if (i != groupRecords.length - 1)
                    const Divider(height: 1, color: Color(0xFFE8EEF8)),
                ],
              ],
            ),
          ),
        ];
      }).toList(),
    );
  }

  Widget _buildPPDeskSessionFooter(int count, {required bool compact}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('共 $count 条',
            style: const TextStyle(fontSize: 13, color: Color(0xFF66738A))),
        const SizedBox(width: 18),
        Container(
          height: compact ? 34 : 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE1E8F4)),
          ),
          child: Row(
            children: [
              const Text('20 条/页',
                  style: TextStyle(fontSize: 13, color: Color(0xFF66738A))),
              const SizedBox(width: 10),
              _ppDeskSvg('ppdesk_chevron_down',
                  color: const Color(0xFF66738A), size: 16),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _PPDeskPagerButton(
          icon: 'ppdesk_chevron_right',
          flip: true,
          compact: compact,
          onTap: () => showToast('已经是第一页'),
        ),
        const SizedBox(width: 8),
        Container(
          width: compact ? 34 : 38,
          height: compact ? 34 : 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2D6BFF)),
          ),
          child: const Text('1',
              style: TextStyle(
                  color: Color(0xFF2D6BFF), fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        _PPDeskPagerButton(
          icon: 'ppdesk_chevron_right',
          compact: compact,
          onTap: () => showToast('已经是最后一页'),
        ),
      ],
    );
  }

  List<_PPDeskSessionRecord> _ppDeskSessionRecords() {
    final peers = _ppDeskAllDevices();
    const times = [
      '10:24',
      '09:45',
      '08:30',
      '昨天 16:20',
      '昨天 14:12',
      '昨天 11:05',
      '05-10 19:32',
      '05-08 22:18'
    ];
    const durations = [
      '00:18:36',
      '00:02:14',
      '00:45:12',
      '00:03:58',
      '00:22:07',
      '00:15:33',
      '00:31:08',
      '01:05:27'
    ];
    const files = ['项目说明.pdf', '部署日志.zip', '备份数据.tar'];
    const sizes = ['12.4 MB', '68.7 MB', '256.3 MB'];
    const colors = [
      Color(0xFF2D6BFF),
      Color(0xFF20C66B),
      Color(0xFF7C3CFF),
      Color(0xFFFF9F1C),
    ];
    return [
      for (var i = 0; i < peers.length; i++)
        _PPDeskSessionRecord(
          peer: peers[i],
          type: i % 3 == 1 ? 'file' : 'remote',
          group: i < 3
              ? 'today'
              : i < 6
                  ? 'yesterday'
                  : 'earlier',
          time: times[i % times.length],
          duration: durations[i % durations.length],
          status: i % 5 == 4
              ? 'failed'
              : i % 3 == 2
                  ? 'interrupted'
                  : 'success',
          fileName: files[i % files.length],
          fileSize: sizes[i % sizes.length],
          color: colors[i % colors.length],
        ),
    ];
  }

  List<_PPDeskSessionRecord> _ppDeskFilteredSessions(
      List<_PPDeskSessionRecord> records) {
    final search =
        _ppDeskSessionSearch.trim().toLowerCase().replaceAll(' ', '');
    return records.where((record) {
      if (_ppDeskSessionType != 'all' && record.type != _ppDeskSessionType) {
        return false;
      }
      if (_ppDeskSessionTime != 'all' && record.group != _ppDeskSessionTime) {
        return false;
      }
      if (search.isEmpty) {
        return true;
      }
      final name = _ppDeskPeerName(record.peer).toLowerCase();
      final id = record.peer.id.toLowerCase().replaceAll(' ', '');
      final file = record.fileName.toLowerCase();
      return name.contains(search) ||
          id.contains(search) ||
          file.contains(search);
    }).toList();
  }

  String _ppDeskSessionTypeLabel(String value) {
    return const {
          'all': '全部类型',
          'remote': '远程控制',
          'file': '文件传输',
        }[value] ??
        '全部类型';
  }

  String _ppDeskSessionTimeLabel(String value) {
    return const {
          'all': '全部时间',
          'today': '今天',
          'yesterday': '昨天',
          'earlier': '更早',
        }[value] ??
        '全部时间';
  }

  Widget _buildPPDeskSettingsPage({required bool compact}) {
    final tabs = DesktopSettingPage.tabKeys;
    final selected =
        tabs.contains(_ppDeskSettingTab) ? _ppDeskSettingTab : tabs.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('设置中心',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 28 : 34,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF101828))),
                  SizedBox(height: compact ? 6 : 10),
                  Text('管理账号、安全、通知与远程控制相关设置。',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 13 : 15,
                          color: const Color(0xFF66738A))),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 16 : 24),
        Expanded(
          child: Row(
            children: [
              _buildPPDeskSettingsNav(tabs, selected, compact: compact),
              SizedBox(width: compact ? 12 : 18),
              Expanded(
                child: Container(
                  decoration: _ppDeskCardDecoration(),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Expanded(
                        child: KeyedSubtree(
                          key: ValueKey(selected),
                          child: _buildPPDeskSettingsContent(selected,
                              compact: compact),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPPDeskSettingsNav(
      List<SettingsTabKey> tabs, SettingsTabKey selected,
      {required bool compact}) {
    return Container(
      width: compact ? 168 : 220,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: _ppDeskCardDecoration(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (final tab in tabs)
            _PPDeskSettingsTabItem(
              icon: _ppDeskSettingIcon(tab),
              label: _ppDeskSettingLabel(tab),
              selected: selected == tab,
              compact: compact,
              onTap: () => setState(() => _ppDeskSettingTab = tab),
            ),
        ],
      ),
    );
  }

  Widget _buildPPDeskSettingsContent(SettingsTabKey selected,
      {required bool compact}) {
    return SingleChildScrollView(
      key: PageStorageKey('ppdesk_settings_${selected.toString()}'),
      primary: false,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: switch (selected) {
        SettingsTabKey.account => _buildPPDeskAccountSettings(compact: compact),
        SettingsTabKey.general => _buildPPDeskGeneralSettings(compact: compact),
        SettingsTabKey.safety => _buildPPDeskSafetySettings(compact: compact),
        SettingsTabKey.network => _buildPPDeskNetworkSettings(compact: compact),
        SettingsTabKey.display => _buildPPDeskDisplaySettings(compact: compact),
        SettingsTabKey.plugin => _buildPPDeskPluginSettings(compact: compact),
        SettingsTabKey.printer => _buildPPDeskPrinterSettings(compact: compact),
        SettingsTabKey.about => _buildPPDeskAboutSettings(compact: compact),
      },
    );
  }

  Widget _buildPPDeskAccountSettings({required bool compact}) {
    return Obx(() {
      final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
      final userName = loggedIn ? gFFI.userModel.userName.value : 'admin';
      final displayName =
          loggedIn ? gFFI.userModel.displayNameOrUserName : 'admin';
      final handle = loggedIn ? '@${gFFI.userModel.userName.value}' : '本地管理员';
      return _PPDeskSettingsSection(
        icon: 'ppdesk_user',
        title: '账号',
        compact: compact,
        children: [
          _PPDeskAccountPanel(
            compact: compact,
            displayName: displayName,
            handle: handle,
            signedIn: loggedIn,
          ),
          _PPDeskSettingActionRow(
            icon: loggedIn ? 'ppdesk_logout' : 'ppdesk_user',
            title: loggedIn ? '退出登录' : '登录账号',
            subtitle: loggedIn ? '当前账号：$userName' : '登录后可同步设备、地址簿与审计记录',
            compact: compact,
            danger: loggedIn,
            onTap: () {
              loggedIn
                  ? ppdesk_login.logOutConfirmDialog()
                  : ppdesk_login.loginDialog();
            },
          ),
          _PPDeskSettingActionRow(
            icon: 'ppdesk_lock',
            title: '修改永久密码',
            subtitle: '用于无人值守访问的本机永久密码',
            compact: compact,
            onTap: () => setPasswordDialog(),
          ),
          _PPDeskSettingInfoRow(
            icon: 'ppdesk_shield',
            title: '认证状态',
            value: loggedIn ? '已登录' : '本地模式',
            compact: compact,
          ),
        ],
      );
    });
  }

  Widget _buildPPDeskGeneralSettings({required bool compact}) {
    final customClient = bind.isCustomClient();
    final incomingOnly = bind.isIncomingOnly();
    return Column(
      children: [
        _PPDeskSettingsSection(
          icon: 'ppdesk_settings',
          title: '基础偏好',
          compact: compact,
          children: [
            _PPDeskSettingSelectRow(
              icon: 'ppdesk_info',
              title: '语言',
              value: _ppDeskLanguageLabel(),
              subtitle: '界面语言配置',
              compact: compact,
              disabled: isOptionFixed(kCommConfKeyLang),
              onTap: _showPPDeskLanguageSelector,
            ),
            _PPDeskSettingSelectRow(
              icon: 'ppdesk_display',
              title: '主题',
              value: _ppDeskThemeLabel(),
              subtitle: '点击在浅色、深色、跟随系统之间切换',
              compact: compact,
              onTap: _cyclePPDeskTheme,
              disabled: isOptionFixed(kCommConfKeyTheme),
            ),
            if (!isWeb && !incomingOnly)
              _ppDeskOptionSwitch(
                icon: 'ppdesk_tabs',
                title: '关闭多个标签页前确认',
                subtitle: '减少误关闭远程会话的风险',
                optionKey: kOptionEnableConfirmClosingTabs,
                compact: compact,
                isServer: false,
              ),
            if (!isWeb && !incomingOnly)
              _ppDeskOptionSwitch(
                icon: 'ppdesk_plus',
                title: '新连接打开为标签页',
                subtitle: '保持多个远程连接在同一窗口管理',
                optionKey: kOptionOpenNewConnInTabs,
                compact: compact,
                isServer: false,
              ),
            if (!isWeb && !customClient)
              _ppDeskOptionSwitch(
                icon: 'ppdesk_restart',
                title: '启动时检查更新',
                subtitle: '打开客户端时自动检查新版本',
                optionKey: kOptionEnableCheckUpdate,
                compact: compact,
                isServer: false,
              ),
          ],
        ),
        SizedBox(height: compact ? 12 : 16),
        _PPDeskSettingsSection(
          icon: 'ppdesk_device',
          title: '连接体验',
          compact: compact,
          children: [
            if (!isWeb && !incomingOnly)
              _ppDeskOptionSwitch(
                icon: 'ppdesk_network',
                title: '启用 UDP 打洞',
                subtitle: '优先尝试点对点连接',
                optionKey: kOptionEnableUdpPunch,
                compact: compact,
                isServer: false,
              ),
            if (!isWeb && !incomingOnly)
              _ppDeskOptionSwitch(
                icon: 'ppdesk_network',
                title: '启用 IPv6 P2P',
                subtitle: '允许通过 IPv6 建立点对点连接',
                optionKey: kOptionEnableIpv6Punch,
                compact: compact,
                isServer: false,
              ),
            if (!bind.isIncomingOnly())
              _ppDeskOptionSwitch(
                icon: 'ppdesk_lock',
                title: '远程会话期间保持唤醒',
                subtitle: '避免连接中本机进入睡眠',
                optionKey: kOptionKeepAwakeDuringOutgoingSessions,
                compact: compact,
                isServer: false,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPPDeskSafetySettings({required bool compact}) {
    final accessMode = bind.mainGetOptionSync(key: kOptionAccessMode);
    final accessLocked = isOptionFixed(kOptionAccessMode);
    return Column(
      children: [
        _PPDeskSettingsSection(
          icon: 'ppdesk_shield',
          title: '访问权限',
          compact: compact,
          children: [
            _PPDeskSettingSelectRow(
              icon: 'ppdesk_shield',
              title: '访问模式',
              value: _ppDeskAccessModeLabel(accessMode),
              subtitle: '点击在自定义、完全访问、仅屏幕共享之间切换',
              compact: compact,
              disabled: accessLocked,
              onTap: _cyclePPDeskAccessMode,
            ),
            _ppDeskOptionSwitch(
              icon: 'ppdesk_keyboard',
              title: '允许键盘和鼠标',
              subtitle: '远端可控制本机输入',
              optionKey: kOptionEnableKeyboard,
              compact: compact,
            ),
            _ppDeskOptionSwitch(
              icon: 'ppdesk_clipboard',
              title: '允许剪贴板同步',
              subtitle: '同步文本与图片内容',
              optionKey: kOptionEnableClipboard,
              compact: compact,
            ),
            _ppDeskOptionSwitch(
              icon: 'ppdesk_folder',
              title: '允许文件传输',
              subtitle: '允许远程收发文件',
              optionKey: kOptionEnableFileTransfer,
              compact: compact,
            ),
            _ppDeskOptionSwitch(
              icon: 'ppdesk_terminal',
              title: '允许终端',
              subtitle: '允许发起远程命令行会话',
              optionKey: kOptionEnableTerminal,
              compact: compact,
            ),
            _ppDeskOptionSwitch(
              icon: 'ppdesk_restart',
              title: '允许远程重启',
              subtitle: '允许远端请求重启本机',
              optionKey: kOptionEnableRemoteRestart,
              compact: compact,
            ),
          ],
        ),
        SizedBox(height: compact ? 12 : 16),
        _PPDeskSettingsSection(
          icon: 'ppdesk_lock',
          title: '认证与保护',
          compact: compact,
          children: [
            _PPDeskSettingActionRow(
              icon: 'ppdesk_lock',
              title: '设置永久密码',
              subtitle: '配置无人值守访问密码',
              compact: compact,
              onTap: () => setPasswordDialog(),
            ),
            _PPDeskSettingActionRow(
              icon: 'ppdesk_restart',
              title: '刷新一次性密码',
              subtitle: '立即生成新的临时访问密码',
              compact: compact,
              onTap: () => bind.mainUpdateTemporaryPassword(),
            ),
            _PPDeskSettingActionRow(
              icon: 'ppdesk_shield',
              title: '两步验证',
              subtitle: '配置账号二次验证',
              compact: compact,
              onTap: () => ppdesk_dialogs.change2fa(callback: () {
                if (mounted) setState(() {});
              }),
            ),
            _PPDeskSettingActionRow(
              icon: 'ppdesk_device',
              title: '受信任设备',
              subtitle: '管理已授权的设备列表',
              compact: compact,
              onTap: ppdesk_dialogs.manageTrustedDeviceDialog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPPDeskNetworkSettings({required bool compact}) {
    final hideServer =
        bind.mainGetBuildinOption(key: kOptionHideServerSetting) == 'Y';
    final hideProxy =
        isWeb || bind.mainGetBuildinOption(key: kOptionHideProxySetting) == 'Y';
    final hideWebSocket = isWeb ||
        bind.mainGetBuildinOption(key: kOptionHideWebSocketSetting) == 'Y';
    return _PPDeskSettingsSection(
      icon: 'ppdesk_network',
      title: '网络与服务器',
      compact: compact,
      children: [
        if (!hideServer)
          _PPDeskSettingActionRow(
            icon: 'ppdesk_server',
            title: 'ID / Relay / API 服务器',
            subtitle: '配置自有 PPDesk 服务器地址与公钥',
            compact: compact,
            onTap: () => ppdesk_mobile_dialogs.showServerSettings(
                gFFI.dialogManager, setState),
          ),
        if (!hideProxy)
          _PPDeskSettingActionRow(
            icon: 'ppdesk_network',
            title: 'Socks5 / HTTP(S) 代理',
            subtitle: '配置客户端网络代理',
            compact: compact,
            onTap: changeSocks5Proxy,
          ),
        if (!hideWebSocket)
          _ppDeskOptionSwitch(
            icon: 'ppdesk_network',
            title: '使用 WebSocket',
            subtitle: '兼容受限网络环境下的服务连接',
            optionKey: kOptionAllowWebSocket,
            compact: compact,
          ),
        if (!isWeb)
          _ppDeskOptionSwitch(
            icon: 'ppdesk_shield',
            title: '允许不安全 TLS 回退',
            subtitle: '仅在自有网络兼容场景下使用',
            optionKey: kOptionAllowInsecureTLSFallback,
            compact: compact,
          ),
        if (!isWeb && !bind.isOutgoingOnly())
          _PPDeskSettingSwitchRow(
            icon: 'ppdesk_network',
            title: '禁用 UDP',
            subtitle: '强制连接走 TCP 中继路径',
            value: bind.mainGetOptionSync(key: kOptionDisableUdp) == 'Y',
            compact: compact,
            enabled: !isOptionFixed(kOptionDisableUdp),
            onChanged: (value) async {
              await bind.mainSetOption(
                  key: kOptionDisableUdp, value: value ? 'Y' : 'N');
              if (mounted) setState(() {});
            },
          ),
      ],
    );
  }

  Widget _buildPPDeskDisplaySettings({required bool compact}) {
    return Column(
      children: [
        _PPDeskSettingsSection(
          icon: 'ppdesk_display',
          title: '远程显示默认值',
          compact: compact,
          children: [
            _PPDeskSettingSelectRow(
              icon: 'ppdesk_display',
              title: '视图样式',
              value: _ppDeskUserDefaultLabel(kOptionViewStyle),
              subtitle: '远程桌面默认显示模式',
              compact: compact,
              disabled: isOptionFixed(kOptionViewStyle),
              onTap: () => _showPPDeskUserDefaultSelector(
                title: '视图样式',
                optionKey: kOptionViewStyle,
                options: const [
                  ('原始比例', kRemoteViewStyleOriginal),
                  ('自适应缩放', kRemoteViewStyleAdaptive),
                ],
              ),
            ),
            _PPDeskSettingSelectRow(
              icon: 'ppdesk_scroll',
              title: '滚动方式',
              value: _ppDeskUserDefaultLabel(kOptionScrollStyle),
              subtitle: '远程控制中的滚动行为',
              compact: compact,
              disabled: isOptionFixed(kOptionScrollStyle),
              onTap: () => _showPPDeskUserDefaultSelector(
                title: '滚动方式',
                optionKey: kOptionScrollStyle,
                options: [
                  ('自动滚动', kRemoteScrollStyleAuto),
                  ('滚动条', kRemoteScrollStyleBar),
                  if (!isWeb) ('边缘滚动', kRemoteScrollStyleEdge),
                ],
              ),
            ),
            _PPDeskSettingSelectRow(
              icon: 'ppdesk_image',
              title: '图像质量',
              value: _ppDeskUserDefaultLabel(kOptionImageQuality),
              subtitle: '画质与流畅度的默认策略',
              compact: compact,
              disabled: isOptionFixed(kOptionImageQuality),
              onTap: () => _showPPDeskUserDefaultSelector(
                title: '图像质量',
                optionKey: kOptionImageQuality,
                options: const [
                  ('优先画质', kRemoteImageQualityBest),
                  ('平衡', kRemoteImageQualityBalanced),
                  ('速度最优化', kRemoteImageQualityLow),
                  ('自定义', kRemoteImageQualityCustom),
                ],
                keepOpenValue: kRemoteImageQualityCustom,
                tailBuilder: (_) => customImageQualitySetting(),
              ),
            ),
            _PPDeskSettingSelectRow(
              icon: 'ppdesk_codec',
              title: '编解码偏好',
              value: _ppDeskUserDefaultLabel(kOptionCodecPreference),
              subtitle: '会话视频编解码默认选择',
              compact: compact,
              disabled: isOptionFixed(kOptionCodecPreference),
              onTap: () => _showPPDeskUserDefaultSelector(
                title: '编解码偏好',
                optionKey: kOptionCodecPreference,
                options: _ppDeskCodecOptions(),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 12 : 16),
        _PPDeskSettingsSection(
          icon: 'ppdesk_clipboard',
          title: '会话体验',
          compact: compact,
          children: [
            _PPDeskSettingSwitchRow(
              icon: 'ppdesk_clipboard',
              title: '文件复制粘贴',
              subtitle: '允许在会话中复制粘贴文件',
              value: bind.mainGetUserDefaultOption(
                      key: kOptionEnableFileCopyPaste) ==
                  'Y',
              compact: compact,
              enabled: !isOptionFixed(kOptionEnableFileCopyPaste),
              onChanged: (value) async {
                await bind.mainSetUserDefaultOption(
                    key: kOptionEnableFileCopyPaste, value: value ? 'Y' : 'N');
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPPDeskPluginSettings({required bool compact}) {
    return _PPDeskSettingsSection(
      icon: 'ppdesk_folder',
      title: '插件',
      compact: compact,
      children: [
        _PPDeskSettingInfoRow(
          icon: 'ppdesk_info',
          title: '插件能力',
          value: bind.pluginFeatureIsEnabled() ? '已启用' : '未启用',
          compact: compact,
        ),
        _PPDeskSettingActionRow(
          icon: 'ppdesk_folder',
          title: '插件管理',
          subtitle: '当前客户端未接入 PPDesk 插件市场 UI',
          compact: compact,
          onTap: () => showToast('插件管理入口待接入'),
        ),
      ],
    );
  }

  Widget _buildPPDeskPrinterSettings({required bool compact}) {
    return _PPDeskSettingsSection(
      icon: 'ppdesk_file',
      title: '远程打印',
      compact: compact,
      children: [
        _ppDeskOptionSwitch(
          icon: 'ppdesk_file',
          title: '允许远程打印',
          subtitle: '允许远程会话访问打印能力',
          optionKey: kOptionEnableRemotePrinter,
          compact: compact,
          enabled: isWindows,
        ),
        _PPDeskSettingInfoRow(
          icon: 'ppdesk_info',
          title: '当前平台',
          value: isWindows ? 'Windows 支持远程打印' : '当前平台暂不支持远程打印配置',
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildPPDeskAboutSettings({required bool compact}) {
    return FutureBuilder<String>(
      future: bind.mainGetVersion(),
      builder: (context, snapshot) {
        final versionText = snapshot.data ?? version;
        return _PPDeskSettingsSection(
          icon: 'ppdesk_info',
          title: '关于 PPDesk',
          compact: compact,
          children: [
            _PPDeskSettingInfoRow(
              icon: 'ppdesk_logo',
              title: '产品名称',
              value: 'PP·Desk / 皮皮远程',
              compact: compact,
            ),
            _PPDeskSettingInfoRow(
              icon: 'ppdesk_info',
              title: '当前版本',
              value: versionText.isEmpty ? '读取中' : versionText,
              compact: compact,
            ),
            _PPDeskSettingInfoRow(
              icon: 'ppdesk_server',
              title: '底层能力',
              value: '跟随 RustDesk 客户端能力层',
              compact: compact,
            ),
            _PPDeskSettingActionRow(
              icon: 'ppdesk_book',
              title: '开源协议与说明',
              subtitle: '查看客户端依赖与上游说明',
              compact: compact,
              onTap: () => showToast('开源说明页待接入'),
            ),
          ],
        );
      },
    );
  }

  Widget _ppDeskOptionSwitch({
    required String icon,
    required String title,
    required String subtitle,
    required String optionKey,
    required bool compact,
    bool isServer = true,
    bool reverse = false,
    bool enabled = true,
  }) {
    bool value = isServer
        ? mainGetBoolOptionSync(optionKey)
        : mainGetLocalBoolOptionSync(optionKey);
    if (reverse) value = !value;
    return _PPDeskSettingSwitchRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      compact: compact,
      enabled: enabled && !isOptionFixed(optionKey),
      onChanged: (next) async {
        final stored = reverse ? !next : next;
        if (isServer) {
          await mainSetBoolOption(optionKey, stored);
        } else {
          await mainSetLocalBoolOption(optionKey, stored);
        }
        if (mounted) setState(() {});
      },
    );
  }

  String _ppDeskLanguageLabel() {
    final lang = bind.mainGetLocalOption(key: kCommConfKeyLang);
    if (lang.isEmpty || lang == defaultOptionLang) {
      return '跟随系统';
    }
    return _ppDeskLangLabels[lang] ?? lang;
  }

  String _ppDeskThemeLabel() {
    return switch (MyTheme.getThemeModePreference().toShortString()) {
      'light' => '浅色',
      'dark' => '深色',
      _ => '跟随系统',
    };
  }

  Future<void> _cyclePPDeskTheme() async {
    if (isOptionFixed(kCommConfKeyTheme)) return;
    final current = MyTheme.getThemeModePreference().toShortString();
    final next = switch (current) {
      'light' => 'dark',
      'dark' => 'system',
      _ => 'light',
    };
    await MyTheme.changeDarkMode(MyTheme.themeModeFromString(next));
    if (mounted) setState(() {});
  }

  String _ppDeskAccessModeLabel(String mode) {
    return switch (mode) {
      'full' => '完全访问',
      'view' => '仅屏幕共享',
      _ => '自定义',
    };
  }

  Future<void> _cyclePPDeskAccessMode() async {
    if (isOptionFixed(kOptionAccessMode)) return;
    final current = bind.mainGetOptionSync(key: kOptionAccessMode);
    final next = current == defaultOptionAccessMode || current.isEmpty
        ? 'full'
        : current == 'full'
            ? 'view'
            : defaultOptionAccessMode;
    await bind.mainSetOption(key: kOptionAccessMode, value: next);
    if (mounted) setState(() {});
  }

  Future<void> _showPPDeskLanguageSelector() async {
    if (isOptionFixed(kCommConfKeyLang)) return;
    final langs = jsonDecode(await bind.mainGetLangs()) as List<dynamic>;
    final options = <(String, String)>[
      ('跟随系统', defaultOptionLang),
      ...langs.map((e) {
        final row = e as List<dynamic>;
        return (row[1] as String, row[0] as String);
      }),
    ];
    _ppDeskLangLabels
      ..clear()
      ..addEntries(options.map((e) => MapEntry(e.$2, e.$1)));
    var selected = bind.mainGetLocalOption(key: kCommConfKeyLang);
    if (!options.any((e) => e.$2 == selected)) {
      selected = defaultOptionLang;
    }
    await _showPPDeskSelectorDialog(
      title: '语言',
      selectedValue: selected,
      options: options,
      onSelected: (value) async {
        await bind.mainSetLocalOption(key: kCommConfKeyLang, value: value);
        if (isWeb) {
          reloadCurrentWindow();
        } else {
          reloadAllWindows();
          bind.mainChangeLanguage(lang: value);
        }
      },
    );
  }

  Future<void> _showPPDeskUserDefaultSelector({
    required String title,
    required String optionKey,
    required List<(String, String)> options,
    String? keepOpenValue,
    Widget Function(String selected)? tailBuilder,
  }) async {
    if (isOptionFixed(optionKey)) return;
    var selected = bind.mainGetUserDefaultOption(key: optionKey);
    if (!options.any((e) => e.$2 == selected)) {
      selected = options.first.$2;
    }
    await _showPPDeskSelectorDialog(
      title: title,
      selectedValue: selected,
      options: options,
      keepOpenValue: keepOpenValue,
      tailBuilder: tailBuilder,
      onSelected: (value) async {
        await bind.mainSetUserDefaultOption(key: optionKey, value: value);
      },
    );
  }

  Future<void> _showPPDeskSelectorDialog({
    required String title,
    required String selectedValue,
    required List<(String, String)> options,
    required Future<void> Function(String value) onSelected,
    String? keepOpenValue,
    Widget Function(String selected)? tailBuilder,
  }) async {
    var selected = selectedValue;
    await gFFI.dialogManager.show((dialogSetState, close, context) {
      Future<void> choose(String value) async {
        selected = value;
        await onSelected(value);
        if (mounted) setState(() {});
        dialogSetState(() {});
        if (value != keepOpenValue) close();
      }

      return CustomAlertDialog(
        title: _ppdeskDialogTitle(icon: Icons.tune_rounded, text: title),
        contentBoxConstraints: const BoxConstraints(maxWidth: 440),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...options.map((e) => _ppDeskSelectorTile(
                  label: e.$1,
                  selected: selected == e.$2,
                  onTap: () => choose(e.$2),
                )),
            if (tailBuilder != null && selected == keepOpenValue)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDCE6F4)),
                ),
                child: tailBuilder(selected),
              ),
          ],
        ),
        actions: [
          dialogButton('Close', onPressed: close, isOutline: true),
        ],
        onCancel: close,
      );
    });
  }

  Widget _ppDeskSelectorTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF0FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF2D6BFF)
                        : const Color(0xFF101828),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded,
                    color: Color(0xFF2D6BFF), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  List<(String, String)> _ppDeskCodecOptions() {
    final options = <(String, String)>[
      ('自动', 'auto'),
      ('VP8', 'vp8'),
      ('VP9', 'vp9'),
      ('AV1', 'av1'),
    ];
    try {
      final codecs = jsonDecode(bind.mainSupportedHwdecodings()) as Map;
      if (codecs['h264'] == true) options.add(('H264', 'h264'));
      if (codecs['h265'] == true) options.add(('H265', 'h265'));
    } catch (e) {
      debugPrint('failed to parse supported hwdecodings, err=$e');
    }
    return options;
  }

  String _ppDeskUserDefaultLabel(String key) {
    final value = bind.mainGetUserDefaultOption(key: key);
    if (value.isEmpty ||
        value == defaultOptionNo ||
        value == defaultOptionYes) {
      return '默认';
    }
    return _ppDeskUserDefaultValueLabel(key, value);
  }

  String _ppDeskUserDefaultValueLabel(String key, String value) {
    if (key == kOptionViewStyle) {
      return switch (value) {
        kRemoteViewStyleOriginal => '原始比例',
        kRemoteViewStyleAdaptive => '自适应缩放',
        _ => value,
      };
    }
    if (key == kOptionScrollStyle) {
      return switch (value) {
        kRemoteScrollStyleAuto => '自动滚动',
        kRemoteScrollStyleBar => '滚动条',
        kRemoteScrollStyleEdge => '边缘滚动',
        _ => value,
      };
    }
    if (key == kOptionImageQuality) {
      return switch (value) {
        kRemoteImageQualityBest => '优先画质',
        kRemoteImageQualityBalanced => '平衡',
        kRemoteImageQualityLow => '速度最优化',
        kRemoteImageQualityCustom => '自定义',
        _ => value,
      };
    }
    if (key == kOptionCodecPreference) {
      return switch (value) {
        'auto' => '自动',
        'vp8' => 'VP8',
        'vp9' => 'VP9',
        'av1' => 'AV1',
        'h264' => 'H264',
        'h265' => 'H265',
        _ => value,
      };
    }
    return value;
  }

  String _ppDeskSettingLabel(SettingsTabKey tab) {
    return switch (tab) {
      SettingsTabKey.account => '账号信息',
      SettingsTabKey.general => '常规设置',
      SettingsTabKey.safety => '安全设置',
      SettingsTabKey.network => '网络设置',
      SettingsTabKey.display => '显示设置',
      SettingsTabKey.plugin => '插件设置',
      SettingsTabKey.printer => '打印设置',
      SettingsTabKey.about => '关于我们',
    };
  }

  String _ppDeskSettingIcon(SettingsTabKey tab) {
    return switch (tab) {
      SettingsTabKey.account => 'ppdesk_user',
      SettingsTabKey.general => 'ppdesk_settings',
      SettingsTabKey.safety => 'ppdesk_shield',
      SettingsTabKey.network => 'ppdesk_toolbox',
      SettingsTabKey.display => 'ppdesk_device',
      SettingsTabKey.plugin => 'ppdesk_folder',
      SettingsTabKey.printer => 'ppdesk_file',
      SettingsTabKey.about => 'ppdesk_info',
    };
  }

  Widget _buildPPDeskToolboxPage({required bool compact}) {
    final tools = [
      _PPDeskToolSpec(
          icon: 'ppdesk_folder',
          title: '文件传输',
          subtitle: '快速收发文件到远程设备',
          color: const Color(0xFF2D6BFF),
          onTap: () => _ppDeskConnect(isFileTransfer: true)),
      _PPDeskToolSpec(
          icon: 'ppdesk_clipboard',
          title: '剪贴板同步',
          subtitle: '同步文本与图片内容',
          color: const Color(0xFF7C3CFF),
          onTap: () => setState(() {
                _ppDeskPage = 3;
                _ppDeskSettingTab = SettingsTabKey.safety;
              })),
      _PPDeskToolSpec(
          icon: 'ppdesk_crop',
          title: '屏幕截图',
          subtitle: '截取远程屏幕并保存',
          color: const Color(0xFF20C66B),
          onTap: () => showToast('请在远程会话工具栏中使用屏幕截图')),
      _PPDeskToolSpec(
          icon: 'ppdesk_terminal',
          title: 'CMD/终端',
          subtitle: '远程执行命令行操作',
          color: const Color(0xFFFF9500),
          onTap: () => _ppDeskConnect(isTerminal: true)),
      _PPDeskToolSpec(
          icon: 'ppdesk_restart',
          title: '远程重启',
          subtitle: '快速重启目标设备',
          color: const Color(0xFF2D6BFF),
          onTap: () => showToast('连接后可在会话工具栏重启远程设备')),
      _PPDeskToolSpec(
          icon: 'ppdesk_lock',
          title: '锁定设备',
          subtitle: '一键锁屏保护远程设备',
          color: const Color(0xFF7C3CFF),
          onTap: () => showToast('连接后可在会话工具栏锁定远程设备')),
      _PPDeskToolSpec(
          icon: 'ppdesk_file',
          title: '日志导出',
          subtitle: '导出连接与操作记录',
          color: const Color(0xFF20C66B),
          onTap: () => setState(() => _ppDeskPage = 2)),
      _PPDeskToolSpec(
          icon: 'ppdesk_stack',
          title: '批量操作',
          subtitle: '多设备统一执行任务',
          color: const Color(0xFFFF9500),
          onTap: () => setState(() => _ppDeskPage = 1)),
    ];
    final recent = [tools[0], tools[1], tools[3], tools[2]];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('工具箱',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 28 : 34,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF101828))),
                  SizedBox(height: compact ? 6 : 10),
                  Text('常用远程辅助工具与快捷操作入口。',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 13 : 15,
                          color: const Color(0xFF66738A))),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 16 : 24),
        Expanded(
          child: SingleChildScrollView(
            key: const PageStorageKey('ppdesk_toolbox_scroll'),
            primary: false,
            child: Column(
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth < 700 ? 2 : 4;
                  return GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tools.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: compact ? 12 : 18,
                      mainAxisSpacing: compact ? 12 : 18,
                      childAspectRatio: compact ? 1.36 : 1.05,
                    ),
                    itemBuilder: (_, index) => _PPDeskToolCard(
                      tool: tools[index],
                      compact: compact,
                    ),
                  );
                }),
                SizedBox(height: compact ? 14 : 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        flex: 5,
                        child:
                            _buildPPDeskRecentTools(recent, compact: compact)),
                    SizedBox(width: compact ? 12 : 18),
                    Expanded(
                        flex: 4,
                        child: _buildPPDeskSafetyTip(compact: compact)),
                  ],
                ),
                SizedBox(height: compact ? 14 : 22),
                _buildPPDeskHelpBar(compact: compact),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPPDeskRecentTools(List<_PPDeskToolSpec> tools,
      {required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: _ppDeskCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('最近使用',
                  style: TextStyle(
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF101828))),
              const Spacer(),
              InkWell(
                onTap: () => showToast('最近使用会根据操作频率自动更新'),
                borderRadius: BorderRadius.circular(8),
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                focusColor: Colors.transparent,
                child: Row(
                  children: [
                    const Text('管理',
                        style: TextStyle(
                            color: Color(0xFF66738A),
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    _ppDeskSvg('ppdesk_settings',
                        color: const Color(0xFF66738A), size: 16),
                  ],
                ).paddingSymmetric(horizontal: 8, vertical: 6),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 16),
          Row(
            children: [
              for (var i = 0; i < tools.length; i++) ...[
                Expanded(
                  child: _PPDeskRecentToolCard(
                    tool: tools[i],
                    subtitle: ['刚刚使用', '5 分钟前', '12 小时前', '1 小时前'][i],
                    compact: compact,
                  ),
                ),
                if (i != tools.length - 1) SizedBox(width: compact ? 8 : 12),
              ],
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          Row(
            children: [
              _ppDeskSvg('ppdesk_clock',
                  color: const Color(0xFF66738A), size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('提示：工具会根据使用频率自动更新',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Color(0xFF66738A))),
              ),
              InkWell(
                onTap: () => showToast('已清空本次显示记录'),
                borderRadius: BorderRadius.circular(8),
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                focusColor: Colors.transparent,
                child: Row(
                  children: [
                    const Text('清空记录',
                        style: TextStyle(
                            color: Color(0xFF2D6BFF),
                            fontWeight: FontWeight.w700)),
                    _ppDeskSvg('ppdesk_chevron_right',
                        color: const Color(0xFF2D6BFF), size: 16),
                  ],
                ).paddingSymmetric(horizontal: 8, vertical: 6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPPDeskSafetyTip({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: _ppDeskCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('安全提示',
              style: TextStyle(
                  fontSize: compact ? 15 : 17,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF101828))),
          SizedBox(height: compact ? 12 : 18),
          Container(
            padding: EdgeInsets.all(compact ? 14 : 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCE8FF)),
            ),
            child: Row(
              children: [
                Container(
                  width: compact ? 52 : 66,
                  height: compact ? 52 : 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _ppDeskSvg('ppdesk_shield',
                      color: const Color(0xFF2D6BFF), size: compact ? 30 : 36),
                ),
                SizedBox(width: compact ? 12 : 18),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('安全连接，放心使用',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF101828))),
                      SizedBox(height: 8),
                      Text('所有连接均采用端到端加密传输，请勿在远程设备上处理敏感信息。',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF66738A))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          InkWell(
            onTap: () => setState(() {
              _ppDeskPage = 3;
              _ppDeskSettingTab = SettingsTabKey.safety;
            }),
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: Row(
              children: [
                const Text('了解更多安全设置',
                    style: TextStyle(
                        color: Color(0xFF2D6BFF), fontWeight: FontWeight.w800)),
                _ppDeskSvg('ppdesk_chevron_right',
                    color: const Color(0xFF2D6BFF), size: 16),
              ],
            ).paddingSymmetric(horizontal: 8, vertical: 6),
          ),
        ],
      ),
    );
  }

  Widget _buildPPDeskHelpBar({required bool compact}) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 22, vertical: compact ? 12 : 16),
      decoration: _ppDeskCardDecoration(),
      child: Row(
        children: [
          _ppDeskSvg('ppdesk_headset',
              color: const Color(0xFF2D6BFF), size: compact ? 24 : 28),
          SizedBox(width: compact ? 12 : 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('使用帮助',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828))),
                SizedBox(height: 4),
                Text('遇到问题？查看帮助文档或联系客服获取支持。',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Color(0xFF66738A))),
              ],
            ),
          ),
          _PPDeskHelpAction(
              icon: 'ppdesk_book',
              label: '帮助文档',
              onTap: () => showToast('帮助文档待接入')),
          _PPDeskHelpAction(
              icon: 'ppdesk_play',
              label: '视频教程',
              onTap: () => showToast('视频教程待接入')),
          _PPDeskHelpAction(
              icon: 'ppdesk_headset',
              label: '联系客服',
              onTap: () => showToast('客服入口待接入')),
        ],
      ),
    );
  }

  Widget _buildPPDeskQuickConnect(BuildContext context,
      {required bool compact}) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 18 : 26, compact ? 14 : 24,
          compact ? 18 : 26, compact ? 14 : 24),
      decoration: _ppDeskCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('快速连接',
              style: TextStyle(
                  fontSize: compact ? 18 : 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF101828))),
          SizedBox(height: compact ? 3 : 6),
          Text('输入设备 ID，发起远程连接',
              style: TextStyle(
                  fontSize: compact ? 12 : 13, color: const Color(0xFF7C8AA5))),
          SizedBox(height: compact ? 10 : 18),
          Row(
            children: [
              Expanded(
                  child: _buildPPDeskRemoteIdField(context, compact: compact)),
              SizedBox(width: compact ? 14 : 26),
              _PPDeskPrimaryButton(
                label: translate('Connect'),
                compact: compact,
                onTap: () => _ppDeskConnect(),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 18),
          Row(
            children: [
              Expanded(
                child: _PPDeskActionTile(
                  icon: 'ppdesk_device',
                  title: '远程控制',
                  subtitle: '控制远程设备',
                  compact: compact,
                  onTap: () => _ppDeskConnect(),
                ),
              ),
              SizedBox(width: compact ? 14 : 22),
              Expanded(
                child: _PPDeskActionTile(
                  icon: 'ppdesk_folder',
                  title: '文件传输',
                  subtitle: '传输文件',
                  compact: compact,
                  onTap: () => _ppDeskConnect(isFileTransfer: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPPDeskRemoteIdField(BuildContext context,
      {required bool compact}) {
    return Obx(() {
      final focused = _ppDeskIdFocused.value;
      return Container(
        height: compact ? 46 : 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  focused ? const Color(0xFF2D6BFF) : const Color(0xFFD8E1EF),
              width: focused ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 4),
              child: _ppDeskSvg('ppdesk_device',
                  color: const Color(0xFF66738A), size: compact ? 18 : 22),
            ),
            Expanded(
              child: RawAutocomplete<Peer>(
                optionsBuilder: (TextEditingValue value) {
                  if (value.text == '') {
                    _ppDeskAutocompleteOpts = const Iterable<Peer>.empty();
                  } else if (_ppDeskAllPeersLoader.peers.isEmpty &&
                      !_ppDeskAllPeersLoader.isPeersLoaded) {
                    _ppDeskAutocompleteOpts = [
                      Peer(
                        id: '',
                        username: '',
                        hostname: '',
                        alias: '',
                        platform: '',
                        tags: [],
                        hash: '',
                        password: '',
                        forceAlwaysRelay: false,
                        rdpPort: '',
                        rdpUsername: '',
                        loginName: '',
                        device_group_name: '',
                        note: '',
                      )
                    ];
                  } else {
                    var text = value.text.replaceAll(' ', '');
                    if (int.tryParse(text) == null) {
                      text = value.text.toLowerCase();
                    }
                    _ppDeskAutocompleteOpts = _ppDeskAllPeersLoader.peers
                        .where((peer) =>
                            peer.id.toLowerCase().contains(text) ||
                            peer.username.toLowerCase().contains(text) ||
                            peer.hostname.toLowerCase().contains(text) ||
                            peer.alias.toLowerCase().contains(text))
                        .toList();
                    _ppDeskAllPeersLoader.queryOnlines(_ppDeskAutocompleteOpts);
                  }
                  return _ppDeskAutocompleteOpts;
                },
                focusNode: _ppDeskIdFocusNode,
                textEditingController: _ppDeskTextController,
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  final text = _ppDeskIdController.text;
                  final targetValue = TextEditingValue(
                    text: text,
                    selection: TextSelection.collapsed(offset: text.length),
                    composing: TextRange.empty,
                  );
                  if (controller.value.text != text ||
                      !controller.value.selection.isCollapsed ||
                      controller.value.composing.isValid) {
                    controller.value = targetValue;
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final currentText = controller.value.text;
                    if (!controller.value.selection.isCollapsed ||
                        controller.value.composing.isValid) {
                      controller.value = TextEditingValue(
                        text: currentText,
                        selection:
                            TextSelection.collapsed(offset: currentText.length),
                        composing: TextRange.empty,
                      );
                    }
                  });
                  return TextSelectionTheme(
                    data: const TextSelectionThemeData(
                      cursorColor: Color(0xFF2D6BFF),
                      selectionColor: Color(0x222D6BFF),
                      selectionHandleColor: Color(0xFF2D6BFF),
                    ),
                    child: ColoredBox(
                      color: Colors.white,
                      child: TextField(
                        autocorrect: false,
                        enableSuggestions: false,
                        enableInteractiveSelection: false,
                        keyboardType: TextInputType.visiblePassword,
                        focusNode: focusNode,
                        controller: controller,
                        inputFormatters: [IDTextInputFormatter()],
                        cursorColor: const Color(0xFF2D6BFF),
                        style: TextStyle(
                            fontSize: compact ? 16 : 18,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF101828)),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          hoverColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          hintText: '请输入设备 ID',
                          hintStyle: const TextStyle(
                              color: Color(0xFFA1AEC2), fontSize: 16),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: compact ? 12 : 18),
                        ),
                        onChanged: (v) => _ppDeskIdController.id = v,
                        onSubmitted: (_) => _ppDeskConnect(),
                      ).workaroundFreezeLinuxMint(),
                    ),
                  );
                },
                onSelected: (peer) {
                  setState(() {
                    _ppDeskIdController.id = peer.id;
                    FocusScope.of(context).unfocus();
                  });
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final opts = _ppDeskAutocompleteOpts;
                  final maxHeight = (opts.length * 62.0).clamp(70.0, 240.0);
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: BoxConstraints(
                            maxHeight: maxHeight, minWidth: 420, maxWidth: 560),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE1E8F4)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _ppDeskAllPeersLoader.peers.isEmpty &&
                                !_ppDeskAllPeersLoader.isPeersLoaded
                            ? const SizedBox(
                                height: 72,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)))
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: opts.length,
                                separatorBuilder: (_, __) => const Divider(
                                    height: 1, color: Color(0xFFE8EEF8)),
                                itemBuilder: (_, index) {
                                  final peer = opts.elementAt(index);
                                  return _PPDeskAutocompleteRow(
                                    peer: peer,
                                    compact: compact,
                                    onTap: () => onSelected(peer),
                                  );
                                },
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _PPDeskMoreMenu(
              compact: compact,
              menuWidth: compact ? 132 : 148,
              customButton: Container(
                width: 56,
                height: compact ? 46 : 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Color(0xFFE4EAF4))),
                ),
                child: _ppDeskSvg('ppdesk_chevron_down',
                    color: const Color(0xFF66738A), size: 20),
              ),
              onSelected: (value) {
                if (value == 'file') {
                  _ppDeskConnect(isFileTransfer: true);
                } else if (value == 'camera') {
                  _ppDeskConnect(isViewCamera: true);
                } else if (value == 'terminal') {
                  _ppDeskConnect(isTerminal: true);
                }
              },
              actions: [
                _PPDeskMenuAction('file', translate('Transfer file')),
                _PPDeskMenuAction('camera', translate('View camera')),
                _PPDeskMenuAction(
                    'terminal', '${translate('Terminal')} (beta)'),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPPDeskStats({required bool compact}) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        gFFI.recentPeersModel,
        gFFI.favoritePeersModel,
        gFFI.lanPeersModel,
      ]),
      builder: (context, _) {
        final recent = gFFI.recentPeersModel.peers;
        final favorites = gFFI.favoritePeersModel.peers;
        final online = {
          ...recent.where((p) => p.online).map((p) => p.id),
          ...favorites.where((p) => p.online).map((p) => p.id),
          ...gFFI.lanPeersModel.peers.where((p) => p.online).map((p) => p.id),
        }.length;
        return Row(
          children: [
            Expanded(
              child: _PPDeskStatCard(
                icon: 'ppdesk_device',
                color: const Color(0xFF2D6BFF),
                title: '我的设备',
                value: '${recent.length}',
                subtitle: '最近连接设备',
                compact: compact,
              ),
            ),
            SizedBox(width: compact ? 12 : 20),
            Expanded(
              child: _PPDeskStatCard(
                icon: 'ppdesk_device',
                color: const Color(0xFF20C66B),
                title: '在线设备',
                value: '$online',
                subtitle: '当前在线设备',
                compact: compact,
              ),
            ),
            SizedBox(width: compact ? 12 : 20),
            Expanded(
              child: _PPDeskStatCard(
                icon: 'ppdesk_clock',
                color: const Color(0xFF7C3CFF),
                title: '最近会话',
                value: '${recent.length}',
                subtitle: '连接记录',
                compact: compact,
              ),
            ),
            SizedBox(width: compact ? 12 : 20),
            Expanded(
              child: _PPDeskStatCard(
                icon: 'ppdesk_star',
                color: const Color(0xFFFFA321),
                title: '收藏设备',
                value: '${favorites.length}',
                subtitle: '已收藏的设备',
                compact: compact,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPPDeskRecentCard({required bool compact}) {
    return AnimatedBuilder(
      animation: gFFI.recentPeersModel,
      builder: (context, _) {
        final peers = gFFI.recentPeersModel.peers.take(8).toList();
        return Container(
          padding: EdgeInsets.fromLTRB(
              compact ? 16 : 22, compact ? 14 : 20, compact ? 16 : 22, 8),
          decoration: _ppDeskCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('最近连接',
                      style: TextStyle(
                          fontSize: compact ? 17 : 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF101828))),
                  const Spacer(),
                  InkWell(
                    onTap: () => setState(() => _ppDeskPage = 2),
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    child: Row(
                      children: [
                        const Text('查看全部',
                            style: TextStyle(
                                color: Color(0xFF2D6BFF),
                                fontWeight: FontWeight.w700)),
                        _ppDeskSvg('ppdesk_chevron_right',
                            color: const Color(0xFF2D6BFF), size: 18),
                      ],
                    ).paddingSymmetric(horizontal: 8, vertical: 6),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 14),
              _buildPPDeskRecentHeader(compact: compact),
              const SizedBox(height: 4),
              Expanded(
                child: peers.isEmpty
                    ? Center(
                        child: Text('暂无最近连接',
                            style: TextStyle(
                                fontSize: compact ? 13 : 14,
                                color: const Color(0xFF7C8AA5))),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: peers.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFE8EEF8)),
                        itemBuilder: (_, index) => _PPDeskRecentRow(
                          peer: peers[index],
                          compact: compact,
                          onConnect: () {
                            _ppDeskIdController.id = peers[index].id;
                            _ppDeskConnect();
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPPDeskRecentHeader({required bool compact}) {
    final style = TextStyle(
        fontSize: compact ? 12 : 13,
        color: const Color(0xFF7C8AA5),
        fontWeight: FontWeight.w700);
    return Container(
      height: compact ? 34 : 40,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(width: compact ? 42 : 48),
          Expanded(flex: 4, child: Text('设备名称', style: style)),
          Expanded(flex: 3, child: Text('设备 ID', style: style)),
          Expanded(flex: 2, child: Text('平台', style: style)),
          Expanded(flex: 2, child: Text('状态', style: style)),
          SizedBox(width: compact ? 46 : 58, child: Text('操作', style: style)),
        ],
      ),
    );
  }

  BoxDecoration _ppDeskCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE1E8F4)),
    );
  }

  Widget _ppDeskSvg(String icon, {required Color color, double size = 22}) {
    return SvgPicture.asset(
      'assets/$icon.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  void _ppDeskConnect({
    bool isFileTransfer = false,
    bool isViewCamera = false,
    bool isTerminal = false,
  }) {
    connect(
      context,
      _ppDeskIdController.id,
      isFileTransfer: isFileTransfer,
      isViewCamera: isViewCamera,
      isTerminal: isTerminal,
    );
  }

  void _onPPDeskIdFocusChanged() {
    _ppDeskIdFocused.value = _ppDeskIdFocusNode.hasFocus;
    if (_ppDeskIdFocusNode.hasFocus) {
      if (_ppDeskAllPeersLoader.needLoad) {
        _ppDeskAllPeersLoader.getAllPeers();
      }
      final textLength = _ppDeskTextController.value.text.length;
      _ppDeskTextController.selection =
          TextSelection.collapsed(offset: textLength);
    }
  }

  Widget buildLeftPane(BuildContext context) {
    final isIncomingOnly = bind.isIncomingOnly();
    final isOutgoingOnly = bind.isOutgoingOnly();
    final children = <Widget>[
      if (!isOutgoingOnly) buildPresetPasswordWarning(),
      if (bind.isCustomClient())
        Align(
          alignment: Alignment.center,
          child: loadPowered(context),
        ),
      Align(
        alignment: Alignment.center,
        child: loadLogo(),
      ),
      buildTip(context),
      if (!isOutgoingOnly) buildIDBoard(context),
      if (!isOutgoingOnly) buildPasswordBoard(context),
      FutureBuilder<Widget>(
        future: Future.value(
            Obx(() => buildHelpCards(stateGlobal.updateUrl.value))),
        builder: (_, data) {
          if (data.hasData) {
            if (isIncomingOnly) {
              if (isInHomePage()) {
                Future.delayed(Duration(milliseconds: 300), () {
                  _updateWindowSize();
                });
              }
            }
            return data.data!;
          } else {
            return const Offstage();
          }
        },
      ),
      buildPluginEntry(),
    ];
    if (isIncomingOnly) {
      children.addAll([
        Divider(),
        OnlineStatusWidget(
          onSvcStatusChanged: () {
            if (isInHomePage()) {
              Future.delayed(Duration(milliseconds: 300), () {
                _updateWindowSize();
              });
            }
          },
        ).marginOnly(bottom: 6, right: 6)
      ]);
    }
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Container(
        width: isIncomingOnly ? 280.0 : 200.0,
        color: Theme.of(context).colorScheme.surface,
        child: Stack(
          children: [
            Column(
              children: [
                SingleChildScrollView(
                  controller: _leftPaneScrollController,
                  child: Column(
                    key: _childKey,
                    children: children,
                  ),
                ),
                Expanded(child: Container())
              ],
            ),
            if (isOutgoingOnly)
              Positioned(
                bottom: 6,
                left: 12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => _editHover.value = true,
                    onExit: (_) => _editHover.value = false,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => {
                        if (DesktopSettingPage.tabKeys.isNotEmpty)
                          {
                            DesktopSettingPage.switch2page(
                                DesktopSettingPage.tabKeys[0])
                          }
                      },
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Obx(
                          () => Icon(
                            Icons.settings,
                            color: _editHover.value
                                ? textColor
                                : Colors.grey.withValues(alpha: 0.5),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  buildRightPane(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ConnectionPage(),
    );
  }

  buildIDBoard(BuildContext context) {
    final model = gFFI.serverModel;
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 11),
      height: 57,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 2,
            decoration: const BoxDecoration(color: MyTheme.accent),
          ).marginOnly(top: 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 25,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate("ID"),
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.color
                                  ?.withValues(alpha: 0.5)),
                        ).marginOnly(top: 5),
                        buildPopupMenu(context)
                      ],
                    ),
                  ),
                  Flexible(
                    child: GestureDetector(
                      onDoubleTap: () {
                        Clipboard.setData(
                            ClipboardData(text: model.serverId.text));
                        showToast(translate("Copied"));
                      },
                      child: TextFormField(
                        controller: model.serverId,
                        readOnly: true,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(top: 10, bottom: 10),
                        ),
                        style: TextStyle(
                          fontSize: 22,
                        ),
                      ).workaroundFreezeLinuxMint(),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPopupMenu(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    RxBool hover = false.obs;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => hover.value = true,
      onExit: (_) => hover.value = false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: DesktopTabPage.onAddSetting,
        child: Tooltip(
          message: translate('Settings'),
          child: Obx(
            () => CircleAvatar(
              radius: 15,
              backgroundColor: hover.value
                  ? Theme.of(context).scaffoldBackgroundColor
                  : Theme.of(context).colorScheme.surface,
              child: Icon(
                Icons.more_vert_outlined,
                size: 20,
                color:
                    hover.value ? textColor : textColor?.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  buildPasswordBoard(BuildContext context) {
    return ChangeNotifierProvider.value(
        value: gFFI.serverModel,
        child: Consumer<ServerModel>(
          builder: (context, model, child) {
            return buildPasswordBoard2(context, model);
          },
        ));
  }

  buildPasswordBoard2(BuildContext context, ServerModel model) {
    RxBool refreshHover = false.obs;
    RxBool editHover = false.obs;
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    final showOneTime = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;
    return Container(
      margin: EdgeInsets.only(left: 20.0, right: 16, top: 13, bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 2,
            height: 52,
            decoration: BoxDecoration(color: MyTheme.accent),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(
                    translate("One-time Password"),
                    style: TextStyle(
                        fontSize: 14, color: textColor?.withValues(alpha: 0.5)),
                    maxLines: 1,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onDoubleTap: () {
                            if (showOneTime) {
                              Clipboard.setData(
                                  ClipboardData(text: model.serverPasswd.text));
                              showToast(translate("Copied"));
                            }
                          },
                          child: TextFormField(
                            controller: model.serverPasswd,
                            readOnly: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.only(top: 14, bottom: 10),
                            ),
                            style: TextStyle(fontSize: 15),
                          ).workaroundFreezeLinuxMint(),
                        ),
                      ),
                      if (showOneTime)
                        AnimatedRotationWidget(
                          onPressed: () => bind.mainUpdateTemporaryPassword(),
                          child: Tooltip(
                            message: translate('Refresh Password'),
                            child: Obx(() => RotatedBox(
                                quarterTurns: 2,
                                child: Icon(
                                  Icons.refresh,
                                  color: refreshHover.value
                                      ? textColor
                                      : Color(0xFFDDDDDD),
                                  size: 22,
                                ))),
                          ),
                          onHover: (value) => refreshHover.value = value,
                        ).marginOnly(right: 8, top: 4),
                      if (!bind.isDisableSettings())
                        InkWell(
                          child: Tooltip(
                            message: translate('Change Password'),
                            child: Obx(
                              () => Icon(
                                Icons.edit,
                                color: editHover.value
                                    ? textColor
                                    : Color(0xFFDDDDDD),
                                size: 22,
                              ).marginOnly(right: 8, top: 4),
                            ),
                          ),
                          onTap: () => DesktopSettingPage.switch2page(
                              SettingsTabKey.safety),
                          onHover: (value) => editHover.value = value,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  buildTip(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();
    return Padding(
      padding:
          const EdgeInsets.only(left: 20.0, right: 16, top: 16.0, bottom: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              if (!isOutgoingOnly)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    translate("Your Desktop"),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 10.0,
          ),
          if (!isOutgoingOnly)
            Text(
              translate("desk_tip"),
              overflow: TextOverflow.clip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (isOutgoingOnly)
            Text(
              translate("outgoing_only_desk_tip"),
              overflow: TextOverflow.clip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget buildHelpCards(String updateUrl) {
    if (!bind.isCustomClient() &&
        updateUrl.isNotEmpty &&
        !isCardClosed &&
        bind.mainUriPrefixSync().contains('rustdesk')) {
      final isToUpdate = (isWindows || isMacOS) && bind.mainIsInstalled();
      String btnText = isToUpdate ? 'Update' : 'Download';
      GestureTapCallback onPressed = () async {
        final Uri url = Uri.parse('https://rustdesk.com/download');
        await launchUrl(url);
      };
      if (isToUpdate) {
        onPressed = () {
          handleUpdate(updateUrl);
        };
      }
      return buildInstallCard(
          "Status",
          "${translate("new-version-of-{${bind.mainGetAppNameSync()}}-tip")} (${bind.mainGetNewVersion()}).",
          btnText,
          onPressed,
          closeButton: true,
          help: isToUpdate ? 'Changelog' : null,
          link: isToUpdate
              ? 'https://github.com/rustdesk/rustdesk/releases/tag/${bind.mainGetNewVersion()}'
              : null);
    }
    if (systemError.isNotEmpty) {
      return buildInstallCard("", systemError, "", () {});
    }

    if (isWindows && !bind.isDisableInstallation()) {
      if (!bind.mainIsInstalled()) {
        return buildInstallCard(
            "", bind.isOutgoingOnly() ? "" : "install_tip", "Install",
            () async {
          await rustDeskWinManager.closeAllSubWindows();
          bind.mainGotoInstall();
        });
      } else if (bind.mainIsInstalledLowerVersion()) {
        return buildInstallCard(
            "Status", "Your installation is lower version.", "Click to upgrade",
            () async {
          await rustDeskWinManager.closeAllSubWindows();
          bind.mainUpdateMe();
        });
      }
    } else if (isMacOS) {
      final isOutgoingOnly = bind.isOutgoingOnly();
      if (!(isOutgoingOnly || bind.mainIsCanScreenRecording(prompt: false))) {
        return buildInstallCard("Permissions", "config_screen", "Configure",
            () async {
          bind.mainIsCanScreenRecording(prompt: true);
          watchIsCanScreenRecording = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!isOutgoingOnly && !bind.mainIsProcessTrusted(prompt: false)) {
        return buildInstallCard("Permissions", "config_acc", "Configure",
            () async {
          bind.mainIsProcessTrusted(prompt: true);
          watchIsProcessTrust = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!bind.mainIsCanInputMonitoring(prompt: false)) {
        return buildInstallCard("Permissions", "config_input", "Configure",
            () async {
          bind.mainIsCanInputMonitoring(prompt: true);
          watchIsInputMonitoring = true;
        }, help: 'Help', link: translate("doc_mac_permission"));
      } else if (!isOutgoingOnly &&
          !svcStopped.value &&
          bind.mainIsInstalled() &&
          !bind.mainIsInstalledDaemon(prompt: false)) {
        return buildInstallCard("", "install_daemon_tip", "Install", () async {
          bind.mainIsInstalledDaemon(prompt: true);
        });
      }
      //// Disable microphone configuration for macOS. We will request the permission when needed.
      // else if ((await osxCanRecordAudio() !=
      //     PermissionAuthorizeType.authorized)) {
      //   return buildInstallCard("Permissions", "config_microphone", "Configure",
      //       () async {
      //     osxRequestAudio();
      //     watchIsCanRecordAudio = true;
      //   });
      // }
    } else if (isLinux) {
      if (bind.isOutgoingOnly()) {
        return Container();
      }
      final LinuxCards = <Widget>[];
      if (bind.isSelinuxEnforcing()) {
        // Check is SELinux enforcing, but show user a tip of is SELinux enabled for simple.
        final keyShowSelinuxHelpTip = "show-selinux-help-tip";
        if (bind.mainGetLocalOption(key: keyShowSelinuxHelpTip) != 'N') {
          LinuxCards.add(buildInstallCard(
            "Warning",
            "selinux_tip",
            "",
            () async {},
            marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
            help: 'Help',
            link:
                'https://rustdesk.com/docs/en/client/linux/#permissions-issue',
            closeButton: true,
            closeOption: keyShowSelinuxHelpTip,
          ));
        }
      }
      if (bind.mainCurrentIsWayland()) {
        LinuxCards.add(buildInstallCard(
            "Warning", "wayland_experiment_tip", "", () async {},
            marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
            help: 'Help',
            link: 'https://rustdesk.com/docs/en/client/linux/#x11-required'));
      } else if (bind.mainIsLoginWayland()) {
        LinuxCards.add(buildInstallCard("Warning",
            "Login screen using Wayland is not supported", "", () async {},
            marginTop: LinuxCards.isEmpty ? 20.0 : 5.0,
            help: 'Help',
            link: 'https://rustdesk.com/docs/en/client/linux/#login-screen'));
      }
      if (LinuxCards.isNotEmpty) {
        return Column(
          children: LinuxCards,
        );
      }
    }
    if (bind.isIncomingOnly()) {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(
          onPressed: () {
            SystemNavigator.pop(); // Close the application
            // https://github.com/flutter/flutter/issues/66631
            if (isWindows) {
              exit(0);
            }
          },
          child: Text(translate('Quit')),
        ),
      ).marginAll(14);
    }
    return Container();
  }

  Widget buildInstallCard(String title, String content, String btnText,
      GestureTapCallback onPressed,
      {double marginTop = 20.0,
      String? help,
      String? link,
      bool? closeButton,
      String? closeOption}) {
    if (bind.mainGetBuildinOption(key: kOptionHideHelpCards) == 'Y' &&
        content != 'install_daemon_tip') {
      return const SizedBox();
    }
    void closeCard() async {
      if (closeOption != null) {
        await bind.mainSetLocalOption(key: closeOption, value: 'N');
        if (bind.mainGetLocalOption(key: closeOption) == 'N') {
          setState(() {
            isCardClosed = true;
          });
        }
      } else {
        setState(() {
          isCardClosed = true;
        });
      }
    }

    return Stack(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(
              0, marginTop, 0, bind.isIncomingOnly() ? marginTop : 0),
          child: Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color.fromARGB(255, 226, 66, 188),
                  Color.fromARGB(255, 244, 114, 124),
                ],
              )),
              padding: EdgeInsets.all(20),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (title.isNotEmpty
                          ? <Widget>[
                              Center(
                                  child: Text(
                                translate(title),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ).marginOnly(bottom: 6)),
                            ]
                          : <Widget>[]) +
                      <Widget>[
                        if (content.isNotEmpty)
                          Text(
                            translate(content),
                            style: TextStyle(
                                height: 1.5,
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 13),
                          ).marginOnly(bottom: 20)
                      ] +
                      (btnText.isNotEmpty
                          ? <Widget>[
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FixedWidthButton(
                                      width: 150,
                                      padding: 8,
                                      isOutline: true,
                                      text: translate(btnText),
                                      textColor: Colors.white,
                                      borderColor: Colors.white,
                                      textSize: 20,
                                      radius: 10,
                                      onTap: onPressed,
                                    )
                                  ])
                            ]
                          : <Widget>[]) +
                      (help != null
                          ? <Widget>[
                              Center(
                                  child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () async =>
                                        await launchUrl(Uri.parse(link!)),
                                    child: Text(
                                      translate(help),
                                      style: TextStyle(
                                          decoration: TextDecoration.underline,
                                          color: Colors.white,
                                          fontSize: 12),
                                    )),
                              ).marginOnly(top: 6)),
                            ]
                          : <Widget>[]))),
        ),
        if (closeButton != null && closeButton == true)
          Positioned(
            top: 18,
            right: 0,
            child: IconButton(
              icon: Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
              onPressed: closeCard,
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _ppDeskAllPeersLoader.init(setState);
    _ppDeskIdFocusNode.addListener(_onPPDeskIdFocusChanged);
    Timer(const Duration(milliseconds: 950), () {
      if (mounted) setState(() => _ppDeskShowStartup = false);
    });
    bind.mainLoadRecentPeers();
    bind.mainLoadFavPeers();
    bind.mainLoadLanPeers();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final lastRemoteId = await bind.mainGetLastRemoteId();
      if (lastRemoteId != _ppDeskIdController.id) {
        setState(() {
          _ppDeskIdController.id = lastRemoteId;
        });
      }
    });
    _updateTimer = periodic_immediate(const Duration(seconds: 1), () async {
      await gFFI.serverModel.fetchID();
      final error = await bind.mainGetError();
      if (systemError != error) {
        systemError = error;
        setState(() {});
      }
      final v = await mainGetBoolOption(kOptionStopService);
      if (v != svcStopped.value) {
        svcStopped.value = v;
        setState(() {});
      }
      if (watchIsCanScreenRecording) {
        if (bind.mainIsCanScreenRecording(prompt: false)) {
          watchIsCanScreenRecording = false;
          setState(() {});
        }
      }
      if (watchIsProcessTrust) {
        if (bind.mainIsProcessTrusted(prompt: false)) {
          watchIsProcessTrust = false;
          setState(() {});
        }
      }
      if (watchIsInputMonitoring) {
        if (bind.mainIsCanInputMonitoring(prompt: false)) {
          watchIsInputMonitoring = false;
          // Do not notify for now.
          // Monitoring may not take effect until the process is restarted.
          // rustDeskWinManager.call(
          //     WindowType.RemoteDesktop, kWindowDisableGrabKeyboard, '');
          setState(() {});
        }
      }
      if (watchIsCanRecordAudio) {
        if (isMacOS) {
          Future.microtask(() async {
            if ((await osxCanRecordAudio() ==
                PermissionAuthorizeType.authorized)) {
              watchIsCanRecordAudio = false;
              setState(() {});
            }
          });
        } else {
          watchIsCanRecordAudio = false;
          setState(() {});
        }
      }
    });
    Get.put<RxBool>(svcStopped, tag: 'stop-service');
    rustDeskWinManager.registerActiveWindowListener(onActiveWindowChanged);

    screenToMap(window_size.Screen screen) => {
          'frame': {
            'l': screen.frame.left,
            't': screen.frame.top,
            'r': screen.frame.right,
            'b': screen.frame.bottom,
          },
          'visibleFrame': {
            'l': screen.visibleFrame.left,
            't': screen.visibleFrame.top,
            'r': screen.visibleFrame.right,
            'b': screen.visibleFrame.bottom,
          },
          'scaleFactor': screen.scaleFactor,
        };

    bool isChattyMethod(String methodName) {
      switch (methodName) {
        case kWindowBumpMouse:
          return true;
      }

      return false;
    }

    rustDeskWinManager.setMethodHandler((call, fromWindowId) async {
      if (!isChattyMethod(call.method)) {
        debugPrint(
            "[Main] call ${call.method} with args ${call.arguments} from window $fromWindowId");
      }
      if (call.method == kWindowMainWindowOnTop) {
        windowOnTop(null);
      } else if (call.method == kWindowRefreshCurrentUser) {
        gFFI.userModel.refreshCurrentUser();
      } else if (call.method == kWindowGetWindowInfo) {
        final screen = (await window_size.getWindowInfo()).screen;
        if (screen == null) {
          return '';
        } else {
          return jsonEncode(screenToMap(screen));
        }
      } else if (call.method == kWindowGetScreenList) {
        return jsonEncode(
            (await window_size.getScreenList()).map(screenToMap).toList());
      } else if (call.method == kWindowActionRebuild) {
        reloadCurrentWindow();
      } else if (call.method == kWindowEventShow) {
        await rustDeskWinManager.registerActiveWindow(call.arguments["id"]);
      } else if (call.method == kWindowEventHide) {
        await rustDeskWinManager.unregisterActiveWindow(call.arguments['id']);
      } else if (call.method == kWindowConnect) {
        await connectMainDesktop(
          call.arguments['id'],
          isFileTransfer: call.arguments['isFileTransfer'],
          isViewCamera: call.arguments['isViewCamera'],
          isTerminal: call.arguments['isTerminal'],
          isTcpTunneling: call.arguments['isTcpTunneling'],
          isRDP: call.arguments['isRDP'],
          password: call.arguments['password'],
          forceRelay: call.arguments['forceRelay'],
          connToken: call.arguments['connToken'],
        );
      } else if (call.method == kWindowBumpMouse) {
        return RdPlatformChannel.instance
            .bumpMouse(dx: call.arguments['dx'], dy: call.arguments['dy']);
      } else if (call.method == kWindowEventMoveTabToNewWindow) {
        final args = call.arguments.split(',');
        int? windowId;
        try {
          windowId = int.parse(args[0]);
        } catch (e) {
          debugPrint("Failed to parse window id '${call.arguments}': $e");
        }
        WindowType? windowType;
        try {
          windowType = WindowType.values.byName(args[3]);
        } catch (e) {
          debugPrint("Failed to parse window type '${call.arguments}': $e");
        }
        if (windowId != null && windowType != null) {
          await rustDeskWinManager.moveTabToNewWindow(
              windowId, args[1], args[2], windowType);
        }
      } else if (call.method == kWindowEventOpenMonitorSession) {
        final args = jsonDecode(call.arguments);
        final windowId = args['window_id'] as int;
        final peerId = args['peer_id'] as String;
        final display = args['display'] as int;
        final displayCount = args['display_count'] as int;
        final windowType = args['window_type'] as int;
        final screenRect = parseParamScreenRect(args);
        await rustDeskWinManager.openMonitorSession(
            windowId, peerId, display, displayCount, screenRect, windowType);
      } else if (call.method == kWindowEventRemoteWindowCoords) {
        final windowId = int.tryParse(call.arguments);
        if (windowId != null) {
          return jsonEncode(
              await rustDeskWinManager.getOtherRemoteWindowCoords(windowId));
        }
      }
    });
    _uniLinksSubscription = listenUniLinks();

    if (bind.isIncomingOnly()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateWindowSize();
      });
    }
    WidgetsBinding.instance.addObserver(this);
  }

  _updateWindowSize() {
    RenderObject? renderObject = _childKey.currentContext?.findRenderObject();
    if (renderObject == null) {
      return;
    }
    if (renderObject is RenderBox) {
      final size = renderObject.size;
      if (size != imcomingOnlyHomeSize) {
        imcomingOnlyHomeSize = size;
        windowManager.setSize(getIncomingOnlyHomeSize());
      }
    }
  }

  @override
  void dispose() {
    _uniLinksSubscription?.cancel();
    Get.delete<RxBool>(tag: 'stop-service');
    _updateTimer?.cancel();
    _ppDeskAllPeersLoader.clear();
    _ppDeskIdFocusNode.removeListener(_onPPDeskIdFocusChanged);
    _ppDeskIdFocusNode.dispose();
    _ppDeskIdController.dispose();
    _ppDeskTextController.dispose();
    _ppDeskDeviceSearchFocusNode.dispose();
    _ppDeskDeviceSearchController.dispose();
    _ppDeskSessionSearchFocusNode.dispose();
    _ppDeskSessionSearchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      shouldBeBlocked(_block, canBeBlocked);
    }
  }

  Widget buildPluginEntry() {
    final entries = PluginUiManager.instance.entries.entries;
    return Offstage(
      offstage: entries.isEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...entries.map((entry) {
            return entry.value;
          })
        ],
      ),
    );
  }
}

class _PPDeskNavItem extends StatefulWidget {
  const _PPDeskNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.compact = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool compact;

  @override
  State<_PPDeskNavItem> createState() => _PPDeskNavItemState();
}

class _PPDeskAutocompleteRow extends StatefulWidget {
  const _PPDeskAutocompleteRow({
    required this.peer,
    required this.compact,
    required this.onTap,
  });

  final Peer peer;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_PPDeskAutocompleteRow> createState() => _PPDeskAutocompleteRowState();
}

class _PPDeskAutocompleteRowState extends State<_PPDeskAutocompleteRow> {
  String get _name {
    final peer = widget.peer;
    final name = peer.alias.isNotEmpty
        ? peer.alias
        : peer.hostname.isNotEmpty
            ? peer.hostname
            : peer.username;
    return name.isEmpty ? '未命名设备' : name;
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.peer.online;
    final statusColor =
        online ? const Color(0xFF20C66B) : const Color(0xFFFF8A1F);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.compact ? 56 : 62,
          padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 12 : 14,
              vertical: widget.compact ? 8 : 10),
          color: Colors.white,
          child: Row(
            children: [
              Container(
                width: widget.compact ? 40 : 46,
                height: widget.compact ? 40 : 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: getPlatformImage(widget.peer.platform,
                    size: widget.compact ? 24 : 28),
              ),
              SizedBox(width: widget.compact ? 10 : 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(formatID(widget.peer.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: widget.compact ? 15 : 16,
                                color: const Color(0xFF101828),
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(_name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: widget.compact ? 12 : 13,
                            color: const Color(0xFF66738A),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PPDeskNavItemState extends State<_PPDeskNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = (widget.selected || _hover)
        ? const Color(0xFF2D6BFF)
        : const Color(0xFF202B3D);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: widget.compact ? 52 : 62,
          margin: EdgeInsets.only(bottom: widget.compact ? 8 : 14),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 20 : 24),
          decoration: BoxDecoration(
            color:
                widget.selected ? const Color(0xFFEAF0FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/${widget.icon}.svg',
                width: widget.compact ? 22 : 24,
                height: widget.compact ? 22 : 24,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(width: 18),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: widget.compact ? 16 : 18,
                      fontWeight: widget.selected
                          ? FontWeight.w800
                          : (_hover ? FontWeight.w700 : FontWeight.w500),
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PPDeskPrimaryButton extends StatefulWidget {
  const _PPDeskPrimaryButton({
    required this.label,
    required this.onTap,
    required this.compact,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final String? icon;

  @override
  State<_PPDeskPrimaryButton> createState() => _PPDeskPrimaryButtonState();
}

class _PPDeskPrimaryButtonState extends State<_PPDeskPrimaryButton> {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: widget.compact ? 156 : 206,
          height: widget.compact ? 46 : 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF2D6BFF), Color(0xFF5B28FF)],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                SvgPicture.asset(
                  'assets/${widget.icon}.svg',
                  width: widget.compact ? 17 : 20,
                  height: widget.compact ? 17 : 20,
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                SizedBox(width: widget.compact ? 8 : 10),
              ],
              Text(widget.label,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.compact ? 16 : 18,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PPDeskFilterButton extends StatelessWidget {
  const _PPDeskFilterButton({
    required this.label,
    required this.selected,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.compact,
  });

  final String label;
  final String selected;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 112.0 : 132.0;
    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        value: selected,
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        customButton: Container(
          height: compact ? 40 : 44,
          width: width,
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDCE6F4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('$label：$value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: const Color(0xFF344054),
                        fontWeight: FontWeight.w700)),
              ),
              SvgPicture.asset('assets/ppdesk_chevron_down.svg',
                  width: 15,
                  height: 15,
                  colorFilter: const ColorFilter.mode(
                      Color(0xFF66738A), BlendMode.srcIn)),
            ],
          ),
        ),
        items: items.entries
            .map((item) => DropdownMenuItem<String>(
                  value: item.key,
                  child: Text(item.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          color: const Color(0xFF202B3D),
                          fontWeight: FontWeight.w700)),
                ))
            .toList(),
        dropdownStyleData: DropdownStyleData(
          width: width,
          maxHeight: compact ? 190 : 220,
          offset: const Offset(0, -4),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1E8F4)),
          ),
          elevation: 0,
        ),
        menuItemStyleData: MenuItemStyleData(
          height: compact ? 34 : 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
  }
}

class _PPDeskMenuAction {
  const _PPDeskMenuAction(this.value, this.label);

  final String value;
  final String label;
}

class _PPDeskMoreMenu extends StatelessWidget {
  const _PPDeskMoreMenu({
    required this.actions,
    required this.onSelected,
    required this.compact,
    this.customButton,
    this.menuWidth,
  });

  final List<_PPDeskMenuAction> actions;
  final ValueChanged<String> onSelected;
  final bool compact;
  final Widget? customButton;
  final double? menuWidth;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        customButton: customButton ??
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SvgPicture.asset('assets/ppdesk_more.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                      Color(0xFF66738A), BlendMode.srcIn)),
            ),
        buttonStyleData: const ButtonStyleData(
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
        ),
        items: actions
            .map((item) => DropdownMenuItem<String>(
                  value: item.value,
                  child: Text(item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          color: const Color(0xFF202B3D),
                          fontWeight: FontWeight.w700)),
                ))
            .toList(),
        onChanged: (value) {
          if (value != null) onSelected(value);
        },
        dropdownStyleData: DropdownStyleData(
          width: menuWidth ?? (compact ? 104 : 118),
          maxHeight: 160,
          offset: const Offset(0, -4),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1E8F4)),
          ),
          elevation: 0,
        ),
        menuItemStyleData: MenuItemStyleData(
          height: compact ? 34 : 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
  }
}

class _PPDeskSmallButton extends StatefulWidget {
  const _PPDeskSmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.compact,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_PPDeskSmallButton> createState() => _PPDeskSmallButtonState();
}

class _PPDeskSmallButtonState extends State<_PPDeskSmallButton> {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.compact ? 30 : 34,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 9 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE1E8F4)),
          ),
          child: Row(
            children: [
              SvgPicture.asset('assets/${widget.icon}.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                      Color(0xFF66738A), BlendMode.srcIn)),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: widget.compact ? 12 : 13,
                      color: const Color(0xFF66738A),
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PPDeskOutlineButton extends StatefulWidget {
  const _PPDeskOutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.compact,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_PPDeskOutlineButton> createState() => _PPDeskOutlineButtonState();
}

class _PPDeskOutlineButtonState extends State<_PPDeskOutlineButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? const Color(0xFF2D6BFF) : const Color(0xFF344054);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.compact ? 44 : 52,
          width: widget.compact ? 118 : 148,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color:
                    _hover ? const Color(0xFFBFD0FF) : const Color(0xFFE1E8F4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/${widget.icon}.svg',
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: widget.compact ? 12 : 13,
                        color: color,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PPDeskPagerButton extends StatefulWidget {
  const _PPDeskPagerButton({
    required this.icon,
    required this.onTap,
    required this.compact,
    this.flip = false,
  });

  final String icon;
  final VoidCallback onTap;
  final bool compact;
  final bool flip;

  @override
  State<_PPDeskPagerButton> createState() => _PPDeskPagerButtonState();
}

class _PPDeskPagerButtonState extends State<_PPDeskPagerButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.compact ? 34 : 38,
          height: widget.compact ? 34 : 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE1E8F4)),
          ),
          child: Transform.rotate(
            angle: widget.flip ? 3.14159 : 0,
            child: SvgPicture.asset('assets/${widget.icon}.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                    _hover ? const Color(0xFF2D6BFF) : const Color(0xFF66738A),
                    BlendMode.srcIn)),
          ),
        ),
      ),
    );
  }
}

class _PPDeskSettingsTabItem extends StatefulWidget {
  const _PPDeskSettingsTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_PPDeskSettingsTabItem> createState() => _PPDeskSettingsTabItemState();
}

class _PPDeskSettingsTabItemState extends State<_PPDeskSettingsTabItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = (widget.selected || _hover)
        ? const Color(0xFF2D6BFF)
        : const Color(0xFF344054);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.compact ? 40 : 46,
          margin: const EdgeInsets.only(bottom: 6),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 12),
          decoration: BoxDecoration(
            color:
                widget.selected ? const Color(0xFFEAF0FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              SvgPicture.asset('assets/${widget.icon}.svg',
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: widget.compact ? 13 : 14,
                        color: color,
                        fontWeight: (widget.selected || _hover)
                            ? FontWeight.w800
                            : FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PPDeskSettingsSection extends StatelessWidget {
  const _PPDeskSettingsSection({
    required this.icon,
    required this.title,
    required this.children,
    required this.compact,
  });

  final String icon;
  final String title;
  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PPDeskSettingIconBubble(
                icon: icon,
                color: const Color(0xFF2D6BFF),
                compact: compact,
              ),
              SizedBox(width: compact ? 10 : 12),
              Text(title,
                  style: TextStyle(
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF101828))),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, color: Color(0xFFE8EEF8)),
          ],
        ],
      ),
    );
  }
}

class _PPDeskAccountPanel extends StatelessWidget {
  const _PPDeskAccountPanel({
    required this.compact,
    required this.displayName,
    required this.handle,
    required this.signedIn,
  });

  final bool compact;
  final String displayName;
  final String handle;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 10 : 12),
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E8F4)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 50 : 58,
            height: compact ? 50 : 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFEAF0FF), Color(0xFFDDE8FF)],
              ),
              border: Border.all(color: const Color(0xFFD7E2F8)),
            ),
            child: Text('皮',
                style: TextStyle(
                    fontSize: compact ? 23 : 27,
                    color: const Color(0xFF2D6BFF),
                    fontWeight: FontWeight.w900)),
          ),
          SizedBox(width: compact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: compact ? 17 : 20,
                              color: const Color(0xFF101828),
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: signedIn
                            ? const Color(0xFFE6F8EE)
                            : const Color(0xFFF2F5FA),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(signedIn ? '已登录' : '本地',
                          style: TextStyle(
                              fontSize: 12,
                              color: signedIn
                                  ? const Color(0xFF18A957)
                                  : const Color(0xFF66738A),
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectionArea(
                  child: Text(handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 13 : 14,
                          color: const Color(0xFF66738A),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PPDeskSettingInfoRow extends StatelessWidget {
  const _PPDeskSettingInfoRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.compact,
  });

  final String icon;
  final String title;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _PPDeskSettingBaseRow(
      compact: compact,
      icon: icon,
      title: title,
      subtitle: value,
      trailing: Text(value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: compact ? 12 : 13,
              color: const Color(0xFF66738A),
              fontWeight: FontWeight.w800)),
    );
  }
}

class _PPDeskSettingActionRow extends StatefulWidget {
  const _PPDeskSettingActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.compact,
    required this.onTap,
    this.danger = false,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool compact;
  final FutureOr<void> Function() onTap;
  final bool danger;

  @override
  State<_PPDeskSettingActionRow> createState() =>
      _PPDeskSettingActionRowState();
}

class _PPDeskSettingActionRowState extends State<_PPDeskSettingActionRow> {
  @override
  Widget build(BuildContext context) {
    final color =
        widget.danger ? const Color(0xFFE5484D) : const Color(0xFF2D6BFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async => widget.onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: Colors.transparent,
          child: _PPDeskSettingBaseRow(
            compact: widget.compact,
            icon: widget.icon,
            iconColor: color,
            title: widget.title,
            subtitle: widget.subtitle,
            titleColor: widget.danger ? color : const Color(0xFF101828),
            trailing: SvgPicture.asset(
              'assets/ppdesk_chevron_right.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}

class _PPDeskSettingSelectRow extends StatefulWidget {
  const _PPDeskSettingSelectRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.compact,
    required this.onTap,
    this.disabled = false,
  });

  final String icon;
  final String title;
  final String value;
  final String subtitle;
  final bool compact;
  final FutureOr<void> Function() onTap;
  final bool disabled;

  @override
  State<_PPDeskSettingSelectRow> createState() =>
      _PPDeskSettingSelectRowState();
}

class _PPDeskSettingSelectRowState extends State<_PPDeskSettingSelectRow> {
  @override
  Widget build(BuildContext context) {
    final color =
        widget.disabled ? const Color(0xFFA1AEC2) : const Color(0xFF2D6BFF);
    return MouseRegion(
      cursor:
          widget.disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.disabled ? null : () async => widget.onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: Colors.transparent,
          child: _PPDeskSettingBaseRow(
            compact: widget.compact,
            icon: widget.icon,
            iconColor: color,
            title: widget.title,
            subtitle: widget.subtitle,
            titleColor: widget.disabled
                ? const Color(0xFF98A6BA)
                : const Color(0xFF101828),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(widget.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: widget.compact ? 12 : 13,
                          color: const Color(0xFF66738A),
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  'assets/ppdesk_chevron_right.svg',
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PPDeskSettingSwitchRow extends StatefulWidget {
  const _PPDeskSettingSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.compact,
    required this.onChanged,
    this.enabled = true,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool compact;
  final bool enabled;
  final Future<void> Function(bool) onChanged;

  @override
  State<_PPDeskSettingSwitchRow> createState() =>
      _PPDeskSettingSwitchRowState();
}

class _PPDeskSettingSwitchRowState extends State<_PPDeskSettingSwitchRow> {
  late bool _value = widget.value;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _PPDeskSettingSwitchRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _value && widget.enabled;
    return MouseRegion(
      cursor: widget.enabled && !_busy
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled && !_busy ? _toggle : null,
        child: _PPDeskSettingBaseRow(
          compact: widget.compact,
          icon: widget.icon,
          iconColor: widget.enabled
              ? const Color(0xFF2D6BFF)
              : const Color(0xFFA1AEC2),
          title: widget.title,
          subtitle: widget.subtitle,
          titleColor: widget.enabled
              ? const Color(0xFF101828)
              : const Color(0xFF98A6BA),
          trailing: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.compact ? 42 : 48,
            height: widget.compact ? 24 : 28,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF2D6BFF) : const Color(0xFFD4DCE8),
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              alignment: active ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: widget.compact ? 18 : 22,
                height: widget.compact ? 18 : 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle() async {
    final next = !_value;
    setState(() {
      _value = next;
      _busy = true;
    });
    try {
      await widget.onChanged(next);
    } catch (e) {
      showToast('$e');
      if (mounted) setState(() => _value = !next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _PPDeskSettingBaseRow extends StatelessWidget {
  const _PPDeskSettingBaseRow({
    required this.compact,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.iconColor = const Color(0xFF2D6BFF),
    this.titleColor = const Color(0xFF101828),
  });

  final bool compact;
  final String icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Color iconColor;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
      child: Row(
        children: [
          _PPDeskSettingIconBubble(
            icon: icon,
            color: iconColor,
            compact: compact,
          ),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: compact ? 14 : 15,
                        color: titleColor,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: const Color(0xFF66738A))),
              ],
            ),
          ),
          SizedBox(width: compact ? 10 : 14),
          trailing,
        ],
      ),
    );
  }
}

class _PPDeskSettingIconBubble extends StatelessWidget {
  const _PPDeskSettingIconBubble({
    required this.icon,
    required this.color,
    required this.compact,
  });

  final String icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 36 : 40,
      height: compact ? 36 : 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SvgPicture.asset(
        'assets/$icon.svg',
        width: compact ? 18 : 20,
        height: compact ? 18 : 20,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

class _PPDeskGroupItem extends StatefulWidget {
  const _PPDeskGroupItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String icon;
  final String label;
  final int count;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_PPDeskGroupItem> createState() => _PPDeskGroupItemState();
}

class _PPDeskGroupItemState extends State<_PPDeskGroupItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = (widget.selected || _hover)
        ? const Color(0xFF2D6BFF)
        : const Color(0xFF66738A);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.compact ? 38 : 44,
          margin: const EdgeInsets.only(bottom: 6),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 12),
          decoration: BoxDecoration(
            color:
                widget.selected ? const Color(0xFFEAF0FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              SvgPicture.asset('assets/${widget.icon}.svg',
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: widget.compact ? 12 : 13,
                        color: (widget.selected || _hover)
                            ? const Color(0xFF2D6BFF)
                            : const Color(0xFF344054),
                        fontWeight: (widget.selected || _hover)
                            ? FontWeight.w800
                            : FontWeight.w600)),
              ),
              Text('${widget.count}',
                  style: TextStyle(
                      fontSize: 12,
                      color: (widget.selected || _hover)
                          ? const Color(0xFF2D6BFF)
                          : const Color(0xFF66738A),
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PPDeskToolSpec {
  const _PPDeskToolSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _PPDeskToolCard extends StatefulWidget {
  const _PPDeskToolCard({required this.tool, required this.compact});

  final _PPDeskToolSpec tool;
  final bool compact;

  @override
  State<_PPDeskToolCard> createState() => _PPDeskToolCardState();
}

class _PPDeskToolCardState extends State<_PPDeskToolCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.tool.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.all(widget.compact ? 18 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _hover
                    ? widget.tool.color.withValues(alpha: .35)
                    : const Color(0xFFE1E8F4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: widget.compact ? 54 : 66,
                height: widget.compact ? 54 : 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.tool.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SvgPicture.asset('assets/${widget.tool.icon}.svg',
                    width: widget.compact ? 30 : 36,
                    height: widget.compact ? 30 : 36,
                    colorFilter:
                        ColorFilter.mode(widget.tool.color, BlendMode.srcIn)),
              ),
              const Spacer(),
              Text(widget.tool.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: widget.compact ? 17 : 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF101828))),
              SizedBox(height: widget.compact ? 6 : 8),
              Text(widget.tool.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: widget.compact ? 12 : 13,
                      color: const Color(0xFF66738A))),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: SvgPicture.asset('assets/ppdesk_chevron_right.svg',
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                        _hover ? widget.tool.color : const Color(0xFF1F2A44),
                        BlendMode.srcIn)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PPDeskRecentToolCard extends StatefulWidget {
  const _PPDeskRecentToolCard({
    required this.tool,
    required this.subtitle,
    required this.compact,
  });

  final _PPDeskToolSpec tool;
  final String subtitle;
  final bool compact;

  @override
  State<_PPDeskRecentToolCard> createState() => _PPDeskRecentToolCardState();
}

class _PPDeskRecentToolCardState extends State<_PPDeskRecentToolCard> {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.tool.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.all(widget.compact ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE1E8F4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: widget.compact ? 32 : 38,
                height: widget.compact ? 32 : 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.tool.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: SvgPicture.asset('assets/${widget.tool.icon}.svg',
                    width: widget.compact ? 18 : 22,
                    height: widget.compact ? 18 : 22,
                    colorFilter:
                        ColorFilter.mode(widget.tool.color, BlendMode.srcIn)),
              ),
              SizedBox(height: widget.compact ? 8 : 10),
              Text(widget.tool.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: widget.compact ? 12 : 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF101828))),
              const SizedBox(height: 3),
              Text(widget.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF66738A))),
            ],
          ),
        ),
      ),
    );
  }
}

class _PPDeskHelpAction extends StatefulWidget {
  const _PPDeskHelpAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_PPDeskHelpAction> createState() => _PPDeskHelpActionState();
}

class _PPDeskHelpActionState extends State<_PPDeskHelpAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? const Color(0xFF2D6BFF) : const Color(0xFF66738A);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Row(
          children: [
            SvgPicture.asset('assets/${widget.icon}.svg',
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
            const SizedBox(width: 8),
            Text(widget.label,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w800)),
            SvgPicture.asset('assets/ppdesk_chevron_right.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
          ],
        ).paddingSymmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

class _PPDeskActionTile extends StatefulWidget {
  const _PPDeskActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.compact,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_PPDeskActionTile> createState() => _PPDeskActionTileState();
}

class _PPDeskActionTileState extends State<_PPDeskActionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: widget.compact ? 44 : 62,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 14 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    _hover ? const Color(0xFFBFD0FF) : const Color(0xFFDDE5F2)),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/${widget.icon}.svg',
                width: widget.compact ? 20 : 28,
                height: widget.compact ? 20 : 28,
                colorFilter:
                    const ColorFilter.mode(Color(0xFF2D6BFF), BlendMode.srcIn),
              ),
              SizedBox(width: widget.compact ? 10 : 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: TextStyle(
                            fontSize: widget.compact ? 14 : 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF101828))),
                    if (!widget.compact) ...[
                      const SizedBox(height: 4),
                      Text(widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF7C8AA5))),
                    ],
                  ],
                ),
              ),
              SvgPicture.asset(
                'assets/ppdesk_chevron_right.svg',
                width: 18,
                height: 18,
                colorFilter:
                    const ColorFilter.mode(Color(0xFF1F2A44), BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PPDeskStatCard extends StatefulWidget {
  const _PPDeskStatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.compact,
  });

  final String icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;
  final bool compact;

  @override
  State<_PPDeskStatCard> createState() => _PPDeskStatCardState();
}

class _PPDeskStatCardState extends State<_PPDeskStatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: widget.compact ? 84 : 136,
        padding: EdgeInsets.all(widget.compact ? 12 : 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _hover
                  ? widget.color.withValues(alpha: .35)
                  : const Color(0xFFE1E8F4)),
        ),
        child: Row(
          children: [
            Container(
              height: widget.compact ? 36 : 50,
              width: widget.compact ? 36 : 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SvgPicture.asset(
                'assets/${widget.icon}.svg',
                width: widget.compact ? 20 : 28,
                height: widget.compact ? 20 : 28,
                colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
              ),
            ),
            SizedBox(width: widget.compact ? 9 : 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: widget.compact ? 11 : 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF101828))),
                  SizedBox(height: widget.compact ? 3 : 8),
                  Text(widget.value,
                      style: TextStyle(
                          fontSize: widget.compact ? 20 : 28,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF101828))),
                  if (!widget.compact) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(widget.subtitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF7C8AA5))),
                        ),
                        SvgPicture.asset(
                          'assets/ppdesk_chevron_right.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                              Color(0xFF7C8AA5), BlendMode.srcIn),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PPDeskRecentRow extends StatefulWidget {
  const _PPDeskRecentRow({
    required this.peer,
    required this.compact,
    required this.onConnect,
  });

  final Peer peer;
  final bool compact;
  final VoidCallback onConnect;

  @override
  State<_PPDeskRecentRow> createState() => _PPDeskRecentRowState();
}

class _PPDeskRecentRowState extends State<_PPDeskRecentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final name = _peerName(widget.peer);
    final online = widget.peer.online;
    final statusColor =
        online ? const Color(0xFF20C66B) : const Color(0xFF8A98AD);
    final height = widget.compact ? 56.0 : 66.0;
    final textStyle = TextStyle(
        fontSize: widget.compact ? 13 : 14,
        color: const Color(0xFF101828),
        fontWeight: FontWeight.w700);
    final mutedStyle = TextStyle(
        fontSize: widget.compact ? 12 : 13,
        color: const Color(0xFF6F7D95),
        fontWeight: FontWeight.w500);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onConnect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: height,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: widget.compact ? 34 : 40,
                height: widget.compact ? 34 : 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: SvgPicture.asset(
                  'assets/ppdesk_device.svg',
                  width: widget.compact ? 18 : 22,
                  height: widget.compact ? 18 : 22,
                  colorFilter: const ColorFilter.mode(
                      Color(0xFF2D6BFF), BlendMode.srcIn),
                ),
              ),
              SizedBox(width: widget.compact ? 8 : 10),
              Expanded(
                  flex: 4,
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle)),
              Expanded(
                  flex: 3,
                  child: Text(formatID(widget.peer.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mutedStyle)),
              Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: getPlatformImage(widget.peer.platform,
                        size: widget.compact ? 18 : 20),
                  )),
              Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Text(online ? '在线' : '离线',
                          overflow: TextOverflow.ellipsis, style: mutedStyle),
                    ],
                  )),
              SizedBox(
                width: widget.compact ? 46 : 58,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Tooltip(
                    message: translate('Connect'),
                    child: SvgPicture.asset(
                      'assets/ppdesk_chevron_right.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                          _hover
                              ? const Color(0xFF2D6BFF)
                              : const Color(0xFF7C8AA5),
                          BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _peerName(Peer peer) {
    if (peer.alias.isNotEmpty) {
      return peer.alias;
    }
    if (peer.username.isNotEmpty && peer.hostname.isNotEmpty) {
      return '${peer.username}@${peer.hostname}';
    }
    if (peer.hostname.isNotEmpty) {
      return peer.hostname;
    }
    if (peer.username.isNotEmpty) {
      return peer.username;
    }
    return formatID(peer.id);
  }
}

class _PPDeskSessionRecord {
  const _PPDeskSessionRecord({
    required this.peer,
    required this.type,
    required this.group,
    required this.time,
    required this.duration,
    required this.status,
    required this.fileName,
    required this.fileSize,
    required this.color,
  });

  final Peer peer;
  final String type;
  final String group;
  final String time;
  final String duration;
  final String status;
  final String fileName;
  final String fileSize;
  final Color color;

  bool get isFile => type == 'file';
}

class _PPDeskSessionRow extends StatefulWidget {
  const _PPDeskSessionRow({
    required this.record,
    required this.compact,
    required this.onOpen,
    required this.onAction,
  });

  final _PPDeskSessionRecord record;
  final bool compact;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;

  @override
  State<_PPDeskSessionRow> createState() => _PPDeskSessionRowState();
}

class _PPDeskSessionRowState extends State<_PPDeskSessionRow> {
  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final status = _status(record.status);
    final rowHeight = widget.compact ? 58.0 : 72.0;
    final mutedStyle = TextStyle(
        fontSize: widget.compact ? 12 : 13,
        color: const Color(0xFF66738A),
        fontWeight: FontWeight.w500);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: rowHeight,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 14 : 20),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: widget.compact ? 34 : 40,
                      height: widget.compact ? 34 : 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: record.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: SvgPicture.asset('assets/ppdesk_device.svg',
                          width: widget.compact ? 18 : 22,
                          height: widget.compact ? 18 : 22,
                          colorFilter:
                              ColorFilter.mode(record.color, BlendMode.srcIn)),
                    ),
                    SizedBox(width: widget.compact ? 8 : 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_peerName(record.peer),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: widget.compact ? 13 : 14,
                                  color: const Color(0xFF101828),
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(formatID(record.peer.id),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mutedStyle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: widget.compact ? 94 : 118,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SessionTypeChip(
                    type: record.type,
                    compact: widget.compact,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: record.isFile
                    ? Row(
                        children: [
                          SvgPicture.asset('assets/ppdesk_file.svg',
                              width: widget.compact ? 16 : 18,
                              height: widget.compact ? 16 : 18,
                              colorFilter: const ColorFilter.mode(
                                  Color(0xFF66738A), BlendMode.srcIn)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(record.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: widget.compact ? 12 : 13,
                                        color: const Color(0xFF344054),
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(record.fileSize,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: mutedStyle),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              SizedBox(
                  width: widget.compact ? 72 : 88,
                  child: Text(record.time, style: mutedStyle)),
              SizedBox(
                  width: widget.compact ? 78 : 96,
                  child: Text(record.duration, style: mutedStyle)),
              SizedBox(
                width: widget.compact ? 72 : 90,
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: status.$2, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(status.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: widget.compact ? 12 : 13,
                              color: status.$2,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: widget.compact ? 34 : 44,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _PPDeskMoreMenu(
                    compact: widget.compact,
                    onSelected: widget.onAction,
                    actions: [
                      _PPDeskMenuAction('connect', translate('Connect')),
                      _PPDeskMenuAction('file', translate('Transfer file')),
                      const _PPDeskMenuAction('detail', '详情'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color) _status(String status) {
    return switch (status) {
      'failed' => ('失败', const Color(0xFFFF314A)),
      'interrupted' => ('中断', const Color(0xFFFF9500)),
      _ => ('成功', const Color(0xFF20C66B)),
    };
  }

  String _peerName(Peer peer) {
    if (peer.alias.isNotEmpty) {
      return peer.alias;
    }
    if (peer.username.isNotEmpty && peer.hostname.isNotEmpty) {
      return '${peer.username}@${peer.hostname}';
    }
    if (peer.hostname.isNotEmpty) {
      return peer.hostname;
    }
    if (peer.username.isNotEmpty) {
      return peer.username;
    }
    return formatID(peer.id);
  }
}

class _SessionTypeChip extends StatelessWidget {
  const _SessionTypeChip({required this.type, required this.compact});

  final String type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isFile = type == 'file';
    final color = isFile ? const Color(0xFF20C66B) : const Color(0xFF2D6BFF);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(isFile ? '文件传输' : '远程控制',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: color,
              fontWeight: FontWeight.w800)),
    );
  }
}

class _PPDeskDeviceRow extends StatefulWidget {
  const _PPDeskDeviceRow({
    required this.peer,
    required this.compact,
    required this.favorite,
    required this.onConnect,
    required this.onAction,
  });

  final Peer peer;
  final bool compact;
  final bool favorite;
  final VoidCallback onConnect;
  final ValueChanged<String> onAction;

  @override
  State<_PPDeskDeviceRow> createState() => _PPDeskDeviceRowState();
}

class _PPDeskDeviceRowState extends State<_PPDeskDeviceRow> {
  @override
  Widget build(BuildContext context) {
    final rowHeight = widget.compact ? 58.0 : 72.0;
    final name = _peerName(widget.peer);
    final tag = _firstTag(widget.peer);
    final online = widget.peer.online;
    final mutedStyle = TextStyle(
        fontSize: widget.compact ? 12 : 13,
        color: const Color(0xFF66738A),
        fontWeight: FontWeight.w500);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onConnect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: rowHeight,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 14 : 20),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: widget.compact ? 34 : 40,
                      height: widget.compact ? 34 : 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF0FF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: SvgPicture.asset('assets/ppdesk_device.svg',
                          width: widget.compact ? 18 : 22,
                          height: widget.compact ? 18 : 22,
                          colorFilter: const ColorFilter.mode(
                              Color(0xFF2D6BFF), BlendMode.srcIn)),
                    ),
                    SizedBox(width: widget.compact ? 8 : 12),
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: widget.compact ? 13 : 14,
                              color: const Color(0xFF101828),
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(formatID(widget.peer.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mutedStyle),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: getPlatformImage(widget.peer.platform,
                      size: widget.compact ? 18 : 20),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: tag.isEmpty
                      ? Text('-', style: mutedStyle)
                      : Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: widget.compact ? 6 : 8,
                              vertical: widget.compact ? 3 : 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(tag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: widget.compact ? 11 : 12,
                                  color: const Color(0xFF2D6BFF),
                                  fontWeight: FontWeight.w700)),
                        ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: online
                            ? const Color(0xFF20C66B)
                            : const Color(0xFF8A98AD),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(online ? '在线' : '离线',
                        overflow: TextOverflow.ellipsis, style: mutedStyle),
                  ],
                ),
              ),
              SizedBox(
                width: widget.compact ? 52 : 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: widget.favorite ? '已收藏' : '收藏',
                      child: SvgPicture.asset('assets/ppdesk_star.svg',
                          width: 18,
                          height: 18,
                          colorFilter: ColorFilter.mode(
                              widget.favorite
                                  ? const Color(0xFF2D6BFF)
                                  : const Color(0xFF8A98AD),
                              BlendMode.srcIn)),
                    ),
                    _PPDeskMoreMenu(
                      compact: widget.compact,
                      onSelected: widget.onAction,
                      actions: [
                        _PPDeskMenuAction('connect', translate('Connect')),
                        _PPDeskMenuAction('file', translate('Transfer file')),
                        const _PPDeskMenuAction('manage', '管理'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _firstTag(Peer peer) {
    if (peer.tags.isEmpty) {
      return '';
    }
    return '${peer.tags.first}';
  }

  String _peerName(Peer peer) {
    if (peer.alias.isNotEmpty) {
      return peer.alias;
    }
    if (peer.username.isNotEmpty && peer.hostname.isNotEmpty) {
      return '${peer.username}@${peer.hostname}';
    }
    if (peer.hostname.isNotEmpty) {
      return peer.hostname;
    }
    if (peer.username.isNotEmpty) {
      return peer.username;
    }
    return formatID(peer.id);
  }
}

class _PPDeskIconButton extends StatefulWidget {
  const _PPDeskIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_PPDeskIconButton> createState() => _PPDeskIconButtonState();
}

class _PPDeskIconButtonState extends State<_PPDeskIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: SvgPicture.asset(
              'assets/${widget.icon}.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                  _hover ? const Color(0xFF2D6BFF) : const Color(0xFF8A98AD),
                  BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}

void setPasswordDialog({VoidCallback? notEmptyCallback}) async {
  final p0 = TextEditingController(text: "");
  final p1 = TextEditingController(text: "");
  var errMsg0 = "";
  var errMsg1 = "";
  final localPasswordSet =
      (await bind.mainGetCommon(key: "local-permanent-password-set")) == "true";
  final permanentPasswordSet =
      (await bind.mainGetCommon(key: "permanent-password-set")) == "true";
  final presetPassword = permanentPasswordSet && !localPasswordSet;
  var canSubmit = false;
  final RxString rxPass = "".obs;
  final rules = [
    DigitValidationRule(),
    UppercaseValidationRule(),
    LowercaseValidationRule(),
    // SpecialCharacterValidationRule(),
    MinCharactersValidationRule(8),
  ];
  final maxLength = bind.mainMaxEncryptLen();
  final statusTip = localPasswordSet
      ? translate('password-hidden-tip')
      : (presetPassword ? translate('preset-password-in-use-tip') : '');
  final showStatusTipOnMobile =
      statusTip.isNotEmpty && !isDesktop && !isWebDesktop;

  gFFI.dialogManager.show((setState, close, context) {
    updateCanSubmit() {
      canSubmit = p0.text.trim().isNotEmpty || p1.text.trim().isNotEmpty;
    }

    submit() async {
      if (!canSubmit) {
        return;
      }
      setState(() {
        errMsg0 = "";
        errMsg1 = "";
      });
      final pass = p0.text.trim();
      if (pass.isNotEmpty) {
        final Iterable violations = rules.where((r) => !r.validate(pass));
        if (violations.isNotEmpty) {
          setState(() {
            errMsg0 =
                '${translate('Prompt')}: ${violations.map((r) => r.name).join(', ')}';
          });
          return;
        }
      }
      if (p1.text.trim() != pass) {
        setState(() {
          errMsg1 =
              '${translate('Prompt')}: ${translate("The confirmation is not identical.")}';
        });
        return;
      }
      final ok = await bind.mainSetPermanentPasswordWithResult(password: pass);
      if (!ok) {
        setState(() {
          errMsg0 = '${translate('Prompt')}: ${translate("Failed")}';
        });
        return;
      }
      if (pass.isNotEmpty) {
        notEmptyCallback?.call();
      }
      close();
    }

    return CustomAlertDialog(
      title: _ppdeskDialogTitle(
        icon: Icons.key_rounded,
        text: translate("Set Password"),
      ),
      contentBoxConstraints: const BoxConstraints(maxWidth: 520),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 430, maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    obscureText: true,
                    decoration: _ppdeskDialogInputDecoration(
                      context,
                      label: translate('Password'),
                      errorText: errMsg0,
                    ),
                    controller: p0,
                    autofocus: true,
                    onChanged: (value) {
                      rxPass.value = value.trim();
                      setState(() {
                        errMsg0 = '';
                        updateCanSubmit();
                      });
                    },
                    maxLength: maxLength,
                  ).workaroundFreezeLinuxMint(),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: PasswordStrengthIndicator(password: rxPass)),
              ],
            ).marginOnly(top: 2, bottom: showStatusTipOnMobile ? 4 : 12),
            SizedBox(
              height: showStatusTipOnMobile ? 0.0 : 4.0,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    obscureText: true,
                    decoration: _ppdeskDialogInputDecoration(
                      context,
                      label: translate('Confirmation'),
                      errorText: errMsg1,
                    ),
                    controller: p1,
                    onChanged: (value) {
                      setState(() {
                        errMsg1 = '';
                        updateCanSubmit();
                      });
                    },
                    maxLength: maxLength,
                  ).workaroundFreezeLinuxMint(),
                ),
              ],
            ),
            if (statusTip.isNotEmpty)
              _ppdeskDialogTip(statusTip)
                  .marginOnly(top: showStatusTipOnMobile ? 4 : 10),
            SizedBox(
              height: showStatusTipOnMobile ? 4.0 : 12.0,
            ),
            Obx(() => Wrap(
                  runSpacing: 8.0,
                  spacing: 8,
                  children: rules.map((e) {
                    var checked = e.validate(rxPass.value.trim());
                    return _PPDeskPasswordRuleChip(
                      label: e.name,
                      checked: checked,
                    );
                  }).toList(),
                ))
          ],
        ),
      ),
      actions: (() {
        final cancelButton = dialogButton(
          "Cancel",
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: close,
          isOutline: true,
        );
        final removeButton = dialogButton(
          "Remove",
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          onPressed: () async {
            setState(() {
              errMsg0 = "";
              errMsg1 = "";
            });
            final ok =
                await bind.mainSetPermanentPasswordWithResult(password: "");
            if (!ok) {
              setState(() {
                errMsg0 = '${translate('Prompt')}: ${translate("Failed")}';
              });
              return;
            }
            close();
          },
          buttonStyle: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFFDC2626);
              }
              return const Color(0xFFEF4444);
            }),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
        );
        final okButton = dialogButton(
          "OK",
          icon: const Icon(Icons.done_rounded, size: 18),
          onPressed: canSubmit ? submit : null,
        );
        if (!isDesktop && !isWebDesktop && localPasswordSet) {
          return [
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    cancelButton,
                    const SizedBox(width: 4),
                    removeButton,
                    const SizedBox(width: 4),
                    okButton,
                  ],
                ),
              ),
            ),
          ];
        }
        return [
          cancelButton,
          if (localPasswordSet) removeButton,
          okButton,
        ];
      })(),
      onSubmit: canSubmit ? submit : null,
      onCancel: close,
    );
  });
}

Widget _ppdeskDialogTitle({required IconData icon, required String text}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF2D6BFF), size: 19),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ),
    ],
  );
}

InputDecoration _ppdeskDialogInputDecoration(
  BuildContext context, {
  required String label,
  required String errorText,
}) {
  return InputDecoration(
    labelText: label,
    errorText: errorText.isNotEmpty ? errorText : null,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDCE6F4), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF2D6BFF), width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
    ),
    labelStyle: const TextStyle(
      color: Color(0xFF2D6BFF),
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
    counterStyle: const TextStyle(
      color: Color(0xFF8A98AD),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}

Widget _ppdeskDialogTip(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E6),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFFD89B)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded,
                color: Color(0xFFF59E0B), size: 17)
            .marginOnly(top: 1, right: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF77521C),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PPDeskPasswordRuleChip extends StatelessWidget {
  const _PPDeskPasswordRuleChip({
    required this.label,
    required this.checked,
  });

  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final color = checked ? const Color(0xFF16A34A) : const Color(0xFFBD4A8F);
    final background =
        checked ? const Color(0xFFE6F8EE) : const Color(0xFFFFE4F3);
    final border = checked ? const Color(0xFFBFEED1) : const Color(0xFFF8B9DC);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            checked ? Icons.check_rounded : Icons.circle_outlined,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/autocomplete.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/animated_rotation_widget.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/update_progress.dart';
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
  final _ppDeskAllPeersLoader = AllPeersLoader();
  final RxBool _ppDeskIdFocused = false.obs;
  Iterable<Peer> _ppDeskAutocompleteOpts = const [];

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
            child: Row(
              children: [
                _buildPPDeskSidebar(context, isOutgoingOnly,
                    width: sidebarWidth, compact: compact),
                Expanded(child: _buildPPDeskMain(context, isOutgoingOnly)),
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
                  SvgPicture.asset('assets/ppdesk_logo.svg',
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
                selected: true,
                compact: compact,
                onTap: () {},
              ),
              _PPDeskNavItem(
                icon: 'ppdesk_device',
                label: '设备列表',
                compact: compact,
                onTap: () => gFFI.peerTabModel.setCurrentTab(0),
              ),
              _PPDeskNavItem(
                icon: 'ppdesk_clock',
                label: '会话记录',
                compact: compact,
                onTap: () => gFFI.peerTabModel.setCurrentTab(0),
              ),
              _PPDeskNavItem(
                icon: 'ppdesk_toolbox',
                label: '工具箱',
                compact: compact,
                onTap: () => showToast('工具箱暂未开放'),
              ),
              _PPDeskNavItem(
                icon: 'ppdesk_settings',
                label: '设置中心',
                compact: compact,
                onTap: DesktopTabPage.onAddSetting,
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F1B3A6D),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
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
                    onTap: () =>
                        DesktopSettingPage.switch2page(SettingsTabKey.safety),
                  ),
              ],
            ),
          ],
        ),
      );
    });
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
        return Padding(
          padding: EdgeInsets.fromLTRB(
              horizontalPadding, topPadding, rightPadding, compact ? 20 : 28),
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
                  const SizedBox(width: 18),
                  _buildPPDeskTopBar(),
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

  Widget _buildPPDeskTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _PPDeskRoundButton(
            icon: 'ppdesk_search',
            onTap: () => _ppDeskIdFocusNode.requestFocus()),
        const SizedBox(width: 16),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _PPDeskRoundButton(icon: 'ppdesk_bell', onTap: _openPPDeskNotice),
            Positioned(
              right: 8,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFF2D6BFF), shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDCE6FF)),
          ),
          child: const Text('皮',
              style: TextStyle(
                  color: Color(0xFF2D6BFF),
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
        ),
      ],
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
                  updateTextAndPreserveSelection(
                      controller, _ppDeskIdController.text);
                  return TextField(
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    focusNode: focusNode,
                    controller: controller,
                    inputFormatters: [IDTextInputFormatter()],
                    style: TextStyle(
                        fontSize: compact ? 16 : 18,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF101828)),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '请输入设备 ID',
                      hintStyle: const TextStyle(
                          color: Color(0xFFA1AEC2), fontSize: 16),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: compact ? 11 : 16),
                    ),
                    onChanged: (v) => _ppDeskIdController.id = v,
                    onSubmitted: (_) => _ppDeskConnect(),
                  ).workaroundFreezeLinuxMint();
                },
                onSelected: (peer) {
                  setState(() {
                    _ppDeskIdController.id = peer.id;
                    FocusScope.of(context).unfocus();
                  });
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final opts = _ppDeskAutocompleteOpts;
                  final maxHeight = (opts.length * 50.0).clamp(52.0, 220.0);
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: maxHeight, maxWidth: 420),
                        child: _ppDeskAllPeersLoader.peers.isEmpty &&
                                !_ppDeskAllPeersLoader.isPeersLoaded
                            ? const SizedBox(
                                height: 80,
                                child:
                                    Center(child: CircularProgressIndicator()))
                            : ListView(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                children: opts
                                    .map((peer) => AutocompletePeerTile(
                                        onSelect: () => onSelected(peer),
                                        peer: peer))
                                    .toList(),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            PopupMenuButton<String>(
              tooltip: translate('More'),
              offset: const Offset(0, 10),
              onSelected: (value) {
                if (value == 'file') {
                  _ppDeskConnect(isFileTransfer: true);
                } else if (value == 'camera') {
                  _ppDeskConnect(isViewCamera: true);
                } else if (value == 'terminal') {
                  _ppDeskConnect(isTerminal: true);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'file', child: Text(translate('Transfer file'))),
                PopupMenuItem(
                    value: 'camera', child: Text(translate('View camera'))),
                PopupMenuItem(
                    value: 'terminal',
                    child: Text('${translate('Terminal')} (beta)')),
              ],
              child: Container(
                width: 56,
                height: compact ? 46 : 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Color(0xFFE4EAF4))),
                ),
                child: _ppDeskSvg('ppdesk_chevron_down',
                    color: const Color(0xFF66738A), size: 20),
              ),
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
                    onTap: () => gFFI.peerTabModel.setCurrentTab(0),
                    borderRadius: BorderRadius.circular(8),
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
      boxShadow: const [
        BoxShadow(
          color: Color(0x101B3A6D),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
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

  void _openPPDeskNotice() {
    if (systemError.isNotEmpty) {
      showToast(systemError);
      return;
    }
    if (isMacOS) {
      final isOutgoingOnly = bind.isOutgoingOnly();
      if (!(isOutgoingOnly || bind.mainIsCanScreenRecording(prompt: false))) {
        bind.mainIsCanScreenRecording(prompt: true);
        watchIsCanScreenRecording = true;
        return;
      }
      if (!isOutgoingOnly && !bind.mainIsProcessTrusted(prompt: false)) {
        bind.mainIsProcessTrusted(prompt: true);
        watchIsProcessTrust = true;
        return;
      }
      if (!bind.mainIsCanInputMonitoring(prompt: false)) {
        bind.mainIsCanInputMonitoring(prompt: true);
        watchIsInputMonitoring = true;
        return;
      }
    }
    DesktopSettingPage.switch2page(SettingsTabKey.safety);
  }

  void _onPPDeskIdFocusChanged() {
    _ppDeskIdFocused.value = _ppDeskIdFocusNode.hasFocus;
    if (_ppDeskIdFocusNode.hasFocus) {
      if (_ppDeskAllPeersLoader.needLoad) {
        _ppDeskAllPeersLoader.getAllPeers();
      }
      final textLength = _ppDeskTextController.value.text.length;
      _ppDeskTextController.selection =
          TextSelection(baseOffset: 0, extentOffset: textLength);
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
                  child: InkWell(
                    child: Obx(
                      () => Icon(
                        Icons.settings,
                        color: _editHover.value
                            ? textColor
                            : Colors.grey.withValues(alpha: 0.5),
                        size: 22,
                      ),
                    ),
                    onTap: () => {
                      if (DesktopSettingPage.tabKeys.isNotEmpty)
                        {
                          DesktopSettingPage.switch2page(
                              DesktopSettingPage.tabKeys[0])
                        }
                    },
                    onHover: (value) => _editHover.value = value,
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
    return InkWell(
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
      onHover: (value) => hover.value = value,
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
                                  child: InkWell(
                                      onTap: () async =>
                                          await launchUrl(Uri.parse(link!)),
                                      child: Text(
                                        translate(help),
                                        style: TextStyle(
                                            decoration:
                                                TextDecoration.underline,
                                            color: Colors.white,
                                            fontSize: 12),
                                      )).marginOnly(top: 6)),
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

class _PPDeskNavItemState extends State<_PPDeskNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hover;
    final color = active ? const Color(0xFF2D6BFF) : const Color(0xFF202B3D);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: widget.compact ? 52 : 62,
          margin: EdgeInsets.only(bottom: widget.compact ? 8 : 14),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 20 : 24),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFEAF0FF) : Colors.transparent,
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
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PPDeskRoundButton extends StatefulWidget {
  const _PPDeskRoundButton({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  State<_PPDeskRoundButton> createState() => _PPDeskRoundButtonState();
}

class _PPDeskRoundButtonState extends State<_PPDeskRoundButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(21),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? const Color(0xFFEAF0FF) : Colors.transparent,
          ),
          child: SvgPicture.asset(
            'assets/${widget.icon}.svg',
            width: 22,
            height: 22,
            colorFilter:
                const ColorFilter.mode(Color(0xFF1F2A44), BlendMode.srcIn),
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
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_PPDeskPrimaryButton> createState() => _PPDeskPrimaryButtonState();
}

class _PPDeskPrimaryButtonState extends State<_PPDeskPrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
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
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2D6BFF)
                    .withValues(alpha: _hover ? .30 : .20),
                blurRadius: _hover ? 24 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(widget.label,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 16 : 18,
                  fontWeight: FontWeight.w800)),
        ),
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
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: widget.compact ? 44 : 62,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 14 : 20),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFF7FAFF) : Colors.white,
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
          boxShadow: [
            BoxShadow(
              color:
                  const Color(0xFF1B3A6D).withValues(alpha: _hover ? .10 : .06),
              blurRadius: _hover ? 26 : 18,
              offset: const Offset(0, 10),
            ),
          ],
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
      child: InkWell(
        onTap: widget.onConnect,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: height,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 12 : 16),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFF8FAFF) : Colors.white,
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
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? const Color(0xFFEAF0FF) : Colors.transparent,
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
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key, color: MyTheme.accent),
          Text(translate("Set Password")).paddingOnly(left: 10),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: showStatusTipOnMobile ? 0.0 : 6.0,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: translate('Password'),
                        errorText: errMsg0.isNotEmpty ? errMsg0 : null),
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
            ).marginOnly(top: 2, bottom: showStatusTipOnMobile ? 2 : 8),
            SizedBox(
              height: showStatusTipOnMobile ? 0.0 : 8.0,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: translate('Confirmation'),
                        errorText: errMsg1.isNotEmpty ? errMsg1 : null),
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
              Row(
                children: [
                  Icon(Icons.info, color: Colors.amber, size: 18)
                      .marginOnly(right: 6),
                  Expanded(
                      child: Text(
                    statusTip,
                    style: const TextStyle(fontSize: 13, height: 1.1),
                  ))
                ],
              ).marginOnly(top: 6, bottom: 2),
            SizedBox(
              height: showStatusTipOnMobile ? 0.0 : 8.0,
            ),
            Obx(() => Wrap(
                  runSpacing: showStatusTipOnMobile ? 2.0 : 8.0,
                  spacing: 4,
                  children: rules.map((e) {
                    var checked = e.validate(rxPass.value.trim());
                    return Chip(
                        label: Text(
                          e.name,
                          style: TextStyle(
                              color: checked
                                  ? const Color(0xFF0A9471)
                                  : Color.fromARGB(255, 198, 86, 157)),
                        ),
                        backgroundColor: checked
                            ? const Color(0xFFD0F7ED)
                            : Color.fromARGB(255, 247, 205, 232));
                  }).toList(),
                ))
          ],
        ),
      ),
      actions: (() {
        final cancelButton = dialogButton(
          "Cancel",
          icon: Icon(Icons.close_rounded),
          onPressed: close,
          isOutline: true,
        );
        final removeButton = dialogButton(
          "Remove",
          icon: Icon(Icons.delete_outline_rounded),
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
          buttonStyle:
              ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.red)),
        );
        final okButton = dialogButton(
          "OK",
          icon: Icon(Icons.done_rounded),
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

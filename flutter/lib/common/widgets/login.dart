import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/user_model.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common.dart';

const kOpSvgList = [
  'github',
  'gitlab',
  'google',
  'apple',
  'okta',
  'facebook',
  'azure',
  'auth0',
  'microsoft'
];

class _OidcProviderBranding {
  final String label;
  final String iconKey;

  const _OidcProviderBranding({
    required this.label,
    required this.iconKey,
  });
}

_OidcProviderBranding _oidcProviderBranding(String op) {
  switch (op.toLowerCase()) {
    case 'azure':
      return _OidcProviderBranding(
        label: 'Microsoft',
        iconKey: 'microsoft',
      );
    default:
      return _OidcProviderBranding(
        label: {
              'github': 'GitHub',
              'gitlab': 'GitLab',
            }[op.toLowerCase()] ??
            toCapitalized(op),
        iconKey: op.toLowerCase(),
      );
  }
}

class _IconOP extends StatelessWidget {
  final String op;
  final String? icon;
  final EdgeInsets margin;
  const _IconOP(
      {Key? key,
      required this.op,
      required this.icon,
      this.margin = const EdgeInsets.symmetric(horizontal: 4.0)})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final svgFile =
        kOpSvgList.contains(op.toLowerCase()) ? op.toLowerCase() : 'default';
    return Container(
      margin: margin,
      child: icon == null
          ? SvgPicture.asset(
              'assets/auth-$svgFile.svg',
              width: 20,
            )
          : SvgPicture.string(
              icon!,
              width: 20,
            ),
    );
  }
}

class ButtonOP extends StatelessWidget {
  final String op;
  final RxString curOP;
  final String? icon;
  final Color primaryColor;
  final double height;
  final Function() onTap;

  const ButtonOP({
    Key? key,
    required this.op,
    required this.curOP,
    required this.icon,
    required this.primaryColor,
    required this.height,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final branding = _oidcProviderBranding(op);
    final buttonLabel = '使用 ${branding.label} 登录';
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Obx(() => ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF101828),
            disabledBackgroundColor: const Color(0xFFF3F6FB),
            disabledForegroundColor: const Color(0xFF98A4B8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFDCE6F4)),
            ),
          ).copyWith(
            elevation: ButtonStyleButton.allOrNull(0.0),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          onPressed: curOP.value.isEmpty || curOP.value == op ? onTap : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IconOP(
                op: branding.iconKey,
                icon: icon,
                margin: const EdgeInsets.only(right: 10),
              ),
              Flexible(
                child: Text(buttonLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.1,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ))),
    );
  }
}

class ConfigOP {
  final String op;
  final String? icon;
  ConfigOP({required this.op, required this.icon});
}

const _ppDeskLoginBlue = Color(0xFF2D6BFF);
const _ppDeskLoginText = Color(0xFF101828);
const _ppDeskLoginSubText = Color(0xFF66738A);
const _ppDeskLoginBorder = Color(0xFFDCE6F4);

Widget _ppDeskLoginLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFEAF0FF),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFE1E8F4)),
    ),
    alignment: Alignment.center,
    child: Image.asset(
      'assets/ppdesk_logo.png',
      width: size * .76,
      height: size * .76,
      fit: BoxFit.contain,
    ),
  );
}

class _PPDeskLoginField extends StatelessWidget {
  const _PPDeskLoginField({
    required this.title,
    required this.hintText,
    required this.controller,
    required this.icon,
    this.focusNode,
    this.obscureText = false,
    this.suffix,
    this.errorText,
    this.readOnly = false,
    this.keyboardType,
    this.onChanged,
  });

  final String title;
  final String hintText;
  final TextEditingController controller;
  final String icon;
  final FocusNode? focusNode;
  final bool obscureText;
  final Widget? suffix;
  final String? errorText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _ppDeskLoginText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              obscureText: obscureText,
              keyboardType: keyboardType,
              onChanged: (_) => onChanged?.call(),
              style: const TextStyle(
                  fontSize: 15,
                  color: _ppDeskLoginText,
                  fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                    color: Color(0xFFABB6C8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(13),
                  child: SvgPicture.asset('assets/$icon.svg',
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF8A98AD), BlendMode.srcIn)),
                ),
                suffixIcon: suffix,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _ppDeskLoginBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _ppDeskLoginBlue, width: 1.6),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFEF4444), width: 1.6),
                ),
              ),
            ).workaroundFreezeLinuxMint(),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(errorText!,
                  style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _PPDeskLoginTab extends StatelessWidget {
  const _PPDeskLoginTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Text(label,
                style: TextStyle(
                    color: active ? _ppDeskLoginBlue : _ppDeskLoginSubText,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600)),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 2,
            width: active ? 112 : 0,
            decoration: BoxDecoration(
              color: _ppDeskLoginBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _PPDeskLoginPrimaryButton extends StatelessWidget {
  const _PPDeskLoginPrimaryButton({
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _ppDeskLoginBlue,
          disabledBackgroundColor: const Color(0xFFCAD4E6),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ).copyWith(
          elevation: ButtonStyleButton.allOrNull(0),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFFCAD4E6);
            }
            return _ppDeskLoginBlue;
          }),
        ),
        onPressed: enabled ? onTap : null,
        child: Text(label,
            style: const TextStyle(
                fontSize: 16, height: 1.1, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

Widget _ppDeskLoginDivider() {
  return Row(
    children: const [
      Expanded(child: Divider(color: Color(0xFFE3EAF5))),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('或',
            style: TextStyle(
                color: Color(0xFF9AA8BF),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
      Expanded(child: Divider(color: Color(0xFFE3EAF5))),
    ],
  );
}

class WidgetOP extends StatefulWidget {
  final ConfigOP config;
  final RxString curOP;
  final Function(Map<String, dynamic>) cbLogin;
  const WidgetOP({
    Key? key,
    required this.config,
    required this.curOP,
    required this.cbLogin,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _WidgetOPState();
  }
}

class _WidgetOPState extends State<WidgetOP> {
  Timer? _updateTimer;
  String _stateMsg = '';
  String _failedMsg = '';
  String _url = '';

  @override
  void dispose() {
    super.dispose();
    _updateTimer?.cancel();
  }

  _beginQueryState() {
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateState();
    });
  }

  _updateState() {
    bind.mainAccountAuthResult().then((result) {
      if (result.isEmpty) {
        return;
      }
      final resultMap = jsonDecode(result);
      if (resultMap == null) {
        return;
      }
      final String stateMsg = resultMap['state_msg'];
      String failedMsg = resultMap['failed_msg'];
      final String? url = resultMap['url'];
      final bool urlLaunched = (resultMap['url_launched'] as bool?) ?? false;
      final authBody = resultMap['auth_body'];
      if (_stateMsg != stateMsg || _failedMsg != failedMsg) {
        if (_url.isEmpty && url != null && url.isNotEmpty) {
          if (!urlLaunched) {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          }
          _url = url;
        }
        if (authBody != null) {
          _updateTimer?.cancel();
          widget.curOP.value = '';
          widget.cbLogin(authBody as Map<String, dynamic>);
        }

        setState(() {
          _stateMsg = stateMsg;
          _failedMsg = failedMsg;
          if (failedMsg.isNotEmpty) {
            widget.curOP.value = '';
            _updateTimer?.cancel();
          }
        });
      }
    });
  }

  _resetState() {
    _stateMsg = '';
    _failedMsg = '';
    _url = '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ButtonOP(
          op: widget.config.op,
          curOP: widget.curOP,
          icon: widget.config.icon,
          primaryColor: str2color(widget.config.op, 0x7f),
          height: 36,
          onTap: () async {
            _resetState();
            widget.curOP.value = widget.config.op;
            await bind.mainAccountAuth(op: widget.config.op, rememberMe: true);
            _beginQueryState();
          },
        ),
        Obx(() {
          if (widget.curOP.isNotEmpty &&
              widget.curOP.value != widget.config.op) {
            _failedMsg = '';
          }
          return Offstage(
            offstage:
                _failedMsg.isEmpty && widget.curOP.value != widget.config.op,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_stateMsg.isNotEmpty && _failedMsg.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SelectableText(
                      translate(_stateMsg),
                      style: DefaultTextStyle.of(context)
                          .style
                          .copyWith(fontSize: 12),
                    ),
                  ),
                if (_failedMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Builder(builder: (context) {
                      final errorColor = Theme.of(context).colorScheme.error;
                      final bgColor = Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.3);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                color: errorColor, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: SelectableText(
                                translate(_failedMsg),
                                style:
                                    DefaultTextStyle.of(context).style.copyWith(
                                          fontSize: 13,
                                          color: errorColor,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
              ],
            ),
          );
        }),
        Obx(
          () => Offstage(
            offstage: widget.curOP.value != widget.config.op,
            child: const SizedBox(
              height: 5.0,
            ),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: widget.curOP.value != widget.config.op,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 20),
              child: ElevatedButton(
                onPressed: () {
                  widget.curOP.value = '';
                  _updateTimer?.cancel();
                  _resetState();
                  bind.mainAccountAuthCancel();
                },
                child: Text(
                  translate('Cancel'),
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LoginWidgetOP extends StatelessWidget {
  final List<ConfigOP> ops;
  final RxString curOP;
  final Function(Map<String, dynamic>) cbLogin;

  LoginWidgetOP({
    Key? key,
    required this.ops,
    required this.curOP,
    required this.cbLogin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var children = ops
        .map((op) => [
              WidgetOP(
                config: op,
                curOP: curOP,
                cbLogin: cbLogin,
              ),
              const Divider(
                indent: 5,
                endIndent: 5,
              )
            ])
        .expand((i) => i)
        .toList();
    if (children.isNotEmpty) {
      children.removeLast();
    }
    return SingleChildScrollView(
        child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: children,
            )));
  }
}

class LoginWidgetUserPass extends StatefulWidget {
  final TextEditingController username;
  final TextEditingController pass;
  final TextEditingController code;
  final String? usernameMsg;
  final String? passMsg;
  final String? codeMsg;
  final bool isInProgress;
  final RxString curOP;
  final Function() onLogin;
  final Function() onCodeLoginUnavailable;
  final FocusNode? userFocusNode;
  final int mode;
  final ValueChanged<int> onModeChanged;
  final bool rememberMe;
  final ValueChanged<bool> onRememberMeChanged;
  const LoginWidgetUserPass({
    Key? key,
    this.userFocusNode,
    required this.username,
    required this.pass,
    required this.code,
    required this.usernameMsg,
    required this.passMsg,
    required this.codeMsg,
    required this.isInProgress,
    required this.curOP,
    required this.onLogin,
    required this.onCodeLoginUnavailable,
    required this.mode,
    required this.onModeChanged,
    required this.rememberMe,
    required this.onRememberMeChanged,
  }) : super(key: key);

  @override
  State<LoginWidgetUserPass> createState() => _LoginWidgetUserPassState();
}

class _LoginWidgetUserPassState extends State<LoginWidgetUserPass> {
  bool _passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    final isCodeMode = widget.mode == 1;
    return SizedBox(
      width: 390,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ppDeskLoginLogo(56),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('皮皮远程',
                      style: TextStyle(
                          color: _ppDeskLoginText,
                          fontSize: 24,
                          height: 1.05,
                          fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('PPDesk',
                      style: TextStyle(
                          color: _ppDeskLoginSubText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PPDeskLoginTab(
                label: '邮箱密码登录',
                active: widget.mode == 0,
                onTap: () => widget.onModeChanged(0),
              ),
              const SizedBox(
                height: 18,
                child: VerticalDivider(color: Color(0xFFE3EAF5), width: 1),
              ),
              _PPDeskLoginTab(
                label: '验证码登录',
                active: isCodeMode,
                onTap: () => widget.onModeChanged(1),
              ),
              const SizedBox(
                height: 18,
                child: VerticalDivider(color: Color(0xFFE3EAF5), width: 1),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onRememberMeChanged(!widget.rememberMe),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text('记住登录',
                      style: TextStyle(
                          color: widget.rememberMe
                              ? _ppDeskLoginBlue
                              : _ppDeskLoginSubText,
                          fontSize: 14,
                          fontWeight: widget.rememberMe
                              ? FontWeight.w800
                              : FontWeight.w600)),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFFE3EAF5), height: 18),
          const SizedBox(height: 14),
          _PPDeskLoginField(
            title: '邮箱',
            hintText: '请输入邮箱地址',
            controller: widget.username,
            focusNode: widget.userFocusNode,
            icon: 'ppdesk_user',
            keyboardType: TextInputType.emailAddress,
            errorText: widget.usernameMsg,
          ),
          if (isCodeMode)
            _PPDeskLoginField(
              title: '验证码',
              hintText: '请输入验证码',
              controller: widget.code,
              icon: 'ppdesk_shield',
              errorText: widget.codeMsg,
              suffix: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _ppDeskLoginBlue,
                ).copyWith(
                  overlayColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                ),
                onPressed: widget.onCodeLoginUnavailable,
                child: const Text('获取验证码',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            )
          else
            _PPDeskLoginField(
              title: '密码',
              hintText: '请输入密码',
              controller: widget.pass,
              icon: 'ppdesk_lock',
              obscureText: !_passwordVisible,
              errorText: widget.passMsg,
              suffix: IconButton(
                splashRadius: 1,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 19,
                  color: const Color(0xFF8A98AD),
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
          if (!isCodeMode)
            Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onRememberMeChanged(!widget.rememberMe),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: widget.rememberMe
                              ? _ppDeskLoginBlue
                              : Colors.white,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                              color: widget.rememberMe
                                  ? _ppDeskLoginBlue
                                  : _ppDeskLoginBorder),
                        ),
                        child: widget.rememberMe
                            ? const Icon(Icons.check,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      const Text('记住我',
                          style: TextStyle(
                              color: _ppDeskLoginSubText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Spacer(),
                const Text('忘记密码?',
                    style: TextStyle(
                        color: _ppDeskLoginBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          const SizedBox(height: 22),
          if (widget.isInProgress) ...[
            const LinearProgressIndicator(
              minHeight: 2,
              color: _ppDeskLoginBlue,
              backgroundColor: Color(0xFFEAF0FF),
            ),
            const SizedBox(height: 14),
          ],
          Obx(() {
            final canSubmit =
                widget.curOP.value.isEmpty || widget.curOP.value == 'rustdesk';
            return _PPDeskLoginPrimaryButton(
              label: '登录',
              enabled: canSubmit,
              onTap:
                  isCodeMode ? widget.onCodeLoginUnavailable : widget.onLogin,
            );
          }),
        ],
      ),
    );
  }
}

const kAuthReqTypeOidc = 'oidc/';

// call this directly
Future<bool?> loginDialog() async {
  var username =
      TextEditingController(text: UserModel.getLocalUserInfo()?['name'] ?? '');
  var password = TextEditingController();
  var code = TextEditingController();
  final userFocusNode = FocusNode()..requestFocus();
  Timer(Duration(milliseconds: 100), () => userFocusNode..requestFocus());

  String? usernameMsg;
  String? passwordMsg;
  String? codeMsg;
  var isInProgress = false;
  var loginMode = 0;
  var rememberLogin = true;
  final RxString curOP = ''.obs;

  final loginOptions = [].obs;
  Future.delayed(Duration.zero, () async {
    loginOptions.value = await UserModel.queryOidcLoginOptions();
  });

  final res = await gFFI.dialogManager.show<bool>((setState, close, context) {
    username.addListener(() {
      if (usernameMsg != null) {
        setState(() => usernameMsg = null);
      }
    });

    password.addListener(() {
      if (passwordMsg != null) {
        setState(() => passwordMsg = null);
      }
    });

    code.addListener(() {
      if (codeMsg != null) {
        setState(() => codeMsg = null);
      }
    });

    onDialogCancel() {
      isInProgress = false;
      close(false);
    }

    onCodeLoginUnavailable() {
      setState(() {
        codeMsg = '当前 API 暂未提供独立邮箱发码接口';
      });
      showToast('请先使用邮箱密码登录，后端返回验证码后可继续验证');
    }

    handleLoginResponse(LoginResponse resp, bool storeIfAccessToken,
        void Function([dynamic])? close) async {
      switch (resp.type) {
        case HttpType.kAuthResTypeToken:
          if (resp.access_token != null) {
            if (storeIfAccessToken) {
              await bind.mainSetLocalOption(
                  key: 'access_token', value: resp.access_token!);
              await bind.mainSetLocalOption(
                  key: 'user_info', value: jsonEncode(resp.user ?? {}));
            }
            if (close != null) {
              close(true);
            }
            return;
          }
          break;
        case HttpType.kAuthResTypeEmailCheck:
          bool? isEmailVerification;
          if (resp.tfa_type == null ||
              resp.tfa_type == HttpType.kAuthResTypeEmailCheck) {
            isEmailVerification = true;
          } else if (resp.tfa_type == HttpType.kAuthResTypeTfaCheck) {
            isEmailVerification = false;
          } else {
            passwordMsg = "Failed, bad tfa type from server";
          }
          if (isEmailVerification != null) {
            if (isMobile) {
              if (close != null) close(null);
              verificationCodeDialog(
                  resp.user, resp.secret, isEmailVerification);
            } else {
              setState(() => isInProgress = false);
              // Workaround for web, close the dialog first, then show the verification code dialog.
              // Otherwise, the text field will keep selecting the text and we can't input the code.
              // Not sure why this happens.
              if (isWeb && close != null) close(null);
              final res = await verificationCodeDialog(
                  resp.user, resp.secret, isEmailVerification);
              if (res == true) {
                if (!isWeb && close != null) close(false);
                return;
              }
            }
          }
          break;
        default:
          passwordMsg = "Failed, bad response from server";
          break;
      }
    }

    onLogin() async {
      // validate
      if (username.text.isEmpty) {
        setState(() => usernameMsg = translate('Username missed'));
        return;
      }
      if (password.text.isEmpty) {
        setState(() => passwordMsg = translate('Password missed'));
        return;
      }
      curOP.value = 'rustdesk';
      setState(() => isInProgress = true);
      try {
        final resp = await gFFI.userModel.login(LoginRequest(
            username: username.text,
            password: password.text,
            id: await bind.mainGetMyId(),
            uuid: await bind.mainGetUuid(),
            autoLogin: rememberLogin,
            type: HttpType.kAuthReqTypeAccount));
        await handleLoginResponse(resp, true, close);
      } on RequestException catch (err) {
        passwordMsg = translate(err.cause);
      } catch (err) {
        passwordMsg = "Unknown Error: $err";
      }
      curOP.value = '';
      setState(() => isInProgress = false);
    }

    thirdAuthWidget() => Obx(() {
          return Offstage(
            offstage: loginOptions.isEmpty,
            child: Column(
              children: [
                const SizedBox(height: 26),
                _ppDeskLoginDivider(),
                const SizedBox(height: 18),
                LoginWidgetOP(
                  ops: loginOptions
                      .map((e) => ConfigOP(op: e['name'], icon: e['icon']))
                      .toList(),
                  curOP: curOP,
                  cbLogin: (Map<String, dynamic> authBody) async {
                    LoginResponse? resp;
                    try {
                      // access_token is already stored in the rust side.
                      resp =
                          gFFI.userModel.getLoginResponseFromAuthBody(authBody);
                    } catch (e) {
                      debugPrint(
                          'Failed to parse oidc login body: "$authBody"');
                    }
                    close(true);

                    if (resp != null) {
                      handleLoginResponse(resp, false, null);
                    }
                  },
                ),
              ],
            ),
          );
        });

    return CustomAlertDialog(
      contentBoxConstraints: const BoxConstraints(maxWidth: 430),
      content: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                LoginWidgetUserPass(
                  username: username,
                  pass: password,
                  code: code,
                  usernameMsg: usernameMsg,
                  passMsg: passwordMsg,
                  codeMsg: codeMsg,
                  isInProgress: isInProgress,
                  curOP: curOP,
                  onLogin: onLogin,
                  onCodeLoginUnavailable: onCodeLoginUnavailable,
                  userFocusNode: userFocusNode,
                  mode: loginMode,
                  onModeChanged: (mode) => setState(() => loginMode = mode),
                  rememberMe: rememberLogin,
                  onRememberMeChanged: (value) =>
                      setState(() => rememberLogin = value),
                ),
                thirdAuthWidget(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('没有账号？',
                        style: TextStyle(
                            color: _ppDeskLoginSubText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    SizedBox(width: 10),
                    Text('立即注册',
                        style: TextStyle(
                            color: _ppDeskLoginBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDialogCancel,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 22, color: Color(0xFF8A98AD)),
              ),
            ),
          ),
        ],
      ),
      onCancel: onDialogCancel,
      onSubmit: loginMode == 0 ? onLogin : onCodeLoginUnavailable,
    );
  });

  if (res != null) {
    await UserModel.updateOtherModels();
  }

  return res;
}

Future<bool?> verificationCodeDialog(
    UserPayload? user, String? secret, bool isEmailVerification) async {
  var autoLogin = true;
  var isInProgress = false;
  String? errorText;

  final code = TextEditingController();

  final res = await gFFI.dialogManager.show<bool>((setState, close, context) {
    void onVerify() async {
      setState(() => isInProgress = true);

      try {
        final resp = await gFFI.userModel.login(LoginRequest(
            verificationCode: code.text,
            tfaCode: isEmailVerification ? null : code.text,
            secret: secret,
            username: user?.name,
            id: await bind.mainGetMyId(),
            uuid: await bind.mainGetUuid(),
            autoLogin: autoLogin,
            type: HttpType.kAuthReqTypeEmailCode));

        switch (resp.type) {
          case HttpType.kAuthResTypeToken:
            if (resp.access_token != null) {
              await bind.mainSetLocalOption(
                  key: 'access_token', value: resp.access_token!);
              close(true);
              return;
            }
            break;
          default:
            errorText = "Failed, bad response from server";
            break;
        }
      } on RequestException catch (err) {
        errorText = translate(err.cause);
      } catch (err) {
        errorText = "Unknown Error: $err";
      }

      setState(() => isInProgress = false);
    }

    getOnSubmit() =>
        code.text.trim().length == 6 && !isInProgress ? onVerify : null;

    return CustomAlertDialog(
      contentBoxConstraints: const BoxConstraints(maxWidth: 430),
      content: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 2),
            child: SizedBox(
              width: 390,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ppDeskLoginLogo(54),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEmailVerification ? '邮箱验证码' : '两步验证',
                              style: const TextStyle(
                                  color: _ppDeskLoginText,
                                  fontSize: 23,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 5),
                          const Text('继续登录皮皮远程',
                              style: TextStyle(
                                  color: _ppDeskLoginSubText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (isEmailVerification && user?.email != null)
                    _PPDeskLoginField(
                      title: '邮箱',
                      hintText: '',
                      controller: TextEditingController(text: user?.email),
                      icon: 'ppdesk_user',
                      readOnly: true,
                    ),
                  _PPDeskLoginField(
                    title: isEmailVerification ? '验证码' : '动态验证码',
                    hintText: '请输入验证码',
                    controller: code,
                    icon: 'ppdesk_shield',
                    errorText: errorText,
                    keyboardType: TextInputType.visiblePassword,
                    onChanged: () => setState(() => errorText = null),
                  ),
                  const Text('验证码为 6 位，请在有效期内完成验证。',
                      style: TextStyle(
                          color: _ppDeskLoginSubText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  if (isInProgress) ...[
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: _ppDeskLoginBlue,
                      backgroundColor: Color(0xFFEAF0FF),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _PPDeskLoginPrimaryButton(
                    label: '登录',
                    enabled: getOnSubmit() != null,
                    onTap: getOnSubmit() ?? () {},
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 22, color: Color(0xFF8A98AD)),
              ),
            ),
          ),
        ],
      ),
      onCancel: close,
      onSubmit: getOnSubmit(),
    );
  });
  // For verification code, desktop update other models in login dialog, mobile need to close login dialog first,
  // otherwise the soft keyboard will jump out on each key press, so mobile update in verification code dialog.
  if (isMobile && res == true) {
    await UserModel.updateOtherModels();
  }

  return res;
}

void logOutConfirmDialog() {
  gFFI.dialogManager.show((setState, close, context) {
    submit() {
      close();
      gFFI.userModel.logOut();
    }

    return CustomAlertDialog(
      content: Text(translate("logout_tip")),
      actions: [
        dialogButton(translate("Cancel"), onPressed: close, isOutline: true),
        dialogButton(translate("OK"), onPressed: submit),
      ],
      onSubmit: submit,
      onCancel: close,
    );
  });
}

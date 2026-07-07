// https://github.com/rodrigobastosv/fancy_password_field
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:get/get.dart';
import 'package:password_strength/password_strength.dart';

abstract class ValidationRule {
  String get name;
  bool validate(String value);
}

class UppercaseValidationRule extends ValidationRule {
  @override
  String get name => translate('uppercase');
  @override
  bool validate(String value) {
    return value.runes.any((int rune) {
      var character = String.fromCharCode(rune);
      return character.toUpperCase() == character &&
          character.toLowerCase() != character;
    });
  }
}

class LowercaseValidationRule extends ValidationRule {
  @override
  String get name => translate('lowercase');

  @override
  bool validate(String value) {
    return value.runes.any((int rune) {
      var character = String.fromCharCode(rune);
      return character.toLowerCase() == character &&
          character.toUpperCase() != character;
    });
  }
}

class DigitValidationRule extends ValidationRule {
  @override
  String get name => translate('digit');

  @override
  bool validate(String value) {
    return value.contains(RegExp(r'[0-9]'));
  }
}

class SpecialCharacterValidationRule extends ValidationRule {
  @override
  String get name => translate('special character');

  @override
  bool validate(String value) {
    return value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  }
}

class MinCharactersValidationRule extends ValidationRule {
  final int _numberOfCharacters;
  MinCharactersValidationRule(this._numberOfCharacters);

  @override
  String get name => translate('length>=$_numberOfCharacters');

  @override
  bool validate(String value) {
    return value.length >= _numberOfCharacters;
  }
}

class PasswordStrengthIndicator extends StatelessWidget {
  final RxString password;
  final double weakMedium = 0.33;
  final double mediumStrong = 0.67;
  const PasswordStrengthIndicator({Key? key, required this.password})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      var strength = estimatePasswordStrength(password.value);
      final activeColor = _getColor(strength);
      final inactiveColor = Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A3140)
          : const Color(0xFFE7EDF7);
      return Row(
        children: [
          Expanded(
              child:
                  _indicator(password.isEmpty ? inactiveColor : activeColor)),
          const SizedBox(width: 5),
          Expanded(
              child: _indicator(password.isEmpty || strength < weakMedium
                  ? inactiveColor
                  : activeColor)),
          const SizedBox(width: 5),
          Expanded(
              child: _indicator(password.isEmpty || strength < mediumStrong
                  ? inactiveColor
                  : activeColor)),
          if (password.isNotEmpty)
            Text(
              translate(_getLabel(strength)),
              style: TextStyle(
                color: activeColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ).marginOnly(left: 8),
        ],
      );
    });
  }

  Widget _indicator(Color color) {
    return Container(
      height: 7,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  String _getLabel(double strength) {
    if (strength < weakMedium) {
      return 'Weak';
    } else if (strength < mediumStrong) {
      return 'Medium';
    } else {
      return 'Strong';
    }
  }

  Color _getColor(double strength) {
    if (strength < weakMedium) {
      return const Color(0xFFF59E0B);
    } else if (strength < mediumStrong) {
      return const Color(0xFF2D6BFF);
    } else {
      return const Color(0xFF22C55E);
    }
  }
}

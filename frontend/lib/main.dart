import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

import 'fingerprint.dart';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'api.dart';
import 'location_card.dart';

part 'app_theme.dart';
part 'auth_page.dart';
part 'home_page.dart';
part 'child_page.dart';

void main() => runApp(const AnTamSo());

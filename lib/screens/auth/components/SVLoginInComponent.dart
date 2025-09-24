import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:http/http.dart' as http;
import 'package:bbdsocial/screens/SVDashboardScreen.dart';
import 'package:bbdsocial/screens/auth/screens/SVForgetPasswordScreen.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:bbdsocial/utils/SVCommon.dart';

class SVLoginInComponent extends StatefulWidget {
  final VoidCallback? callback;

  SVLoginInComponent({this.callback});

  @override
  State<SVLoginInComponent> createState() => _SVLoginInComponentState();
}

class _SVLoginInComponentState extends State<SVLoginInComponent> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool doRemember = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    String? savedUsername = await _secureStorage.read(key: 'username');
    String? savedPassword = await _secureStorage.read(key: 'password');

    if (savedUsername != null && savedPassword != null) {
      setState(() {
        emailController.text = savedUsername;
        passwordController.text = savedPassword;
        doRemember = true;
      });
    }
  }

  Future<void> _saveCredentials(String username, String password) async {
    await _secureStorage.write(key: 'username', value: username);
    await _secureStorage.write(key: 'password', value: password);
  }

  Future<void> loginUser() async {
    setState(() {
      isLoading = true;
    });

    String username = emailController.text.toLowerCase();
    String password = passwordController.text;

    var url = Uri.parse('http://10.0.0.158:8000/api/auth/login/');

    try {
      var response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        var token = jsonResponse['token'];
        var profile = jsonResponse['profile'];

        print('token: $token');
        await setValue('auth_token', token);
        await setValue('profile', profile);
        
        if (doRemember) {
          await _saveCredentials(username, password);
        } else {
          await _secureStorage.delete(key: 'username');
          await _secureStorage.delete(key: 'password');
        }

        toast("Login Successful");
        SVDashboardScreen().launch(context);
      } else {
        print('Login Failed: ${response.body}');
        toast("Login Failed: ${response.body}");
      }
    } catch (e) {
      toast("An error occurred");
      print(e);
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.width(),
      color: context.cardColor,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            16.height,
            Text('Welcome back!', style: boldTextStyle(size: 24)).paddingSymmetric(horizontal: 16),
            8.height,
            Text('You Have Been Missed For Long Time', style: secondaryTextStyle(weight: FontWeight.w500, color: svGetBodyColor())).paddingSymmetric(horizontal: 16),
            Container(
              child: Column(
                children: [
                  30.height,
                  AppTextField(
                    controller: emailController,
                    textFieldType: TextFieldType.EMAIL,
                    textStyle: boldTextStyle(),
                    decoration: svInputDecoration(
                      context,
                      label: 'Username',
                      labelStyle: secondaryTextStyle(weight: FontWeight.w600, color: svGetBodyColor()),
                    ),
                  ).paddingSymmetric(horizontal: 16),
                  16.height,
                  AppTextField(
                    controller: passwordController,
                    textFieldType: TextFieldType.PASSWORD,
                    textStyle: boldTextStyle(),
                    suffixIconColor: svGetBodyColor(),
                    suffixPasswordInvisibleWidget: Image.asset('images/socialv/icons/ic_Hide.png', height: 16, width: 16, fit: BoxFit.fill).paddingSymmetric(vertical: 16, horizontal: 14),
                    suffixPasswordVisibleWidget: svRobotoText(text: 'Show', color: SVAppColorPrimary).paddingOnly(top: 20),
                    decoration: svInputDecoration(
                      context,
                      label: 'Password',
                      contentPadding: EdgeInsets.all(0),
                      labelStyle: secondaryTextStyle(weight: FontWeight.w600, color: svGetBodyColor()),
                    ),
                  ).paddingSymmetric(horizontal: 16),
                  12.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            shape: RoundedRectangleBorder(borderRadius: radius(2)),
                            activeColor: SVAppColorPrimary,
                            value: doRemember,
                            onChanged: (val) {
                              setState(() {
                                doRemember = val.validate();
                              });
                            },
                          ),
                          svRobotoText(text: 'Remember Me'),
                        ],
                      ),
                      svRobotoText(
                        text: 'Forget Password?',
                        color: SVAppColorPrimary,
                        fontStyle: FontStyle.italic,
                        onTap: () {
                          SVForgetPasswordScreen().launch(context);
                        },
                      ).paddingSymmetric(horizontal: 16),
                    ],
                  ),
                  32.height,
                  svAppButton(
                    context: context,
                    text: 'LOGIN',
                    onTap: () {
                      loginUser();
                    },
                  ).visible(!isLoading),
                  Loader().visible(isLoading),
                  16.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      svRobotoText(text: 'Don’t Have An Account?'),
                      4.width,
                      Text(
                        'Sign Up',
                        style: secondaryTextStyle(color: SVAppColorPrimary, decoration: TextDecoration.underline),
                      ).onTap(() {
                        widget.callback?.call();
                      }, highlightColor: Colors.transparent, splashColor: Colors.transparent)
                    ],
                  ),
                  50.height,
                  svRobotoText(text: 'OR Continue With'),
                  16.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('images/socialv/icons/ic_Google.png', height: 36, width: 36, fit: BoxFit.cover),
                      8.width,
                      Image.asset('images/socialv/icons/ic_Facebook.png', height: 36, width: 36, fit: BoxFit.cover),
                      8.width,
                      Image.asset('images/socialv/icons/ic_Twitter.png', height: 36, width: 36, fit: BoxFit.cover),
                    ],
                  ),
                  50.height,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
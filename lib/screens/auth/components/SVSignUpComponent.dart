import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:http/http.dart' as http;
import 'package:bbdsocial/screens/SVDashboardScreen.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:bbdsocial/utils/SVCommon.dart';

class SVSignUpComponent extends StatefulWidget {
  final VoidCallback? callback;

  SVSignUpComponent({this.callback});

  @override
  State<SVSignUpComponent> createState() => _SVSignUpComponentState();
}

class _SVSignUpComponentState extends State<SVSignUpComponent> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool isLoading = false;

  Future<void> _saveCredentials(String username, String password) async {
    await _secureStorage.write(key: 'username', value: username);
    await _secureStorage.write(key: 'password', value: password);
  }

  Future<void> loginUser() async {
    String username = usernameController.text.toLowerCase();
    String password = passwordController.text;

    var url = Uri.parse('http://10.0.0.158:5000/api-signup/');

    try {
      var response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
          'client': false,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        var jsonResponse = jsonDecode(response.body);
        var token = jsonResponse['token'];

        await setValue('auth_token', token);
        await _saveCredentials(username, password);

        SVDashboardScreen().launch(context);
      } else {
        toast("Login Failed: ${response.body}");
      }
    } catch (e) {
      toast("An error occurred");
      print(e);
    }
  }

  Future<void> registerUser() async {
    setState(() {
      isLoading = true;
    });

    String username = usernameController.text.toLowerCase();
    String email = emailController.text.toLowerCase();
    String password = passwordController.text;
    String passwordConfirm = confirmPasswordController.text;

    if (passwordConfirm != password) {
      toast("Password does not match ...");
      setState(() {
        isLoading = false;
      });
      return;
    }

    var url = Uri.parse('http://10.0.0.158:5000/api-signup/');

    try {
      var response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        var jsonResponse = jsonDecode(response.body);
        String responseBool = jsonResponse['response'];

        if (responseBool == 'success') {
          toast("Account created successfully. Please log in.");
          await _saveCredentials(username, password);
          loginUser();
        } else {
          toast("Problem creating profile. Please try again.");
        }
      } else {
        toast("Failed to create account: ${response.body}");
      }
    } catch (e) {
      toast("An error occurred while creating account.");
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
            Text('Hello User', style: boldTextStyle(size: 24)).paddingSymmetric(horizontal: 16),
            8.height,
            Text('Create Your Account For Better Experience', style: secondaryTextStyle(weight: FontWeight.w500, color: svGetBodyColor())).paddingSymmetric(horizontal: 16),
            Container(
              child: Column(
                children: [
                  30.height,
                  AppTextField(
                    controller: usernameController,
                    textFieldType: TextFieldType.NAME,
                    textStyle: boldTextStyle(),
                    decoration: svInputDecoration(
                      context,
                      label: 'Username',
                      labelStyle: secondaryTextStyle(weight: FontWeight.w600, color: svGetBodyColor()),
                    ),
                  ).paddingSymmetric(horizontal: 16),
                  8.height,
                  AppTextField(
                    controller: emailController,
                    textFieldType: TextFieldType.EMAIL,
                    textStyle: boldTextStyle(),
                    decoration: svInputDecoration(
                      context,
                      label: 'Your Email',
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
                  10.height,
                  AppTextField(
                    controller: confirmPasswordController,
                    textFieldType: TextFieldType.PASSWORD,
                    textStyle: boldTextStyle(),
                    suffixIconColor: svGetBodyColor(),
                    suffixPasswordInvisibleWidget: Image.asset('images/socialv/icons/ic_Hide.png', height: 16, width: 16, fit: BoxFit.fill).paddingSymmetric(vertical: 16, horizontal: 14),
                    suffixPasswordVisibleWidget: svRobotoText(text: 'Show', color: SVAppColorPrimary).paddingOnly(top: 20),
                    decoration: svInputDecoration(
                      context,
                      label: 'Confirm Password',
                      contentPadding: EdgeInsets.all(0),
                      labelStyle: secondaryTextStyle(weight: FontWeight.w600, color: svGetBodyColor()),
                    ),
                  ).paddingSymmetric(horizontal: 16),
                  30.height,
                  svAppButton(
                    context: context,
                    text: 'SIGN UP',
                    onTap: () {
                      registerUser();
                    },
                  ).visible(!isLoading),
                  Loader().visible(isLoading),
                  16.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      svRobotoText(text: 'Already Have An Account?'),
                      4.width,
                      Text(
                        'Sign In',
                        style: secondaryTextStyle(color: SVAppColorPrimary, decoration: TextDecoration.underline),
                      ).onTap(() {
                        widget.callback?.call();
                      }, highlightColor: Colors.transparent, splashColor: Colors.transparent)
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
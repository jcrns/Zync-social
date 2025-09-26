import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/services/UserService.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:bbdsocial/utils/SVCommon.dart';

class SVEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profileData;

  SVEditProfileScreen({this.profileData});

  @override
  _SVEditProfileScreenState createState() => _SVEditProfileScreenState();
}

class _SVEditProfileScreenState extends State<SVEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  late TextEditingController _dobController;
  late TextEditingController _languageController;
  String? _profileImage;
  static const String _baseUrl = 'http://10.0.0.158:5000';

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.profileData?['username']);
    _emailController = TextEditingController(text: widget.profileData?['email']);
    _bioController = TextEditingController(text: widget.profileData?['bio']);
    _dobController = TextEditingController(text: widget.profileData?['date_of_birth']);
    _languageController = TextEditingController(text: widget.profileData?['language']);
    _profileImage = widget.profileData?['image'];
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedData = {
        'username': _usernameController.text,
        'email': _emailController.text,
        'bio': _bioController.text,
        'date_of_birth': _dobController.text,
        'language': _languageController.text,
        'image': _profileImage,
      };

      try {
        await UserService.updateUserProfile(updatedData);
        toast('Profile updated successfully');
        finish(context, true);
      } catch (e) {
        toast('Failed to update profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: boldTextStyle(color: Colors.white)),
        backgroundColor: SVAppColorPrimary,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              20.height,
              GestureDetector(
                onTap: () => _pickImage(),
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
                        ],
                      ),
                      child: _profileImage != null
                          ? CircleAvatar(
                              radius: 50,
                              backgroundImage: NetworkImage(_baseUrl + _profileImage!),
                            )
                          : CircleAvatar(
                              radius: 50,
                              child: Icon(Icons.person, size: 40, color: Colors.grey),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: SVAppColorPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              30.height,
              AppTextField(
                controller: _usernameController,
                textFieldType: TextFieldType.NAME,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: "Enter your username",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: context.cardColor,
                ),
                validator: (value) => value.isEmptyOrNull ? 'Required field' : null,
              ),
              16.height,
              AppTextField(
                controller: _emailController,
                textFieldType: TextFieldType.EMAIL,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: "Enter your email address",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: context.cardColor,
                ),
                validator: (value) => value.isEmptyOrNull ? 'Required field' : null,
              ),
              16.height,
              AppTextField(
                controller: _bioController,
                textFieldType: TextFieldType.MULTILINE,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  hintText: "Tell us about yourself",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: context.cardColor,
                ),
              ),
              16.height,
              AppTextField(
                controller: _dobController,
                textFieldType: TextFieldType.OTHER,
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  hintText: "Select your date of birth",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: context.cardColor,
                  suffixIcon: Icon(Icons.calendar_today, size: 20),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    _dobController.text = date.toString().split(' ')[0];
                  }
                },
              ),
              16.height,
              AppTextField(
                controller: _languageController,
                textFieldType: TextFieldType.OTHER,
                decoration: InputDecoration(
                  labelText: 'Language',
                  hintText: "Preferred language",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: context.cardColor,
                ),
              ),
              30.height,
              AppButton(
                text: 'Save Changes',
                color: SVAppColorPrimary,
                textColor: Colors.white,
                onTap: _updateProfile,
                width: context.width(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickImage() {
    // Implement image picking logic
    toast('Image picker will be implemented');
  }
}
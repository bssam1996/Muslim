import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:contactus/contactus.dart';
import 'package:muslim/shared/constants.dart';
class ContactPageClass extends StatelessWidget {
  const ContactPageClass({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact_Title', style: TextStyle(color: textColor),).tr(),
        iconTheme: const IconThemeData(color: textColor),
        backgroundColor: primaryColor,
      ),
      backgroundColor: fourthColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ContactUs(
          logo: const AssetImage('assets/icon/main.png'),
          email: 'bssam2012@gmail.com',
          emailText: "Contact_Email".tr(),
          companyName: 'B++',
          dividerThickness: 2,
          website: 'https://bssam1996.github.io/',
          websiteText: "Contact_Website".tr(),
          githubUserName: 'bssam1996',
          linkedinURL: 'https://www.linkedin.com/in/bassam-hesham/',
          textColor: thirdColor,
          cardColor: textColor,
          companyColor: textColor,
          taglineColor: textColor,
        ),
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'contactus.dart';

class ContactPageClass extends StatelessWidget {
  const ContactPageClass({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Contact_Title'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ContactUs(
            logo: const AssetImage('assets/icon/icon.png'),
            email: 'bssam2012@gmail.com',
            emailText: 'Contact_Email'.tr(),
            companyName: 'B++',
            dividerThickness: 1,
            website: 'https://bssam1996.github.io/',
            websiteText: 'Contact_Website'.tr(),
            githubUserName: 'bssam1996',
            linkedinURL: 'https://www.linkedin.com/in/bassam-hesham/',
            textColor: colors.onSurface,
            cardColor: colors.surfaceContainer,
            companyColor: colors.onSurface,
            taglineColor: colors.onSurface,
          ),
        ),
      ),
    );
  }
}

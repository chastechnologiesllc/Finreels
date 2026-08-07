import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScreen(
      title: 'Privacy Policy',
      lastUpdated: 'July 2026',
      sections: [
        _LegalSection(
          heading: 'Introduction',
          body:
              'FinReels ("we", "our", or "us") is operated by chAs Technologies LLC '
              '(trading as chAs Tech Group). This Privacy Policy explains how we '
              'collect, use, and protect your information when you use the FinReels '
              'mobile application — a financial literacy content aggregator for videos, '
              'shorts, blogs, and books across 60 business, skill, and profession '
              'categories. By using FinReels, you agree to the practices described in '
              'this policy.',
        ),
        _LegalSection(
          heading: '1. Information We Collect',
          body:
              'FinReels is designed with your privacy in mind. We collect only what '
              'is necessary to operate the app:\n\n'
              '• Device Information — Device type, operating system version, and app '
              'version, used to ensure compatibility and diagnose issues.\n\n'
              '• Usage Analytics — Aggregated, anonymised data about which content '
              'categories and resource types are viewed, to help us improve feed '
              'quality. This data cannot be used to identify you personally.\n\n'
              '• Category Preferences — Your selected business, skill, or profession '
              'categories, stored locally on your device to personalise your feed. '
              'This data is never transmitted to our servers.\n\n'
              '• Notification Preferences — Whether you have enabled or disabled '
              'push notifications. Stored locally on your device.\n\n'
              '• Purchase Records — If you purchase an ad-free period, the payment '
              'is processed by Google Play (for Play Store installs) or by Paystack '
              '(for sideloaded installs). We only receive confirmation of the '
              'purchase; we do not store your payment card details.\n\n'
              'We do not require account registration. We do not collect your name, '
              'email address, or any other personally identifiable information unless '
              'you contact us directly, or unless you choose to pay via Paystack '
              '(which requires an email address to process the transaction — see '
              'Section 3 below).',
        ),
        _LegalSection(
          heading: '2. How We Use Your Information',
          body:
              'The information we collect is used solely to:\n\n'
              '• Deliver and personalise the FinReels content feed across videos, '
              'shorts, blogs, and books.\n'
              '• Serve relevant advertisements via Google AdMob and its mediation '
              'partners, including Unity Ads (free tier only).\n'
              '• Process and verify in-app purchases.\n'
              '• Diagnose crashes and performance issues.\n'
              '• Send push notifications about new content when you have opted in.\n'
              '• Respond to support requests you send us.',
        ),
        _LegalSection(
          heading: '3. Advertising & Third-Party SDKs',
          body:
              'Free users see ads delivered by Google AdMob. To maximise fill rate, '
              'AdMob uses mediation — it may route some ad requests to Unity Ads '
              'when that network can offer a better-performing ad. Both AdMob and '
              'Unity Ads may collect and process certain device identifiers to serve '
              'personalised ads in accordance with their own respective privacy '
              'policies.\n\n'
              'Where required by applicable law (for example in the EEA, UK, and '
              'Switzerland), we ask for your consent via a form shown on first '
              'launch. You can change your choice at any time from Settings → '
              'Privacy Options. You can also opt out of personalised advertising '
              'through your device\'s ad settings.\n\n'
              'We also use the following third-party services:\n\n'
              '• Google AdMob — advertising and ad mediation\n'
              '• Unity Ads — advertising (served via AdMob mediation)\n'
              '• Google Play In-App Purchases — payment processing for Play Store '
              'installs\n'
              '• Paystack — payment processing for sideloaded installs. Paystack '
              'receives the email address and payment details you provide directly; '
              'we do not see or store your card details\n'
              '• YouTube — FinReels displays publicly available video titles, '
              'thumbnails, and descriptions from YouTube channels\' public RSS '
              'feeds, and links out to the YouTube app or website to play videos\n'
              '• Third-party blog and book sources — content is aggregated from '
              'publicly available RSS feeds and free resource URLs',
        ),
        _LegalSection(
          heading: '4. Data Retention',
          body:
              'Analytics data is retained in aggregated form for up to 12 months. '
              'Purchase records are retained for as long as your purchased ad-free '
              'period is active and for up to 12 months afterwards for accounting '
              'purposes. Locally stored preferences — including category selections, '
              'notification settings, and saved content — remain on your device '
              'until the app is uninstalled.',
        ),
        _LegalSection(
          heading: '5. Children\'s Privacy',
          body:
              'FinReels is not directed at children under the age of 13. We do not '
              'knowingly collect personal information from children. If you believe '
              'a child has provided us with personal information, please contact us '
              'and we will delete it promptly.',
        ),
        _LegalSection(
          heading: '6. Data Security',
          body:
              'We implement industry-standard technical and organisational measures '
              'to protect your information. However, no method of electronic '
              'transmission or storage is 100% secure. We cannot guarantee absolute '
              'security.',
        ),
        _LegalSection(
          heading: '7. Your Rights',
          body:
              'Depending on your jurisdiction, you may have the right to:\n\n'
              '• Access the personal data we hold about you.\n'
              '• Request correction of inaccurate data.\n'
              '• Request deletion of your data.\n'
              '• Opt out of personalised advertising.\n\n'
              'To exercise any of these rights, contact us at '
              'chastechnologiesllc@gmail.com.',
        ),
        _LegalSection(
          heading: '8. Changes to This Policy',
          body:
              'We may update this Privacy Policy from time to time. We will notify '
              'you of significant changes by updating the "Last Updated" date at the '
              'top of this page. Continued use of FinReels after changes constitutes '
              'your acceptance of the revised policy.',
        ),
        _LegalSection(
          heading: '9. Contact Us',
          body:
              'If you have any questions about this Privacy Policy, please '
              'contact us at:\n\nchastechnologiesllc@gmail.com',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Terms of Service screen
// ─────────────────────────────────────────────────────────────────────────────

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScreen(
      title: 'Terms of Service',
      lastUpdated: 'July 2026',
      sections: [
        _LegalSection(
          heading: 'Introduction',
          body:
              'Welcome to FinReels, operated by chAs Technologies LLC (trading as '
              'chAs Tech Group). By downloading or using this app, you agree to be '
              'bound by these Terms of Service ("Terms"). Please read them carefully. '
              'If you do not agree, do not use FinReels.',
        ),
        _LegalSection(
          heading: '1. About FinReels',
          body:
              'FinReels is a financial literacy content aggregator that curates '
              'videos, shorts, blogs, and books across 60 categories covering '
              'business skills, trades, and professions — built specifically to '
              'support entrepreneurs, business owners, and professionals across '
              'Africa and beyond. Content is sourced from publicly available '
              'channels, RSS feeds, and open-access resources.',
        ),
        _LegalSection(
          heading: '2. Use of the App',
          body:
              'You may use FinReels for personal, non-commercial purposes only. '
              'You agree not to:\n\n'
              '• Reproduce, distribute, or sell any content aggregated by FinReels.\n'
              '• Attempt to reverse-engineer, decompile, or tamper with the app.\n'
              '• Use the app for any unlawful or fraudulent purpose.\n'
              '• Circumvent or disable any advertising or in-app purchase system.\n'
              '• Scrape, harvest, or systematically extract content from the app.',
        ),
        _LegalSection(
          heading: '3. Content',
          body:
              'FinReels aggregates publicly available financial education content '
              'from YouTube and other sources. All video content, thumbnails, channel '
              'names, blog articles, and book references are the intellectual property '
              'of their respective creators and are subject to their own terms and '
              'licences.\n\n'
              'We do not host, upload, or claim ownership of any third-party content '
              'displayed in the app. FinReels accesses content via publicly available '
              'RSS feeds and open-access URLs in compliance with the respective '
              'platform\'s terms of service.',
        ),
        _LegalSection(
          heading: '4. Purchases & Payments',
          body:
              'FinReels offers optional one-time ad-free purchases. These are not '
              'subscriptions and do not renew automatically.\n\n'
              'If FinReels is installed from the Google Play Store, purchases are '
              'processed through Google Play and are subject to Google Play\'s billing '
              'terms. If FinReels is installed outside the Play Store, purchases are '
              'processed through Paystack.\n\n'
              '• 24 Hours Ad-Free — \$0.99\n'
              '• 1 Week Ad-Free — \$2.99\n'
              '• 1 Month Ad-Free — \$7.99\n\n'
              'Each purchase grants ad-free access for the selected period from the '
              'date of purchase. All payments are one-time and non-refundable except '
              'where required by applicable law. Google Play purchases may be eligible '
              'for a refund under Google Play\'s refund policy. For Paystack purchases, '
              'contact us using the details in Section 9 of our Privacy Policy.',
        ),
        _LegalSection(
          heading: '5. Intellectual Property',
          body:
              'The FinReels app — including its name, logo, design, original code, '
              'category taxonomy, and branding — is owned by chAs Technologies LLC '
              'and protected by applicable intellectual property laws. You may not '
              'reproduce or use our branding without prior written permission.',
        ),
        _LegalSection(
          heading: '6. Disclaimer of Warranties',
          body:
              'FinReels is provided "as is" without warranty of any kind. We do not '
              'guarantee that the app will be uninterrupted, error-free, or free of '
              'inaccuracies. Content availability depends on third-party sources that '
              'may change without notice. We make no representations about the '
              'accuracy or completeness of any aggregated content.',
        ),
        _LegalSection(
          heading: '7. Limitation of Liability',
          body:
              'To the maximum extent permitted by law, chAs Technologies LLC shall '
              'not be liable for any indirect, incidental, special, or consequential '
              'damages arising from your use of, or inability to use, FinReels — '
              'including any financial decisions made based on content viewed in '
              'the app.',
        ),
        _LegalSection(
          heading: '8. Termination',
          body:
              'We reserve the right to suspend or terminate your access to FinReels '
              'at any time, without notice, if we believe you have violated these '
              'Terms.',
        ),
        _LegalSection(
          heading: '9. Changes to These Terms',
          body:
              'We may update these Terms from time to time. Continued use of '
              'FinReels after changes take effect constitutes your acceptance of the '
              'revised Terms.',
        ),
        _LegalSection(
          heading: '10. Contact',
          body:
              'For questions about these Terms, contact us at:\n\n'
              'chastechnologiesllc@gmail.com',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content Disclaimer screen
// ─────────────────────────────────────────────────────────────────────────────

class ContentDisclaimerScreen extends StatelessWidget {
  const ContentDisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScreen(
      title: 'Content Disclaimer',
      lastUpdated: 'July 2026',
      sections: [
        _LegalSection(
          heading: 'Important Notice',
          body:
              'Please read this disclaimer carefully before using FinReels. All '
              'content available through FinReels — including videos, shorts, blogs, '
              'and books across 60 business, skill, and profession categories — is '
              'provided for educational and informational purposes only.',
        ),
        _LegalSection(
          heading: '1. Not Financial Advice',
          body:
              'Nothing in FinReels constitutes financial, investment, tax, legal, '
              'business, or accounting advice. The content is designed to improve '
              'general financial literacy, business awareness, and entrepreneurial '
              'skills. It does not take into account your personal financial '
              'situation, business objectives, or individual needs.\n\n'
              'You should not rely on any content in this app as a basis for making '
              'financial, investment, or business decisions. Always consult a '
              'qualified professional before acting on any information you encounter '
              'in the app.',
        ),
        _LegalSection(
          heading: '2. Third-Party Content',
          body:
              'FinReels aggregates content created by independent third-party '
              'creators, YouTube channels, bloggers, and authors. We do not endorse, '
              'verify, or take responsibility for the accuracy, completeness, or '
              'suitability of any third-party content shown in the app.\n\n'
              'Opinions expressed by content creators are their own and do not '
              'reflect the views of chAs Technologies LLC or FinReels. Content '
              'may cover a wide range of business models, industries, and financial '
              'strategies — it is your responsibility to evaluate what is appropriate '
              'for your own circumstances.',
        ),
        _LegalSection(
          heading: '3. No Guarantee of Results',
          body:
              'Business strategies, income claims, pricing approaches, and financial '
              'outcomes described in content shown on FinReels are not guarantees '
              'of results. Past performance of any business, investment strategy, or '
              'financial product is not indicative of future results. Starting or '
              'growing a business involves risk, including the possible loss of '
              'capital and livelihood.',
        ),
        _LegalSection(
          heading: '4. Accuracy & Currency of Information',
          body:
              'Financial laws, business regulations, tax rules, market conditions, '
              'and industry best practices change frequently. Content displayed in '
              'FinReels may not reflect the most current developments, particularly '
              'in the Nigerian and broader African regulatory environment. We make '
              'no warranty, express or implied, regarding the accuracy, timeliness, '
              'or completeness of any information provided.',
        ),
        _LegalSection(
          heading: '5. External Links & Sources',
          body:
              'Content in FinReels may reference or link to external websites, '
              'YouTube channels, blog articles, and downloadable resources. We are '
              'not responsible for the content, privacy practices, or accuracy of '
              'any external sites. Accessing external links is at your own risk.',
        ),
        _LegalSection(
          heading: '6. Books & Reading Resources',
          body:
              'The books and reading resources referenced in FinReels are sourced '
              'from publicly available free sources, open-access publishers, and '
              'public domain archives. FinReels does not host, sell, or distribute '
              'copyrighted books. All book links direct you to the publisher\'s or '
              'author\'s own platforms. Copyright remains with the respective owners.',
        ),
        _LegalSection(
          heading: '7. Limitation of Liability',
          body:
              'chAs Technologies LLC, its developers, and affiliates shall not be '
              'held liable for any financial loss, business failure, damage, or '
              'negative outcome resulting from reliance on content viewed through '
              'FinReels. Use of this app is entirely at your own risk.',
        ),
        _LegalSection(
          heading: '8. Contact',
          body:
              'If you have concerns about any content displayed in FinReels, '
              'please contact us at:\n\nchastechnologiesllc@gmail.com',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared legal scaffold
// ─────────────────────────────────────────────────────────────────────────────

class _LegalScreen extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final List<_LegalSection> sections;

  const _LegalScreen({
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: isDark ? AppTheme.darkText : AppTheme.lightText, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? AppTheme.darkText : AppTheme.lightText,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Last updated badge
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.25), width: 0.5),
            ),
            child: Text(
              'Last updated: $lastUpdated',
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Sections
          ...sections.map((s) => _SectionWidget(section: s)),
        ],
      ),
    );
  }
}

class _LegalSection {
  final String heading;
  final String body;
  const _LegalSection({required this.heading, required this.body});
}

class _SectionWidget extends StatelessWidget {
  final _LegalSection section;
  const _SectionWidget({required this.section});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: TextStyle(
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

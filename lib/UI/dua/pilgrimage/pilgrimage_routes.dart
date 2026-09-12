import 'pilgrimage_content.dart';
import 'pilgrimage_models.dart';

const hajjTypeNames = {
  HajjType.overview: PilgrimageText(
    'Not sure / overview',
    'غير متأكد / نظرة عامة',
  ),
  HajjType.tamattu: PilgrimageText('Tamattuʿ', 'التمتع'),
  HajjType.qiran: PilgrimageText('Qiran', 'القِران'),
  HajjType.ifrad: PilgrimageText('Ifrad', 'الإفراد'),
};
const hajjTypeDescriptions = {
  HajjType.overview: PilgrimageText(
    'All common stages, with conditional steps explained. Choose your type with your Hajj group.',
    'المراحل المشتركة مع توضيح الخطوات المشروطة. حدد نسكك مع مجموعة الحج.',
  ),
  HajjType.tamattu: PilgrimageText(
    'Umrah first, exit ihram, then enter ihram again for Hajj. Hajj has its own Sa’i.',
    'عمرة ثم تحلل، ثم إحرام جديد بالحج. وللحج سعي مستقل.',
  ),
  HajjType.qiran: PilgrimageText(
    'Hajj and Umrah together in one ihram. Stay in ihram after arrival. In this guide, one Sa’i suffices for both.',
    'حج وعمرة بإحرام واحد، مع البقاء في الإحرام بعد القدوم. في هذا الدليل يكفي سعي واحد عنهما.',
  ),
  HajjType.ifrad: PilgrimageText(
    'Hajj alone. Stay in ihram after arrival. Hady is not due solely for choosing Ifrad.',
    'الحج وحده، مع البقاء في الإحرام بعد القدوم. لا يجب الهدي لمجرد الإفراد.',
  ),
};
const journeyNote = PilgrimageText(
  'A schematic guide, not a geographic map. Numbers help you navigate; they do not make every action compulsory or fix its order. Confirm your circumstances with your Hajj group. Hajj-type guidance follows the linked explanation by Ibn Baz; some school rulings differ.',
  'دليل توضيحي وليس خريطة جغرافية. الأرقام للتنقل، ولا تعني وجوب كل عمل أو لزوم ترتيبه. راجع مجموعتك في أحوالك الخاصة. بيان الأنساك يتبع شرح ابن باز المرتبط بالمصادر؛ وقد تختلف بعض أحكام المذاهب.',
);
const dayTenNote = PilgrimageText(
  '10 Dhul-Hijjah • the order of these rites has flexibility (Bukhari 1736).',
  '١٠ ذو الحجة • في ترتيب أعمال هذا اليوم سعة (البخاري ١٧٣٦).',
);
const _tawafContents = [blackStone, corners, afterTawaf];
const _saiContents = [safaStart, saiDhikr];

List<PilgrimageStep> umrahRoute() => const [
  PilgrimageStep(
    id: 'ihram',
    title: PilgrimageText('Ihram & Talbiyah', 'الإحرام والتلبية'),
    stage: PilgrimageText('Begin your Umrah', 'بداية العمرة'),
    landmark: Landmark.ihram,
    content: [talbiyah],
  ),
  PilgrimageStep(
    id: 'tawaf',
    title: PilgrimageText('Tawaf', 'الطواف'),
    stage: PilgrimageText('Makkah • seven circuits', 'مكة • سبعة أشواط'),
    landmark: Landmark.kaaba,
    content: _tawafContents,
  ),
  PilgrimageStep(
    id: 'sai',
    title: PilgrimageText('Sa’i', 'السعي'),
    stage: PilgrimageText(
      'Safa → Marwah • seven legs',
      'الصفا ← المروة • سبعة أشواط',
    ),
    landmark: Landmark.hills,
    content: _saiContents,
  ),
  PilgrimageStep(
    id: 'umrah_hair',
    title: PilgrimageText('Complete Umrah', 'إتمام العمرة'),
    stage: PilgrimageText('Hair shortening / shaving', 'التقصير أو الحلق'),
    landmark: Landmark.scissors,
    content: [hair],
    condition: PilgrimageText(
      'After Tawaf and Sa’i, cut the hair to end Umrah and exit ihram.',
      'بعد الطواف والسعي يكون الحلق أو التقصير لإتمام العمرة والتحلل.',
    ),
    sources: [ritesSource],
  ),
];

/// The overview keeps conditional stages visible. Qiran/Ifrad keep both Sa'i
/// opportunities visible with mutually exclusive guidance, never two duties.
List<PilgrimageStep> hajjRoute(HajjType type) {
  final tamattu = type == HajjType.tamattu;
  final overview = type == HajjType.overview;
  return [
    PilgrimageStep(
      id: 'ihram',
      title: const PilgrimageText('Ihram & Talbiyah', 'الإحرام والتلبية'),
      stage: tamattu
          ? const PilgrimageText('Begin with Umrah', 'ابدأ بالعمرة')
          : const PilgrimageText('Begin your pilgrimage', 'بداية النسك'),
      landmark: Landmark.ihram,
      content: const [talbiyah],
      condition: hajjTypeDescriptions[type],
      sources: const [ritesSource],
    ),
    PilgrimageStep(
      id: 'arrival_tawaf',
      title: tamattu
          ? const PilgrimageText('Umrah Tawaf', 'طواف العمرة')
          : const PilgrimageText('Arrival Tawaf', 'طواف القدوم'),
      stage: const PilgrimageText(
        'Makkah • seven circuits',
        'مكة • سبعة أشواط',
      ),
      landmark: Landmark.kaaba,
      content: _tawafContents,
      condition: tamattu
          ? null
          : const PilgrimageText(
              'For Tamattu’, this is Umrah Tawaf. For Qiran/Ifrad, arrival Tawaf is distinct from Tawaf al-Ifadah; late arrivals should follow their group’s guidance.',
              'للمتمتع طواف العمرة، وللقارن والمفرد طواف القدوم وهو غير طواف الإفاضة. المتأخر في الوصول يتبع توجيه مجموعته.',
            ),
      sources: const [ritesSource],
    ),
    PilgrimageStep(
      id: 'arrival_sai',
      title: tamattu
          ? const PilgrimageText('Umrah Sa’i', 'سعي العمرة')
          : const PilgrimageText('Sa’i on arrival', 'السعي عند القدوم'),
      stage: const PilgrimageText('Safa & Marwah', 'الصفا والمروة'),
      landmark: Landmark.hills,
      content: _saiContents,
      condition: tamattu
          ? null
          : const PilgrimageText(
              'Qiran/Ifrad: do your Sa’i here OR after Tawaf al-Ifadah, not both. Tamattu’: Umrah Sa’i is followed later by a separate Hajj Sa’i.',
              'للقارن والمفرد: السعي هنا أو بعد طواف الإفاضة، لا في الموضعين. وللمتمتع سعي للعمرة ثم سعي آخر للحج.',
            ),
      sources: const [ritesSource],
    ),
    if (tamattu || overview) ...[
      const PilgrimageStep(
        id: 'umrah_hair',
        title: PilgrimageText('End Umrah & exit ihram', 'إتمام العمرة والتحلل'),
        stage: PilgrimageText('Tamattu’ only', 'للمتمتع فقط'),
        landmark: Landmark.scissors,
        content: [hair],
        condition: PilgrimageText(
          'After Umrah Tawaf and Sa’i, shorten the hair and exit ihram. Qiran/Ifrad pilgrims remain in ihram.',
          'بعد طواف العمرة وسعيها يقصر المتمتع ويتحلل؛ ويبقى القارن والمفرد على إحرامهما.',
        ),
        sources: [ritesSource],
      ),
      const PilgrimageStep(
        id: 'hajj_ihram',
        title: PilgrimageText('Enter ihram for Hajj', 'الإحرام بالحج'),
        stage: PilgrimageText(
          '8 Dhul-Hijjah • Tamattu’',
          '٨ ذو الحجة • للمتمتع',
        ),
        landmark: Landmark.ihram,
        content: [talbiyah],
        condition: PilgrimageText(
          'Tamattu’: enter a new ihram for Hajj. Qiran/Ifrad: continue your existing ihram.',
          'المتمتع يحرم بالحج من جديد؛ والقارن والمفرد يستمران في إحرامهما.',
        ),
        sources: [jabirSource],
      ),
    ],
    const PilgrimageStep(
      id: 'mina',
      title: PilgrimageText('Stay in Mina', 'المبيت بمنى'),
      stage: PilgrimageText('8 Dhul-Hijjah', '٨ ذو الحجة'),
      landmark: Landmark.tents,
      content: [mina, talbiyah],
    ),
    const PilgrimageStep(
      id: 'arafah',
      title: PilgrimageText('Arafah', 'عرفة'),
      stage: PilgrimageText(
        '9 Dhul-Hijjah • until sunset',
        '٩ ذو الحجة • إلى الغروب',
      ),
      landmark: Landmark.mountain,
      content: [arafah, generalTahlil, personalDua],
    ),
    const PilgrimageStep(
      id: 'muzdalifah',
      title: PilgrimageText('Muzdalifah', 'المزدلفة'),
      stage: PilgrimageText('Night of 10 Dhul-Hijjah', 'ليلة ١٠ ذو الحجة'),
      landmark: Landmark.night,
      content: [muzdalifah, personalDua],
    ),
    const PilgrimageStep(
      id: 'aqabah',
      title: PilgrimageText('Jamarat al-Aqabah', 'جمرة العقبة'),
      stage: PilgrimageText('10 Dhul-Hijjah', '١٠ ذو الحجة'),
      landmark: Landmark.pillars,
      content: [aqabah],
      condition: dayTenNote,
      sources: [orderSource],
    ),
    PilgrimageStep(
      id: 'hady',
      title: const PilgrimageText('Hady • sacrifice', 'الهدي'),
      stage: const PilgrimageText('When applicable', 'بحسب النسك والحال'),
      landmark: Landmark.sacrifice,
      content: const [sacrifice, acceptance],
      condition: type == HajjType.ifrad
          ? const PilgrimageText(
              'Not due solely for Ifrad. This step remains available for anyone offering a sacrifice.',
              'لا يجب لمجرد الإفراد. تبقى هذه الخطوة متاحة لمن يذبح هديًا.',
            )
          : const PilgrimageText(
              'Normally due for Tamattu’/Qiran; exemptions and alternatives apply (Qur’an 2:196). Check your arrangements with your group.',
              'يجب عادة للمتمتع والقارن مع وجود استثناءات وبدائل (البقرة ١٩٦). راجع ترتيباتك مع مجموعتك.',
            ),
      sources: const [hadySource, ritesSource, orderSource],
    ),
    const PilgrimageStep(
      id: 'hajj_hair',
      title: PilgrimageText('Halq or Taqsir', 'الحلق أو التقصير'),
      stage: PilgrimageText('10 Dhul-Hijjah', '١٠ ذو الحجة'),
      landmark: Landmark.scissors,
      content: [hair],
      condition: dayTenNote,
      sources: [orderSource],
    ),
    const PilgrimageStep(
      id: 'ifadah',
      title: PilgrimageText('Tawaf al-Ifadah', 'طواف الإفاضة'),
      stage: PilgrimageText(
        'Makkah • 10 Dhul-Hijjah or later',
        'مكة • ١٠ ذو الحجة أو بعده',
      ),
      landmark: Landmark.kaaba,
      content: _tawafContents,
      condition: dayTenNote,
      sources: [jabirSource, orderSource],
    ),
    PilgrimageStep(
      id: 'hajj_sai',
      title: const PilgrimageText('Hajj Sa’i', 'سعي الحج'),
      stage: const PilgrimageText('Safa & Marwah', 'الصفا والمروة'),
      landmark: Landmark.hills,
      content: _saiContents,
      condition: tamattu
          ? const PilgrimageText(
              'Perform Hajj Sa’i even though you performed Umrah Sa’i earlier.',
              'أدّ سعي الحج ولو كنت قد أديت سعي العمرة.',
            )
          : const PilgrimageText(
              'Qiran/Ifrad: only if you have not already performed Sa’i on arrival. Tamattu’: a separate Hajj Sa’i is needed.',
              'للقارن والمفرد إذا لم يسعيا عند القدوم. أما المتمتع فعليه سعي مستقل للحج.',
            ),
      sources: const [ritesSource],
    ),
    const PilgrimageStep(
      id: 'tashriq',
      title: PilgrimageText('Mina & the three Jamarat', 'منى والجمرات الثلاث'),
      stage: PilgrimageText(
        '11–12 Dhul-Hijjah • 13 if staying',
        '١١–١٢ ذو الحجة • و١٣ لمن تأخر',
      ),
      landmark: Landmark.pillars,
      content: [tashriq, jamarat, personalDua],
    ),
    const PilgrimageStep(
      id: 'farewell',
      title: PilgrimageText('Farewell Tawaf', 'طواف الوداع'),
      stage: PilgrimageText('Before leaving Makkah', 'قبل مغادرة مكة'),
      landmark: Landmark.kaaba,
      content: [farewell, ..._tawafContents],
    ),
  ];
}

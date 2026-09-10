import 'pilgrimage_models.dart';

const unrestrictedDuaSource = PilgrimageSource(
  'ibnbaz10450',
  PilgrimageText(
    'Ibn Baz • Duaa in Tawaf and Sa’i',
    'ابن باز • الأدعية والأذكار في الطواف والسعي',
  ),
  PilgrimageText(
    'Scholarly explanation • not a hadith grading',
    'شرح فقهي • ليس حكمًا على حديث',
  ),
  'https://binbaz.org.sa/fatwas/10450/الادعية-والاذكار-المشروعة-في-الطواف-والسعي',
);
const endTalbiyahSource = PilgrimageSource(
  'ibnbaz24957',
  PilgrimageText(
    'Ibn Baz • When Talbiyah ends for Umrah',
    'ابن باز • متى يقطع المتمتع التلبية',
  ),
  PilgrimageText(
    'Scholarly explanation • not a hadith grading',
    'شرح فقهي • ليس حكمًا على حديث',
  ),
  'https://binbaz.org.sa/fatwas/24957/متى-يقطع-المتمتع-التلبية',
);

const _bukhariGrade = PilgrimageText(
  'Sahih • collected by Imam al-Bukhari',
  'صحيح • رواه الإمام البخاري',
);
const _muslimGrade = PilgrimageText(
  'Sahih • collected by Imam Muslim',
  'صحيح • رواه الإمام مسلم',
);
const talbiyahSource = PilgrimageSource(
  'b1549',
  PilgrimageText('Sahih al-Bukhari 1549', 'صحيح البخاري ١٥٤٩'),
  _bukhariGrade,
  'https://sunnah.com/bukhari:1549',
);
const tawafSource = PilgrimageSource(
  'b1613',
  PilgrimageText('Sahih al-Bukhari 1613', 'صحيح البخاري ١٦١٣'),
  _bukhariGrade,
  'https://sunnah.com/bukhari:1613',
);
const cornersSource = PilgrimageSource(
  'ad1892',
  PilgrimageText('Sunan Abi Dawud 1892', 'سنن أبي داود ١٨٩٢'),
  PilgrimageText('Hasan • Al-Albani', 'حسن • الألباني'),
  'https://sunnah.com/abudawud:1892',
);
const jabirSource = PilgrimageSource(
  'm1218a',
  PilgrimageText('Sahih Muslim 1218a', 'صحيح مسلم ١٢١٨ أ'),
  _muslimGrade,
  'https://sunnah.com/muslim:1218a',
);
const tahlilSource = PilgrimageSource(
  'b6403',
  PilgrimageText('Sahih al-Bukhari 6403', 'صحيح البخاري ٦٤٠٣'),
  _bukhariGrade,
  'https://sunnah.com/bukhari:6403',
);
const arafahReportSource = PilgrimageSource(
  't3585',
  PilgrimageText('Jamiʿ at-Tirmidhi 3585', 'جامع الترمذي ٣٥٨٥'),
  PilgrimageText(
    'Grading differs: al-Tirmidhi calls it hasan gharib; Darussalam grades it daʿif. Not used here to establish a fixed Arafah formula.',
    'اختلف في درجته: قال الترمذي حسن غريب، وضعّفه دار السلام. لا نعتمد عليه هنا لإثبات صيغة خاصة بعرفة.',
  ),
  'https://sunnah.com/tirmidhi:3585',
);
const muzdalifahSource = PilgrimageSource(
  'q2198',
  PilgrimageText('Qur’an 2:198', 'القرآن الكريم • البقرة ١٩٨'),
  PilgrimageText('Qur’an • Al-Baqarah', 'القرآن الكريم • سورة البقرة'),
  'https://quran.com/2/198',
);
const generalDuaSource = PilgrimageSource(
  'q2201',
  PilgrimageText('Qur’an 2:201', 'القرآن الكريم • البقرة ٢٠١'),
  PilgrimageText('Qur’an • Al-Baqarah', 'القرآن الكريم • سورة البقرة'),
  'https://quran.com/2/201',
);
const ramySource = PilgrimageSource(
  'b1750',
  PilgrimageText('Sahih al-Bukhari 1750', 'صحيح البخاري ١٧٥٠'),
  _bukhariGrade,
  'https://sunnah.com/bukhari:1750',
);
const jamaratSource = PilgrimageSource(
  'b1751',
  PilgrimageText('Sahih al-Bukhari 1751', 'صحيح البخاري ١٧٥١'),
  _bukhariGrade,
  'https://sunnah.com/bukhari:1751',
);
const sacrificeSource = PilgrimageSource(
  'b5565',
  PilgrimageText('Sahih al-Bukhari 5565', 'صحيح البخاري ٥٥٦٥'),
  _bukhariGrade,
  'https://sunnah.com/bukhari:5565',
);
const acceptanceSource = PilgrimageSource(
  'm1967',
  PilgrimageText('Sahih Muslim 1967', 'صحيح مسلم ١٩٦٧'),
  _muslimGrade,
  'https://sunnah.com/muslim:1967',
);
const tashriqSource = PilgrimageSource(
  'q2203',
  PilgrimageText('Qur’an 2:203', 'القرآن الكريم • البقرة ٢٠٣'),
  PilgrimageText('Qur’an • Al-Baqarah', 'القرآن الكريم • سورة البقرة'),
  'https://quran.com/2/203',
);
const farewellSource = PilgrimageSource(
  'b1755',
  PilgrimageText('Sahih al-Bukhari 1755', 'صحيح البخاري ١٧٥٥'),
  _bukhariGrade,
  'https://sunnah.com/bukhari:1755',
);
const orderSource = PilgrimageSource(
  'b1736',
  PilgrimageText('Sahih al-Bukhari 1736', 'صحيح البخاري ١٧٣٦'),
  _bukhariGrade,
  'https://sunnah.com/bukhari:1736',
);
const ritesSource = PilgrimageSource(
  'ibnbaz16511',
  PilgrimageText(
    'Ibn Baz • Description of the three Hajj rites',
    'ابن باز • صفة مناسك الحج الثلاثة',
  ),
  PilgrimageText(
    'Scholarly explanation • not a hadith grading',
    'شرح فقهي • ليس حكمًا على حديث',
  ),
  'https://binbaz.org.sa/fatwas/16511/صفة-مناسك-الحج-الثلاثة',
);
const hadySource = PilgrimageSource(
  'q2196',
  PilgrimageText('Qur’an 2:196', 'القرآن الكريم • البقرة ١٩٦'),
  PilgrimageText('Qur’an • Al-Baqarah', 'القرآن الكريم • سورة البقرة'),
  'https://quran.com/2/196',
);

const talbiyah = PilgrimageContent(
  id: 'talbiyah',
  title: PilgrimageText('Talbiyah', 'التلبية'),
  kind: ContentKind.riteDhikr,
  arabic:
      'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لَا شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ، لَا شَرِيكَ لَكَ.',
  meaning:
      'I answer Your call, O Allah, I answer Your call. You have no partner. All praise, blessing and dominion belong to You. You have no partner.',
  transliteration:
      'Labbayka Allāhumma labbayk, labbayka lā sharīka laka labbayk, inna l-ḥamda wa n-niʿmata laka wa l-mulk, lā sharīka lak.',
  guidance: PilgrimageText(
    'Recite the Talbiyah while in ihram. In Umrah, stop when starting Tawaf; in Hajj, stop at the stoning of Jamarat al-Aqabah.',
    'أكثر من التلبية في الإحرام. في العمرة تقطع عند بدء الطواف، وفي الحج عند رمي جمرة العقبة.',
  ),
  sources: [talbiyahSource, endTalbiyahSource, ritesSource],
);
const blackStone = PilgrimageContent(
  id: 'black_stone',
  title: PilgrimageText('At the Black Stone', 'عند الحجر الأسود'),
  kind: ContentKind.riteDhikr,
  arabic: 'اللَّهُ أَكْبَرُ',
  meaning: 'Allah is greater.',
  transliteration: 'Allāhu akbar.',
  guidance: PilgrimageText(
    'Say the takbir when coming level with the Black Stone on each circuit. If unable to touch it, point towards it. Do not push others.',
    'كبّر عند محاذاة الحجر الأسود في كل شوط. إن لم تستطع استلامه فأشر إليه، ولا تزاحم الناس.',
  ),
  sources: [tawafSource],
);
const cornersArabic =
    'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ.';
const cornersMeaning =
    'Our Lord, give us good in this life and good in the next, and protect us from the punishment of the Fire.';
const cornersTransliteration =
    'Rabbanā ātinā fi d-dunyā ḥasanatan wa fi l-ākhirati ḥasanatan wa qinā ʿadhāba n-nār.';
const corners = PilgrimageContent(
  id: 'corners',
  title: PilgrimageText(
    'Between the two corners',
    'بين الركن اليماني والحجر الأسود',
  ),
  kind: ContentKind.riteDhikr,
  arabic: cornersArabic,
  meaning: cornersMeaning,
  transliteration: cornersTransliteration,
  guidance: PilgrimageText(
    'Recite this between the Yemeni Corner and the Black Stone. There is no prescribed duaa for each Tawaf circuit. Elsewhere, make personal duaa and remember Allah.',
    'يقال بين الركن اليماني والحجر الأسود. لا يوجد دعاء مأثور خاص بكل شوط من الطواف؛ وفي بقية الطواف ادع بما شئت من الخير واذكر الله.',
  ),
  sources: [cornersSource, generalDuaSource, unrestrictedDuaSource],
);
const safaStart = PilgrimageContent(
  id: 'safa_start',
  title: PilgrimageText(
    'Approaching Safa for the first time',
    'عند الاقتراب من الصفا أول مرة',
  ),
  kind: ContentKind.riteDhikr,
  arabic:
      'إِنَّ الصَّفَا وَالْمَرْوَةَ مِنْ شَعَائِرِ اللَّهِ\nأَبْدَأُ بِمَا بَدَأَ اللَّهُ بِهِ.',
  meaning:
      'Safa and Marwah are among Allah’s sacred signs. I begin with what Allah began with.',
  transliteration:
      'Inna ṣ-Ṣafā wa l-Marwata min shaʿā’iri llāh. Abda’u bimā bada’a llāhu bih.',
  guidance: PilgrimageText(
    'This opening of Qur’an 2:158 and the following words are recited on first approaching Safa, not at the start of every leg.',
    'تقرأ بداية آية البقرة ١٥٨ وهذه العبارة عند الاقتراب من الصفا أول مرة، وليس في بداية كل شوط.',
  ),
  sources: [jabirSource],
);
const saiDhikr = PilgrimageContent(
  id: 'sai_dhikr',
  title: PilgrimageText('On Safa and Marwah', 'على الصفا والمروة'),
  kind: ContentKind.riteDhikr,
  arabic:
      'اللَّهُ أَكْبَرُ\nلَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ، أَنْجَزَ وَعْدَهُ، وَنَصَرَ عَبْدَهُ، وَهَزَمَ الْأَحْزَابَ وَحْدَهُ.',
  meaning:
      'Allah is greater. No deity deserves worship except Allah alone, without partner. His is all dominion and praise; He has power over everything. Allah alone fulfilled His promise, supported His servant, and defeated the confederates.',
  transliteration:
      'Allāhu akbar. Lā ilāha illa llāhu waḥdahu lā sharīka lah, lahu l-mulku wa lahu l-ḥamdu wa huwa ʿalā kulli shay’in qadīr. Lā ilāha illa llāhu waḥdah, anjaza waʿdah, wa naṣara ʿabdah, wa hazama l-aḥzāba waḥdah.',
  guidance: PilgrimageText(
    'Face the qiblah, glorify Allah and recite the dhikr three times, making personal duaa between repetitions. Do this on Safa and Marwah. No fixed duaa is prescribed for each leg.',
    'استقبل القبلة وكبّر واذكر الله بهذا الذكر ثلاث مرات مع الدعاء بين التكرارات، وافعل ذلك على الصفا والمروة. لا يوجد دعاء مأثور خاص بكل شوط.',
  ),
  sources: [jabirSource, unrestrictedDuaSource],
);
const afterTawaf = PilgrimageContent(
  id: 'after_tawaf',
  title: PilgrimageText('After Tawaf', 'بعد الطواف'),
  action: PilgrimageText('Pray two rak’ahs', 'صلِّ ركعتين'),
  kind: ContentKind.instruction,
  guidance: PilgrimageText(
    'Pray two rak’ahs after Tawaf, behind Maqam Ibrahim if feasible without obstructing others. Jabir’s report mentions Al-Kafirun and Al-Ikhlas. No fixed post-Tawaf duaa is supplied here.',
    'صل ركعتين بعد الطواف، خلف مقام إبراهيم إن تيسر دون إعاقة الناس. وفي حديث جابر ذكر سورتي الكافرون والإخلاص. لا نورد دعاءً خاصًا بعد الطواف.',
  ),
  sources: [jabirSource, ritesSource],
);
const hair = PilgrimageContent(
  id: 'hair',
  title: PilgrimageText('Shaving or shortening the hair', 'الحلق أو التقصير'),
  action: PilgrimageText('Shave or shorten your hair', 'احلق أو قصّر شعرك'),
  kind: ContentKind.instruction,
  guidance: PilgrimageText(
    'Men shave or shorten their hair; women shorten it. No fixed duaa is supplied for this action. Exiting ihram depends on the rites completed and your Hajj type.',
    'يحلق الرجال أو يقصرون، وتقصر النساء. لا نورد دعاءً خاصًا لهذا العمل. والتحلل من الإحرام يتوقف على المناسك التي أديتها ونوع نسكك.',
  ),
  sources: [ritesSource],
);
const mina = PilgrimageContent(
  id: 'mina',
  title: PilgrimageText('Mina • Day of Tarwiyah', 'منى • يوم التروية'),
  action: PilgrimageText(
    'Stay in Mina and continue Talbiyah',
    'بت بمنى وواصل التلبية',
  ),
  kind: ContentKind.instruction,
  guidance: PilgrimageText(
    'On 8 Dhul-Hijjah, pilgrims go to Mina and stay until the next morning. Continue Talbiyah. No separate fixed duaa is supplied for the journey from Makkah to Mina or on the way to Arafah.',
    'في الثامن من ذي الحجة يتوجه الحجاج إلى منى ويبيتون إلى صباح اليوم التالي مع التلبية. لا نورد دعاءً خاصًا للطريق من مكة إلى منى أو إلى عرفة.',
  ),
  sources: [jabirSource],
);
const arafah = PilgrimageContent(
  id: 'arafah',
  title: PilgrimageText('Duaa at Arafah', 'الدعاء بعرفة'),
  action: PilgrimageText(
    'Devote time to duaa and remembrance',
    'أكثر من الدعاء والذكر',
  ),
  kind: ContentKind.instruction,
  guidance: PilgrimageText(
    'On 9 Dhul-Hijjah, devote time to personal duaa, repentance and remembrance, facing the qiblah. The Prophet stayed until sunset. There is no required long script or separate “Arafah night duaa” here.',
    'في التاسع من ذي الحجة أكثر من الدعاء والتوبة والذكر مستقبلاً القبلة. وقف النبي ﷺ إلى غروب الشمس. لا نعرض نصًا طويلاً لازمًا أو دعاءً خاصًا بليلة عرفة.',
  ),
  sources: [jabirSource],
);
const generalTahlil = PilgrimageContent(
  id: 'general_tahlil',
  title: PilgrimageText('General remembrance', 'ذكر عام'),
  kind: ContentKind.generalDua,
  transliteration:
      'Lā ilāha illa llāhu waḥdahu lā sharīka lah, lahu l-mulku wa lahu l-ḥamdu wa huwa ʿalā kulli shay’in qadīr.',
  arabic:
      'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.',
  meaning:
      'No deity deserves worship except Allah alone, without partner. His is all dominion and praise, and He has power over everything.',
  guidance: PilgrimageText(
    'Authentic as general dhikr (Bukhari 6403); no Arafah-specific count is imposed. The Arafah report in Tirmidhi 3585 has differing gradings and is included in the sources for transparency, not to establish a fixed formula.',
    'ذكر صحيح ثابت في البخاري ٦٤٠٣، دون تخصيص عدد بعرفة. رواية الترمذي ٣٥٨٥ الخاصة بعرفة مختلف في درجتها؛ أدرجت في المصادر للتوضيح لا لإثبات صيغة خاصة.',
  ),
  sources: [tahlilSource, arafahReportSource],
);
const personalDua = PilgrimageContent(
  id: 'personal',
  title: PilgrimageText(
    'A Qur’anic duaa you may choose',
    'من الدعاء القرآني الذي يمكنك اختياره',
  ),
  kind: ContentKind.generalDua,
  arabic: cornersArabic,
  meaning: cornersMeaning,
  transliteration: cornersTransliteration,
  guidance: PilgrimageText(
    'An example of general duaa. You may also ask Allah for your own needs in your own words; this is not a fixed formula for this stage.',
    'مثال للدعاء العام. يمكنك سؤال الله حاجاتك بما شئت من الكلام الطيب؛ وليس هذا دعاءً خاصًا بهذه المرحلة.',
  ),
  sources: [generalDuaSource],
);
const muzdalifah = PilgrimageContent(
  id: 'muzdalifah',
  title: PilgrimageText('Remembrance at Muzdalifah', 'الذكر بالمزدلفة'),
  action: PilgrimageText(
    'Stay at Muzdalifah and remember Allah',
    'بت بالمزدلفة واذكر الله',
  ),
  kind: ContentKind.instruction,
  guidance: PilgrimageText(
    'After Arafah comes the night at Muzdalifah. After Fajr, the Prophet faced the qiblah, made duaa, takbir and tahlil, and departed before sunrise. No fixed long supplication is specified. Those with a concession may leave earlier with their group.',
    'بعد عرفة تكون ليلة المزدلفة. وبعد الفجر استقبل النبي ﷺ القبلة ودعا وكبّر وهلّل، ثم دفع قبل طلوع الشمس. لا تحدد رواية جابر دعاءً طويلاً خاصًا. ولأهل الأعذار رخصة في الدفع المبكر مع مجموعتهم.',
  ),
  sources: [muzdalifahSource, jabirSource, ritesSource],
);
const aqabah = PilgrimageContent(
  id: 'aqabah',
  title: PilgrimageText('Takbir with each pebble', 'التكبير مع كل حصاة'),
  kind: ContentKind.riteDhikr,
  arabic: 'اللَّهُ أَكْبَرُ',
  meaning: 'Allah is greater.',
  transliteration: 'Allāhu akbar.',
  guidance: PilgrimageText(
    'On 10 Dhul-Hijjah, throw seven pebbles at Jamarat al-Aqabah, one at a time, saying one takbir with each pebble. Do not stop for duaa afterwards.',
    'في العاشر من ذي الحجة ترمى جمرة العقبة بسبع حصيات متعاقبات، مع تكبيرة واحدة لكل حصاة. لا تقف للدعاء بعدها.',
  ),
  sources: [ramySource, jamaratSource],
);
const sacrifice = PilgrimageContent(
  id: 'sacrifice',
  title: PilgrimageText('When slaughtering', 'عند الذبح'),
  kind: ContentKind.riteDhikr,
  arabic: 'بِسْمِ اللَّهِ، وَاللَّهُ أَكْبَرُ',
  meaning: 'In Allah’s name; Allah is greater.',
  transliteration: 'Bismi llāh, wa llāhu akbar.',
  guidance: PilgrimageText(
    'The person slaughtering mentions Allah’s name and says takbir. This is not a required recitation for a pilgrim whose sacrifice is carried out by an appointed provider.',
    'يسمي الذابح ويكبر. ليست هذه تلاوة مطلوبة من الحاج حين تذبح عنه جهة موكلة.',
  ),
  sources: [sacrificeSource],
);
const acceptance = PilgrimageContent(
  id: 'acceptance',
  title: PilgrimageText('Asking for acceptance', 'سؤال القبول'),
  kind: ContentKind.generalDua,
  arabic: 'اللَّهُمَّ تَقَبَّلْ مِنِّي',
  meaning: 'O Allah, accept from me.',
  transliteration: 'Allāhumma taqabbal minnī.',
  guidance: PilgrimageText(
    'Personal wording adapted from the sacrifice report. Muslim 1967 records the Prophet asking acceptance on behalf of Muhammad, his family and his community; “from me” is an adaptation, not the exact quotation.',
    'صيغة شخصية مستفادة من حديث الذبح. رواية مسلم ١٩٦٧ فيها سؤال النبي ﷺ القبول عن محمد وآل محمد وأمة محمد؛ ولفظ «مني» تكييف للدعاء وليس نص الرواية.',
  ),
  sources: [acceptanceSource],
);
const tashriq = PilgrimageContent(
  id: 'tashriq',
  title: PilgrimageText('Days of Tashriq • Mina', 'أيام التشريق • منى'),
  action: PilgrimageText(
    'Stay in Mina and stone the three Jamarat',
    'بت بمنى وارم الجمرات الثلاث',
  ),
  kind: ContentKind.instruction,
  guidance: PilgrimageText(
    'Remember Allah often. Stay in Mina during the nights of Tashriq as applicable. Stone the three Jamarat after midday on 11 and 12 Dhul-Hijjah, and on 13 if staying. Those leaving early depart Mina before sunset on 12; coordinate concessions with your group.',
    'أكثر من ذكر الله، وبت بمنى ليالي التشريق بحسب ما يلزمك. ترمى الجمرات الثلاث بعد الزوال يومي ١١ و١٢، ويوم ١٣ لمن تأخر. يخرج المتعجل من منى قبل غروب يوم ١٢، وراجع مجموعتك في الرخص.',
  ),
  sources: [tashriqSource, ritesSource],
);
const jamarat = PilgrimageContent(
  id: 'jamarat',
  title: PilgrimageText('The three Jamarat', 'الجمرات الثلاث'),
  kind: ContentKind.riteDhikr,
  arabic: 'اللَّهُ أَكْبَرُ',
  meaning: 'Allah is greater.',
  transliteration: 'Allāhu akbar.',
  guidance: PilgrimageText(
    'Seven pebbles at each Jamarah: say one takbir with each pebble. After the first and middle Jamarah, move aside, face the qiblah, raise your hands and make personal duaa. Do not stop for duaa after the third (al-Aqabah). No fixed duaa or duration is prescribed here.',
    'سبع حصيات لكل جمرة، مع تكبيرة لكل حصاة. بعد الأولى والوسطى ابتعد عن الزحام واستقبل القبلة وارفع يديك وادع. لا تقف للدعاء بعد الثالثة (العقبة). لا نحدد دعاءً أو مدةً خاصة هنا.',
  ),
  sources: [jamaratSource],
);
const farewell = PilgrimageContent(
  id: 'farewell',
  title: PilgrimageText('Farewell Tawaf', 'طواف الوداع'),
  action: PilgrimageText(
    'Perform Tawaf before leaving Makkah',
    'طف بالبيت قبل مغادرة مكة',
  ),
  kind: ContentKind.instruction,
  guidance: PilgrimageText(
    'Before leaving Makkah after Hajj, make Tawaf your final rite at the House. Menstruating women are exempt. Use the usual Tawaf adhkar; no special farewell or Multazam formula is supplied.',
    'قبل مغادرة مكة بعد الحج اجعل آخر عهدك بالبيت الطواف. الحائض معفاة منه. استخدم أذكار الطواف المعتادة؛ لا نورد صيغة خاصة للوداع أو الملتزم.',
  ),
  sources: [farewellSource],
);

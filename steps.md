I'd like you to implement daily routine for everyday muslim.
a button in homepage in activities section will open Daily Routines page.
Button will have an icon of daily_routine/daily-routine.png.
Main idea of daily routine is to follow Sunnah such as sunnah prayers and Morning and Night azkar.
When the user opens the daily routine page, it should show a nice timeline expecting from the user to check what he has done already.
Checking should be saved in shared preference for this day and it will be removed from shared preference as well after the preiod same as prayer timings to avoid storage expansion.
when long press on the item, it should show a modal with more details such as if user clicked on morning Azkar, it should show a modal with title Morning azkar, and all the morning azkar he should say. Single tab should check or uncheck the item.
The following are the sunnahs that I want you to implement with the correct timeline in Arabic:

السنن الرواتب: وهي 12 ركعة في اليوم والليلة (ركعتان قبل الفجر، 4 قبل الظهر وركعتان بعده، ركعتان بعد المغرب، وركعتان بعد العشاء) تبني لك بيتاً في الجنة.
صلاة الضحى: وقتها من بعد شروق الشمس بثلث ساعة إلى ما قبل الظهر، وأقلها ركعتان.
الوتر: ركعة واحدة أو أكثر قبل النوم لمن يخشى ألا يقوم آخره.


أذكار الصباح والمساء: تقال بعد الفجر وبعد العصر لحفظ المسلم

أذكار النوم: الوضوء قبل النوم

دعاء الاستيقاظ

الاستغفار: قل "أستغفر الله" (3 مرات) ثم "اللهم أنت السلام ومنك السلام، تباركت يا ذا الجلال والإكرام" بعد كل صلاه

التسبيح والتحميد والتكبير: قل سبحان الله (33 مرة)، والحمد لله (33 مرة)، والله أكبر (33 مرة)، وتتم المائة بقول: "لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير" بعد كل صلاه

صلى الله عليه وسلم كان يقول بعد الصلاة: لا إله إلا الله وحده لا شريك له، له الملك، وله الحمد وهو على كل شيء قدير، اللهم لا مانع لما أعطيت، ولا معطي لما منعت، ولا ينفع ذا الجد منك الجد.

قراءة المعوذات وآية الكرسي: اقرأ آية الكرسي، وسورة الإخلاص، وسورة الفلق، وسورة الناس مرة واحدة بعد كل صلاة، وتُكرر ثلاث مرات بعد صلاة الفجر والمغرب.

The previous Sunnah should be in correct order so you can use the web to get more details of these and to draw a correct timeline of it.

Details such as Ayat Al Korsy should appear when long press on the item and written in correct dialect. Use the web to get that. Same as the Azkar and rest of Sunnah items.

When user finishes all the items, celebration should appear.
Progress bar should be visible at top pinned to show the progress of the daily routine in a stylish way.
Progress bar should be dynamic with the number of items as I might add or remove elements.
In the new day, all items should be unchecked to start a new day of daily routine.

New day starts from Fajr timing which can be brought from prayer timings in homepage. This might be tricky with the caching in shared preference so make sure you handle that well.

Only between Thursday and friday, Surat Al Kahf should be read After Maghrib on Thursday till Maghrib of Friday. This also can be tricky in storing in shared preference so make sure you handle all these details. 

Titles and names should be translated in both English and Arabic properly except the details of the Azkar and Quran should be written in Arabic only while handling right to left.

Timeline background can be a good addition, with meaningful colors and meaningful icons such as Sun in the morning and Moon in the night. You can use the web to download suitable icons in png and put them in assets/daily_routine directory or you can draw them yourself or use whatever is available if you can find.
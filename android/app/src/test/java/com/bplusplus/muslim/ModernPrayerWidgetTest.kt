package com.bplusplus.muslim

import android.app.Application
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.SizeF
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ModernPrayerWidgetTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private val keys = listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")

    private fun data(arabic: Boolean = false, next: String = "asr") =
        context.getSharedPreferences("modern-widget-test", Context.MODE_PRIVATE).also { prefs ->
            val labels = if (arabic) listOf("الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء")
                else listOf("Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha")
            val times = listOf("05:10", "06:35", "12:45", "16:20", "18:50", "20:15")
            prefs.edit().clear().apply {
                keys.forEachIndexed { i, key ->
                    putString("${key}_label", labels[i]); putString("${key}_text", times[i])
                }
                putString("hijriDate_text", "30-03-1448")
                putString("gregorianDate_text", "12-09-2026")
                putString("next_prayer_key", next)
            }.commit()
        }

    private fun render(wide: Boolean, width: Int, height: Int, arabic: Boolean = false,
                       next: String = "asr", twelveHour: Boolean = false): View {
        val provider = if (wide) HomeAppWidgetWideModern() else HomeAppWidgetPortraitModern()
        val prefs = data(arabic, next)
        if (twelveHour) prefs.edit().apply {
            keys.forEach { putString("${it}_text", if (arabic) "١٢:٤٥ م" else "12:45 PM") }
        }.commit()
        val remote = provider.createViews(context, prefs, SizeF(width.toFloat(), height.toFloat()))
        val view = remote.apply(context, FrameLayout(context))
        val density = context.resources.displayMetrics.density
        view.measure(View.MeasureSpec.makeMeasureSpec((width * density).toInt(), View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec((height * density).toInt(), View.MeasureSpec.EXACTLY))
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
        view.viewTreeObserver.dispatchOnPreDraw()
        return view
    }

    private fun assertTextFits(view: View) {
        if (view.visibility != View.VISIBLE) return
        if (view is TextView && view.text.isNotEmpty()) {
            val name = context.resources.getResourceEntryName(view.id)
            assertTrue("$name has no width", view.width > 0)
            assertTrue("$name clips vertically", view.layout.height <= view.height - view.paddingTop - view.paddingBottom)
            assertEquals("$name is ellipsized", 0, view.layout.getEllipsisCount(0))
        }
        if (view is ViewGroup) (0 until view.childCount).forEach { assertTextFits(view.getChildAt(it)) }
    }

    @Test fun compactAndExpandedLayoutsFitBothLanguages() {
        for (arabic in listOf(false, true)) {
            for ((wide, sizes) in listOf(true to listOf(320 to 48, 400 to 150),
                false to listOf(110 to 110, 180 to 110, 180 to 180, 240 to 360))) {
                for ((width, height) in sizes) {
                    val view = render(wide, width, height, arabic)
                    assertTextFits(view)
                    assertEquals(if (arabic) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR, view.layoutDirection)
                    val hideMarker = if (wide) height < 100 else height < 150 || width < 150
                    assertEquals(if (hideMarker) View.GONE else View.VISIBLE,
                        view.findViewById<View>(R.id.modern_asr_indicator).visibility)
                    assertEquals(if (hideMarker) View.GONE else View.INVISIBLE,
                        view.findViewById<View>(R.id.modern_fajr_indicator).visibility)
                    val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
                    view.draw(Canvas(bitmap))
                    val output = File("../../build/widget-previews/${if (wide) "wide" else "portrait"}-${width}x$height-${if (arabic) "ar" else "en"}.png")
                    output.parentFile?.mkdirs()
                    output.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    bitmap.recycle()
                }
            }
        }
    }

    @Test fun resizingKeepsDatesVisibleAndExpandsTheSchedule() {
        assertEquals(View.VISIBLE, render(true, 320, 48).findViewById<View>(R.id.modern_dates).visibility)
        assertEquals(View.VISIBLE, render(true, 400, 150).findViewById<View>(R.id.modern_dates).visibility)
        val compact = render(false, 180, 110)
        val tall = render(false, 240, 360)
        assertTrue(tall.findViewById<View>(R.id.asr_card).height > compact.findViewById<View>(R.id.asr_card).height)
        assertTrue(tall.findViewById<TextView>(R.id.asr_text).textSize > compact.findViewById<TextView>(R.id.asr_text).textSize)
        assertEquals("16:20", tall.findViewById<TextView>(R.id.asr_text).text.toString())
        assertEquals(View.INVISIBLE, render(false, 240, 360, next = "").findViewById<View>(R.id.modern_asr_indicator).visibility)
    }

    @Test fun largeSystemFontsFitAndKeepCompactLayout() {
        RuntimeEnvironment.setFontScale(1.5f)
        try {
            assertTextFits(render(false, 240, 360, arabic = true))
            assertTextFits(render(false, 110, 110, arabic = true, twelveHour = true))
            assertTextFits(render(true, 500, 100))
        } finally {
            RuntimeEnvironment.setFontScale(1f)
        }
    }

    @Test fun twelveHourTimesFitBothDesigns() {
        for (arabic in listOf(false, true)) {
            assertTextFits(render(true, 320, 48, arabic, twelveHour = true))
            assertTextFits(render(false, 180, 180, arabic, twelveHour = true))
            assertTextFits(render(false, 110, 110, arabic, twelveHour = true))
        }
    }

    @Test
    @Config(sdk = [24])
    @GraphicsMode(GraphicsMode.Mode.LEGACY)
    fun bothDesignsApplyOnOldestSupportedAndroid() {
        for (wide in listOf(false, true)) {
            val view = render(wide, 320, if (wide) 60 else 360)
            assertEquals("16:20", view.findViewById<TextView>(R.id.asr_text).text.toString())
        }
    }
}

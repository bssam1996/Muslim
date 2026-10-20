package com.bplusplus.muslim

import android.app.Application
import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.SizeF
import android.view.View
import android.widget.FrameLayout
import android.widget.RemoteViews
import android.widget.TextView
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class WidgetAppearanceTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private val designs = listOf("portrait", "wide", "modernPortrait", "modernWide")

    private fun configuration(dark: Boolean): Context {
        val config = Configuration(context.resources.configuration)
        config.uiMode = (config.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
            if (dark) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
        return context.createConfigurationContext(config)
    }

    private fun views(design: String, mode: String?, dark: Boolean): RemoteViews {
        val ctx = configuration(dark)
        val data = context.getSharedPreferences("widget-appearance-test", Context.MODE_PRIVATE)
        data.edit().clear().putString("widget_theme_mode", mode)
            .putString("prayer_data_date", SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()))
            .putLong("next_prayer_epoch_ms", System.currentTimeMillis() + 3600000L)
            .putString("next_prayer_key", "asr").putString("asr_text", "16:20").commit()
        return when (design) {
            "portrait" -> HomeAppWidget().createViews(ctx, data)
            "wide" -> HomeAppWidgetWide().createViews(ctx, data, SizeF(400f, 100f))
            "modernPortrait" -> HomeAppWidgetPortraitModern().createViews(ctx, data, SizeF(240f, 360f))
            else -> HomeAppWidgetWideModern().createViews(ctx, data, SizeF(400f, 150f))
        }
    }

    private fun apply(views: RemoteViews, dark: Boolean): View {
        val ctx = configuration(dark)
        return views.apply(ctx, FrameLayout(ctx))
    }

    private fun colors(view: View): IntArray {
        val background = view.background as GradientDrawable
        return background.colors ?: intArrayOf(background.color!!.defaultColor)
    }

    private fun contrast(text: Int, background: Int): Double {
        val a = Color.luminance(text).toDouble()
        val b = Color.luminance(background).toDouble()
        return (maxOf(a, b) + 0.05) / (minOf(a, b) + 0.05)
    }

    private fun assertPalette(view: View, design: String, dark: Boolean) {
        colors(view).forEach { color ->
            assertEquals("$design root brightness", !dark, Color.luminance(color) > 0.5f)
        }
        val modern = design.startsWith("modern")
        val highlighted = view.findViewById<TextView>(R.id.asr_text)
        assertEquals("16:20", highlighted.text.toString())
        val expectedHighlight = if (modern) {
            if (dark) "#E6C885" else "#805A12"
        } else if (dark) "#FFFFFF" else "#123957"
        assertEquals("$design next-prayer text", Color.parseColor(expectedHighlight), highlighted.currentTextColor)
        for ((label, time, card) in listOf(
            Triple(R.id.fajr_label, R.id.fajr_text, R.id.fajr_card),
            Triple(R.id.asr_label, R.id.asr_text, R.id.asr_card)
        )) {
            for (id in listOf(label, time)) {
                val text = view.findViewById<TextView>(id)
                val surface = when {
                    design == "portrait" -> text
                    design == "wide" || id in listOf(R.id.asr_label, R.id.asr_text) -> view.findViewById(card)
                    else -> view
                }
                // Enforce normal-text contrast for every new light surface.
                if (!dark) colors(surface).forEach { color ->
                    assertTrue("$design light text contrast ${contrast(text.currentTextColor, color)}",
                        contrast(text.currentTextColor, color) >= 4.5)
                }
            }
        }
        val dateIds = if (modern) listOf(R.id.modern_hijri_top, R.id.modern_gregorian_top)
            else listOf(R.id.hijriDate_text, R.id.gregorianDate_text)
        dateIds.forEach { id ->
            val text = view.findViewById<TextView>(id)
            colors(if (modern) view else view.findViewById(R.id.widget_header)).forEach { color ->
                assertTrue("$design date contrast", contrast(text.currentTextColor, color) >= 4.5)
            }
        }
    }

    @Test fun forcedThemesOverrideOppositeDeviceThemeForAllFourWidgets() {
        for (design in designs) {
            for (dark in listOf(false, true)) {
                val remote = views(design, if (dark) "dark" else "light", !dark)
                assertPalette(apply(remote, !dark), design, dark)
            }
        }
    }

    @Test fun defaultAndUnknownModesFollowDeviceForAllFourWidgets() {
        for (design in designs) {
            for (mode in listOf(null, "system", "unknown")) {
                for (dark in listOf(false, true)) {
                    assertPalette(apply(views(design, mode, dark), dark), design, dark)
                }
            }
        }
    }

    @Test fun systemViewsResolveAgainWhenLauncherChangesTheme() {
        for (design in designs) {
            val remote = views(design, "system", false)
            assertPalette(apply(remote, false), design, false)
            assertPalette(apply(remote, true), design, true)
        }
    }

    @Test
    @Config(sdk = [24])
    fun themesRenderOnOldestSupportedAndroid() {
        for (design in designs) {
            for (dark in listOf(false, true)) {
                for (mode in listOf("system", if (dark) "dark" else "light")) {
                    assertPalette(apply(views(design, mode, dark), dark), design, dark)
                }
            }
        }
    }
}

package com.bplusplus.muslim

import android.app.Application
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.res.Configuration
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/** Refresh legacy RemoteViews colors when the device theme changes while our process is alive. */
class MuslimApplication : Application() {
    private var nightMode = Configuration.UI_MODE_NIGHT_UNDEFINED

    override fun onCreate() {
        super.onCreate()
        nightMode = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        val updatedMode = newConfig.uiMode and Configuration.UI_MODE_NIGHT_MASK
        if (nightMode == updatedMode) return
        nightMode = updatedMode
        val data = HomeWidgetPlugin.getData(this)
        if (data.getString("widget_theme_mode", "system") in listOf("light", "dark")) return
        val manager = AppWidgetManager.getInstance(this)
        val providers = listOf<HomeWidgetProvider>(HomeAppWidget(), HomeAppWidgetWide(),
            HomeAppWidgetPortraitModern(), HomeAppWidgetWideModern())
        providers.forEach { provider ->
            val ids = manager.getAppWidgetIds(ComponentName(this, provider.javaClass))
            if (ids.isNotEmpty()) provider.onUpdate(this, manager, ids, data)
        }
    }
}

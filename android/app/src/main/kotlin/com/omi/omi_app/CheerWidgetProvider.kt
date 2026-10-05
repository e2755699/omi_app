package com.omi.omi_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 桌面小工具：今天幾個人幫你加油，加上今天要打卡的鍵帽。
 * 按鍵帽會在背景執行 Dart（home_widget_bridge.dart 的 homeWidgetInteraction）直接打卡，不用打開 App。
 */
class CheerWidgetProvider : HomeWidgetProvider() {
    private val keyViews = intArrayOf(
        R.id.widget_key_0, R.id.widget_key_1, R.id.widget_key_2, R.id.widget_key_3,
        R.id.widget_key_4, R.id.widget_key_5, R.id.widget_key_6, R.id.widget_key_7,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val density = context.resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.cheer_widget).apply {
                setTextViewText(R.id.widget_day, widgetData.getString("day_text", "100 DAYS"))
                setTextViewText(R.id.widget_cheers, widgetData.getString("cheers_text", ""))
                setTextViewText(R.id.widget_footer, widgetData.getString("footer_text", "打開 App ›"))
                setTextViewText(R.id.widget_message, widgetData.getString("message_text", "打開 App 完成設定"))

                val enabled = widgetData.getString("keys_enabled", "0") == "1"
                setViewVisibility(R.id.widget_keys, if (enabled) View.VISIBLE else View.GONE)
                setViewVisibility(R.id.widget_message, if (enabled) View.GONE else View.VISIBLE)

                val count = widgetData.getString("key_count", "0")?.toIntOrNull() ?: 0
                keyViews.forEachIndexed { i, viewId ->
                    if (i >= count) {
                        setViewVisibility(viewId, View.INVISIBLE)
                        return@forEachIndexed
                    }
                    val on = widgetData.getString("key_${i}_on", "0") == "1"
                    val item = widgetData.getString("key_${i}_id", "") ?: ""
                    setViewVisibility(viewId, View.VISIBLE)
                    setTextViewText(viewId, widgetData.getString("key_${i}_label", ""))
                    setInt(
                        viewId,
                        "setBackgroundResource",
                        if (on) litKey(widgetData.getString("key_${i}_pillar", "")) else R.drawable.widget_key_off,
                    )
                    // 按下去的鍵帽頂面比較低，字也跟著往下。
                    if (on) {
                        setViewPadding(viewId, dp(4), dp(7), dp(4), dp(4))
                    } else {
                        setViewPadding(viewId, dp(4), dp(3), dp(4), dp(7))
                    }
                    setOnClickPendingIntent(
                        viewId,
                        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("omiapp://toggle?item=$item")),
                    )
                }

                val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_header, openApp)
                setOnClickPendingIntent(R.id.widget_message, openApp)
                setOnClickPendingIntent(
                    R.id.widget_footer,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("omiapp://checkin"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun litKey(pillar: String?) = when (pillar) {
        "nourish" -> R.drawable.widget_key_on_nourish
        "learn" -> R.drawable.widget_key_on_learn
        "recover" -> R.drawable.widget_key_on_recover
        else -> R.drawable.widget_key_on_move
    }
}

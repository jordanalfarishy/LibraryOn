package com.libraryon.android

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.widget.TextView

object Ui {
    const val background = 0xFFF6F4FB.toInt()
    const val ink = 0xFF24213D.toInt()
    const val muted = 0xFF746F88.toInt()
    const val accent = 0xFF6655C6.toInt()
    const val accentPale = 0xFFEAE6FA.toInt()

    fun Context.dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    fun rounded(color: Int, radius: Float = 18f, stroke: Int? = null): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = radius
            if (stroke != null) setStroke(1, stroke)
        }

    fun text(context: Context, value: String, size: Float, color: Int = ink, bold: Boolean = false) =
        TextView(context).apply {
            text = value
            textSize = size
            setTextColor(color)
            if (bold) typeface = Typeface.create("sans-serif", Typeface.BOLD)
        }

    fun button(context: Context, value: String, primary: Boolean = false) =
        TextView(context).apply {
            text = value
            textSize = 14f
            setTextColor(if (primary) Color.WHITE else accent)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = android.view.Gravity.CENTER
            background = rounded(if (primary) accent else accentPale, context.dp(13).toFloat())
            setPadding(context.dp(14), context.dp(10), context.dp(14), context.dp(10))
            isClickable = true
            isFocusable = true
        }

    fun View.pad(all: Int) = setPadding(context.dp(all), context.dp(all), context.dp(all), context.dp(all))
}

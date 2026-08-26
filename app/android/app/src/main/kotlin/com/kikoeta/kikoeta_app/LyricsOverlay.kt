package com.kikoeta.kikoeta_app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.common.MethodChannel

/**
 * 安卓桌面歌词悬浮窗（WindowManager 覆盖层）。
 * - 竖屏：宽度占满；横屏：宽度 = 竖屏宽度（portraitWidthDp）
 * - 未锁定：可拖动（拖动后位置保留），点击歌词显示锁定按钮
 * - 锁定：FLAG_NOT_TOUCHABLE 点击穿透；只能在设置里解锁
 * - 锁定状态按横/竖屏分开记忆（由 Dart 侧保存）
 */
class LyricsOverlay(
    private val context: Context,
    private val events: MethodChannel,
) {
    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    private var root: LinearLayout? = null
    private var textView: TextView? = null
    private var lockBtn: View? = null
    private var visible = false
    private var locked = false
    private var portrait = true
    private var overlayWidth = WindowManager.LayoutParams.MATCH_PARENT
    private var fontSize = 20f
    private var color = Color.WHITE
    private var outlineColor = Color.BLACK
    private var outlineWidth = 1f

    // 当前窗口坐标（CENTER_HORIZONTAL 下 x 为相对水平中心的偏移）
    private var winX = 0
    private var winY = 0
    // 拖动状态
    private var touchStartX = 0f
    private var touchStartY = 0f
    private var winStartX = 0
    private var winStartY = 0
    private var dragging = false

    fun isAvailable(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(context)

    fun show(
        text: String,
        fontSize: Double,
        color: Int,
        outlineColor: Int,
        outlineWidth: Double,
        locked: Boolean,
        portrait: Boolean,
        portraitWidthDp: Double,
    ) {
        this.portrait = portrait
        overlayWidth = if (portrait) {
            WindowManager.LayoutParams.MATCH_PARENT
        } else {
            dp(portraitWidthDp.toInt())
        }
        this.locked = locked
        this.fontSize = fontSize.toFloat()
        this.color = color
        this.outlineColor = outlineColor
        this.outlineWidth = outlineWidth.toFloat()
        if (root == null) buildOverlay()
        textView?.text = text
        textView?.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, this.fontSize)
        textView?.setTextColor(this.color)
        textView?.setShadowLayer(this.outlineWidth, 0f, 0f, this.outlineColor)
        if (!visible) {
            // 仅首次显示时初始化位置；之后歌词行更新不重置拖动位置
            winX = 0
            winY = dp(90)
            wm.addView(root, params())
            visible = true
        } else {
            constrainPosition()
            wm.updateViewLayout(root, params())
        }
    }

    private fun buildOverlay() {
        // 纵向布局：上一排为锁定按钮（独立占位，不覆盖歌词），下方为歌词文本
        val root = LinearLayout(context)
        root.orientation = LinearLayout.VERTICAL
        root.gravity = Gravity.CENTER_HORIZONTAL

        // 锁定键：歌词上方一行、水平居中；始终占位（歌词不因按钮显隐而移动），
        // 平时不可见，点击歌词后显示（INVISIBLE 占位不显示，避免歌词跳动）
        val btn = LockIconView(context)
        btn.visibility = View.INVISIBLE
        root.addView(
            btn,
            LinearLayout.LayoutParams(dp(30), dp(30)).apply { bottomMargin = dp(6) },
        )

        val tv = TextView(context)
        tv.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, fontSize)
        tv.setTextColor(color)
        tv.setShadowLayer(outlineWidth.toFloat(), 0f, 0f, outlineColor)
        tv.gravity = Gravity.CENTER
        tv.maxLines = 2
        tv.ellipsize = TextUtils.TruncateAt.END
        // 内边距防止描边（outline）在窗口边缘被裁剪
        tv.setPadding(dp(4), dp(3), dp(4), dp(3))
        root.addView(
            tv,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        // 歌词文本同时负责点击和拖拽。ACTION_DOWN 必须消费，否则 Android 不会
        // 分派同一次手势后续的 MOVE/UP 事件，导致悬浮窗无法拖动。
        tv.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    touchStartX = event.rawX
                    touchStartY = event.rawY
                    winStartX = winX
                    winStartY = winY
                    dragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchStartX
                    val dy = event.rawY - touchStartY
                    val slop = ViewConfiguration.get(context).scaledTouchSlop
                    if (!dragging && (Math.abs(dx) > slop || Math.abs(dy) > slop)) {
                        dragging = true
                    }
                    if (dragging) {
                        moveTo((winStartX + dx).toInt(), (winStartY + dy).toInt())
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val wasDragging = dragging
                    dragging = false
                    if (!wasDragging && event.action == MotionEvent.ACTION_UP && !locked) {
                        btn.visibility =
                            if (btn.visibility == View.VISIBLE) View.INVISIBLE else View.VISIBLE
                    }
                    true
                }
                else -> true
            }
        }
        btn.setOnClickListener {
            locked = true
            btn.visibility = View.INVISIBLE
            applyTouchable()
            events.invokeMethod("lockChanged", mapOf("portrait" to portrait, "locked" to true))
        }

        this.root = root
        textView = tv
        lockBtn = btn
    }

    private fun moveTo(x: Int, y: Int) {
        winX = x
        winY = y
        constrainPosition()
        root?.let { wm.updateViewLayout(it, params()) }
    }

    private fun constrainPosition() {
        val screenW = context.resources.displayMetrics.widthPixels
        val screenH = context.resources.displayMetrics.heightPixels
        val maxX = if (portrait || overlayWidth >= screenW) {
            0
        } else {
            ((screenW - overlayWidth).coerceAtLeast(0)) / 2
        }
        val height = root?.height?.takeIf { it > 0 } ?: dp(60)
        winX = winX.coerceIn(-maxX, maxX)
        winY = winY.coerceIn(0, (screenH - height).coerceAtLeast(0))
    }

    private fun params(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        var flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        if (locked) flags = flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        return WindowManager.LayoutParams(
            overlayWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            flags,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = winX
            y = winY
        }
    }

    private fun applyTouchable() {
        root?.let { wm.updateViewLayout(it, params()) }
    }

    fun update(text: String) {
        textView?.text = text
    }

    fun setLocked(locked: Boolean) {
        this.locked = locked
        lockBtn?.visibility = View.INVISIBLE
        if (visible) applyTouchable()
    }

    fun setStyle(fontSize: Double, color: Int, outlineColor: Int, outlineWidth: Double) {
        this.fontSize = fontSize.toFloat()
        this.color = color
        this.outlineColor = outlineColor
        this.outlineWidth = outlineWidth.toFloat()
        textView?.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, this.fontSize)
        textView?.setTextColor(this.color)
        textView?.setShadowLayer(this.outlineWidth, 0f, 0f, this.outlineColor)
    }

    fun hide() {
        root?.let { if (visible) wm.removeView(it) }
        visible = false
    }

    private fun dp(v: Int): Int = (v * context.resources.displayMetrics.density).toInt()
}

/** 锁定键：与 Windows 悬浮窗一致的 SVG 锁图标（48 viewBox 路径光栅化），半透明圆底 */
class LockIconView(context: Context) : View(context) {
    private val bgPaint = Paint().apply {
        color = 0x99333333.toInt()
        style = Paint.Style.FILL
        isAntiAlias = true
    }
    private val paint = Paint().apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        isAntiAlias = true
    }

    private val body = Path().apply {
        addRoundRect(RectF(6f, 22f, 42f, 44f), 2f, 2f, Path.Direction.CW)
    }
    private val arch = Path().apply {
        moveTo(14f, 22f)
        lineTo(14f, 14f)
        cubicTo(14f, 8.477f, 18.477f, 4f, 24f, 4f)
        cubicTo(29.523f, 4f, 34f, 8.477f, 34f, 14f)
        lineTo(34f, 22f)
    }
    private val keyhole = Path().apply {
        moveTo(24f, 30f)
        lineTo(24f, 36f)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        // 半透明深色圆底：亮/暗背景下图标均清晰可见
        canvas.drawCircle(width / 2f, height / 2f, Math.min(width, height) / 2f, bgPaint)
        // 图标占 view 约 78%，避免顶满按钮
        val s = Math.min(width.toFloat(), height.toFloat()) * 0.78f
        val scale = s / 48f
        canvas.save()
        canvas.translate((width - 48f * scale) / 2f, (height - 48f * scale) / 2f)
        canvas.scale(scale, scale)
        // 描边宽度在缩放后保持视觉一致
        paint.strokeWidth = dp(2.6f) / scale
        canvas.drawPath(body, paint)
        canvas.drawPath(arch, paint)
        canvas.drawPath(keyhole, paint)
        canvas.restore()
    }

    private fun dp(v: Float): Float = v * context.resources.displayMetrics.density
}

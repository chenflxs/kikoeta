package com.kikoeta.kikoeta_app

import android.content.Context
import android.content.res.Configuration
import android.hardware.display.DisplayManager
import android.hardware.input.InputManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Point
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.common.MethodChannel
import kotlin.math.ceil

/**
 * 安卓桌面歌词悬浮窗（WindowManager 覆盖层）。
 * - 竖屏：宽度占满；横屏：宽度为当前窗口宽度的一半，可左右拖动
 * - 未锁定：可拖动（拖动后位置保留），点击歌词显示锁定按钮，5 秒后自动隐藏
 * - 锁定：FLAG_NOT_TOUCHABLE 点击穿透；可通过媒体卡片或设置解锁
 * - 横竖屏共用一个锁定状态（由 Dart 侧保存）
 */
class LyricsOverlay(
    private val context: Context,
    private val events: MethodChannel,
) {
    companion object {
        // SYSTEM_ALERT_WINDOW does not belong to the Activity window. If Android keeps the
        // process alive after the task is closed, a newly-created Activity must first remove
        // the overlay owned by the previous Activity or both views will remain on screen.
        private var activeOverlay: LyricsOverlay? = null
    }

    @Suppress("DEPRECATION")
    private val display =
        (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay
    // An Activity left in the background can retain its portrait configuration while
    // another app rotates the display. The overlay needs its own visual context.
    private val overlayContext = context.applicationContext.createDisplayContext(display).let {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            it.createWindowContext(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, null)
        } else {
            it
        }
    }
    private val wm = overlayContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val displayManager =
        overlayContext.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val legacyDisplaySize = Point()
    private var listeningForDisplayChanges = false

    private var root: LinearLayout? = null
    private var textView: OutlinedLyricsTextView? = null
    private var lockBtn: View? = null
    private var visible = false
    private var locked = false
    private var screenWidth = 0
    private var screenHeight = 0
    private var overlayWidth = WindowManager.LayoutParams.MATCH_PARENT
    private var fontSize = 20f
    private var color = Color.WHITE
    private var outlineColor = Color.BLACK
    private var outlineWidth = 1f
    private var opacityPercent = 100
    private var followSystemFont = false

    // 复用应用已打包的 Sarasa UI SC 粗体。
    private val lyricsTypeface: Typeface by lazy {
        runCatching {
            Typeface.createFromAsset(
                context.assets,
                "flutter_assets/assets/fonts/sarasa-ui-sc-bold.ttf",
            )
        }.getOrDefault(Typeface.DEFAULT_BOLD)
    }

    private val positionPreferences = context.applicationContext.getSharedPreferences(
        "lyrics_overlay_position",
        Context.MODE_PRIVATE,
    )
    // CENTER_HORIZONTAL 下 x 为相对水平中心的偏移。
    private var winX = positionPreferences.getInt("x", 0)
    private var winY = positionPreferences.getInt("y", dp(90))
    // 拖动状态
    private var touchStartX = 0f
    private var touchStartY = 0f
    private var winStartX = 0
    private var winStartY = 0
    private var dragging = false

    private val autoHideLockButton = Runnable {
        lockBtn?.visibility = View.INVISIBLE
    }

    private fun hideLockButton() {
        mainHandler.removeCallbacks(autoHideLockButton)
        lockBtn?.visibility = View.INVISIBLE
    }

    private fun toggleLockButton() {
        val button = lockBtn ?: return
        mainHandler.removeCallbacks(autoHideLockButton)
        if (button.visibility == View.VISIBLE) {
            button.visibility = View.INVISIBLE
        } else {
            button.visibility = View.VISIBLE
            mainHandler.postDelayed(autoHideLockButton, 5_000L)
        }
    }

    private val refreshDisplayLayout = Runnable {
        if (visible && refreshDisplayGeometry()) {
            dragging = false
            hideLockButton()
            constrainPosition()
            root?.let { wm.updateViewLayout(it, params()) }
        }
    }

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {}
        override fun onDisplayRemoved(displayId: Int) {}
        override fun onDisplayChanged(displayId: Int) {
            if (displayId == display.displayId) scheduleDisplayLayout()
        }
    }

    private fun scheduleDisplayLayout() {
        root?.let {
            it.removeCallbacks(refreshDisplayLayout)
            it.post(refreshDisplayLayout)
        }
    }

    private fun refreshDisplayGeometry(): Boolean {
        val previousWidth = screenWidth
        val previousHeight = screenHeight
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = wm.currentWindowMetrics.bounds
            screenWidth = bounds.width()
            screenHeight = bounds.height()
        } else {
            @Suppress("DEPRECATION")
            display.getRealSize(legacyDisplaySize)
            screenWidth = legacyDisplaySize.x
            screenHeight = legacyDisplaySize.y
        }
        overlayWidth = if (screenWidth > screenHeight) {
            (screenWidth / 2).coerceAtLeast(1)
        } else {
            WindowManager.LayoutParams.MATCH_PARENT
        }
        return screenWidth != previousWidth || screenHeight != previousHeight
    }

    fun isAvailable(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(context)

    fun show(
        text: String,
        fontSize: Double,
        color: Int,
        outlineColor: Int,
        outlineWidth: Double,
        locked: Boolean,
        opacityPercent: Int,
        followSystemFont: Boolean,
    ) {
        if (activeOverlay !== this) {
            activeOverlay?.hide()
            activeOverlay = this
        }
        refreshDisplayGeometry()
        // State pushed from the media card arrives through show(), not setLocked().
        // Close the transient button before the window starts passing touches through.
        if (this.locked != locked || locked) {
            hideLockButton()
            dragging = false
        }
        this.locked = locked
        this.opacityPercent = opacityPercent.coerceIn(10, 100)
        this.followSystemFont = followSystemFont
        setStyle(fontSize, color, outlineColor, outlineWidth)
        if (root == null) buildOverlay()
        textView?.let { if (!TextUtils.equals(it.text, text)) it.text = text }
        if (!visible) {
            constrainPosition()
            wm.addView(root, params())
            visible = true
            if (!listeningForDisplayChanges) {
                displayManager.registerDisplayListener(displayListener, mainHandler)
                listeningForDisplayChanges = true
            }
        } else {
            constrainPosition()
            wm.updateViewLayout(root, params())
        }
    }

    private fun buildOverlay() {
        // 纵向布局：上一排为锁定按钮（独立占位，不覆盖歌词），下方为歌词文本
        val root = object : LinearLayout(overlayContext) {
            override fun onConfigurationChanged(newConfig: Configuration) {
                super.onConfigurationChanged(newConfig)
                scheduleDisplayLayout()
            }
        }
        root.orientation = LinearLayout.VERTICAL
        root.gravity = Gravity.CENTER_HORIZONTAL

        // 锁定键：歌词上方一行、水平居中；始终占位（歌词不因按钮显隐而移动），
        // 平时不可见，点击歌词后显示（INVISIBLE 占位不显示，避免歌词跳动）
        val btn = LockIconView(overlayContext)
        btn.visibility = View.INVISIBLE
        root.addView(
            btn,
            LinearLayout.LayoutParams(dp(30), dp(30)).apply { bottomMargin = dp(6) },
        )

        val tv = OutlinedLyricsTextView(overlayContext)
        tv.gravity = Gravity.CENTER
        tv.maxLines = 2
        tv.ellipsize = TextUtils.TruncateAt.END
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
                    // Also refresh at gesture start if a display callback is still queued.
                    refreshDisplayLayout.run()
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
                    val slop = ViewConfiguration.get(overlayContext).scaledTouchSlop
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
                    if (wasDragging && (winX != winStartX || winY != winStartY)) {
                        positionPreferences.edit().putInt("x", winX).putInt("y", winY).apply()
                    } else if (!wasDragging && event.action == MotionEvent.ACTION_UP && !locked) {
                        toggleLockButton()
                    }
                    true
                }
                else -> true
            }
        }
        btn.setOnClickListener {
            setLocked(true)
            events.invokeMethod("lockChanged", mapOf("locked" to true))
        }

        this.root = root
        textView = tv
        applyTextStyle()
        lockBtn = btn
    }

    private fun moveTo(x: Int, y: Int) {
        winX = x
        winY = y
        constrainPosition()
        root?.let { wm.updateViewLayout(it, params()) }
    }

    private fun constrainPosition() {
        val maxX = if (overlayWidth == WindowManager.LayoutParams.MATCH_PARENT) {
            0
        } else {
            ((screenWidth - overlayWidth).coerceAtLeast(0)) / 2
        }
        val height = root?.height?.takeIf { it > 0 } ?: dp(60)
        winX = winX.coerceIn(-maxX, maxX)
        winY = winY.coerceIn(0, (screenHeight - height).coerceAtLeast(0))
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
            // Android 12+ also checks opacity when passing touches through overlays.
            val maxOpacity = if (locked && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(InputManager::class.java)
                    .maximumObscuringOpacityForTouch
            } else {
                1f
            }
            alpha = maxOpacity * (opacityPercent / 100f)
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
        hideLockButton()
        dragging = false
        if (visible) applyTouchable()
    }

    fun setStyle(fontSize: Double, color: Int, outlineColor: Int, outlineWidth: Double) {
        this.fontSize = fontSize.toFloat()
        this.color = color
        this.outlineColor = outlineColor
        this.outlineWidth = outlineWidth.toFloat()
        applyTextStyle()
    }

    private fun applyTextStyle() {
        val view = textView ?: return
        view.typeface = if (followSystemFont) Typeface.DEFAULT_BOLD else lyricsTypeface
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSize)
        view.setTextColor(color)
        view.setOutline(outlineColor, outlineWidth)
    }

    fun hide() {
        hideLockButton()
        root?.removeCallbacks(refreshDisplayLayout)
        if (listeningForDisplayChanges) {
            displayManager.unregisterDisplayListener(displayListener)
            listeningForDisplayChanges = false
        }
        root?.let { view ->
            if (visible) {
                // The view may already have been detached by Activity teardown. Cleanup must
                // remain idempotent so lifecycle destruction can safely call it every time.
                runCatching { wm.removeViewImmediate(view) }
            }
        }
        visible = false
        if (activeOverlay === this) activeOverlay = null
    }

    fun dispose() {
        hide()
        root = null
        textView = null
        lockBtn = null
    }

    private fun dp(v: Int): Int = (v * overlayContext.resources.displayMetrics.density).toInt()
}

private class OutlinedLyricsTextView(context: Context) : TextView(context) {
    private var outlineColor = Color.TRANSPARENT
    private var outlineRadiusPx = 0f

    fun setOutline(color: Int, widthDp: Float) {
        val density = resources.displayMetrics.density
        val radius = if (Color.alpha(color) == 0) 0f else widthDp.coerceIn(0f, 4f) * density
        // Reserve room for the outside half of the stroke and its antialiased edge.
        val inset = if (radius > 0f) ceil(radius).toInt() + 1 else 0
        val horizontal = maxOf((4 * density).toInt(), inset)
        val vertical = maxOf((3 * density).toInt(), inset)
        if (horizontal != paddingLeft || vertical != paddingTop) {
            setPadding(horizontal, vertical, horizontal, vertical)
        }
        if (color != outlineColor || radius != outlineRadiusPx) {
            outlineColor = color
            outlineRadiusPx = radius
            invalidate()
        }
    }

    override fun onDraw(canvas: Canvas) {
        val textLayout = layout
        if (outlineRadiusPx > 0f && textLayout != null) {
            val textPaint = textLayout.paint
            val savedColor = textPaint.color
            val savedStyle = textPaint.style
            val savedWidth = textPaint.strokeWidth
            val savedJoin = textPaint.strokeJoin
            val savedCanvas = canvas.save()
            try {
                // Same layout and origin as TextView, so wrapping and ellipses stay aligned.
                canvas.translate(compoundPaddingLeft.toFloat(), totalPaddingTop.toFloat())
                textPaint.color = outlineColor
                textPaint.style = Paint.Style.STROKE
                textPaint.strokeWidth = outlineRadiusPx * 2f
                textPaint.strokeJoin = Paint.Join.ROUND
                textLayout.draw(canvas)
            } finally {
                textPaint.color = savedColor
                textPaint.style = savedStyle
                textPaint.strokeWidth = savedWidth
                textPaint.strokeJoin = savedJoin
                canvas.restoreToCount(savedCanvas)
            }
        }
        super.onDraw(canvas)
    }
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

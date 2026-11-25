.pragma library
// Simplified Chinese translation of the applet: table[context][message] = text.
//
// This file is the translation source itself - the applet does not use gettext
// (no .po, no .pot, no .mo), so there is nothing to compile: edit an entry here
// and it takes effect on the next language resolution.
//
// The key must match the Translations.t(context, message) call in the source
// exactly, context included. A message with no entry falls back to its English
// original, which is why a partial table is valid.

var table = {
  "": {
    "Appearance": "外观",
    "Language": "语言",
  },
  "@action:button": {
    "Choose…": "选择…",
    "Reset to default icon": "恢复默认图标",
  },
  "@action:button Restores the default accent colour": {
    "Restore default (%1)": "恢复默认（%1）",
  },
  "@action:menu": {
    "Change account settings": "更改帐户设置",
    "Hibernate": "休眠",
    "Live tile": "动态磁贴",
    "Lock": "锁定",
    "Open file location": "打开文件位置",
    "Pin to Start": "固定到\"开始\"屏幕",
    "Resize": "调整大小",
    "Restart": "重启",
    "Run as administrator": "以管理员身份运行",
    "Shut down": "关机",
    "Sign out": "注销",
    "Tile colour": "磁贴颜色",
    "Unpin from Start": "从\"开始\"屏幕取消固定",
    "Unpin group from Start": "从\"开始\"菜单中取消固定组",
  },
  "@action:menu %1 is the slot number, %2 the colour name": {
    "Style %1 (%2)": "样式 %1（%2）",
  },
  "@action:menu Opens a submenu": {
    "More": "更多",
  },
  "@action:menu Size of a tile": {
    "Medium": "中",
    "Small": "小",
  },
  "@action:menu Tile colour": {
    "Automatic (from the app)": "自动（按应用）",
  },
  "@action:sidebar": {
    "All apps": "所有应用",
    "Pinned tiles": "已固定的磁贴",
    "Power": "电源",
  },
  "@info:label": {
    "An icon theme's artwork fills only part of its box, the rest is padding. This sets how much of the box counts as artwork, so the visible icon keeps its designed size. Lower it if icons look too small, raise it if they overflow. Default 85%.": "图标主题的图形只占图标框的一部分，其余是留白。这项配置图标可见部分的比例，补偿界面，让可见图标保持设计尺寸。图标视觉上偏小就调低，反之就调高。默认 85%。",
    "Coloured tiles need a matching palette: with \"early\" a tile takes the background of its style slot.": "彩色磁贴需要配对调色板；选择「早期」后磁贴会用其样式槽的底色。",
    "Only this applet is translated: the rest of the desktop keeps its own language. The choice applies immediately, no restart needed.": "只有本插件会切换语言，桌面其它部分保持各自的语言。选择立即生效，无需重启。",
    "While this is off, tiles are always drawn the reference way: the colour and live content records in the layout file are ignored and the tile context menu hides both entries.": "关闭时磁贴始终按参考样式绘制，布局文件里的颜色与动态内容记录不会生效，磁贴右键菜单也不显示这两项。",
  },
  "@info:liveTileCaption": {
    "Battery": "电池",
    "Weather": "天气",
  },
  "@info:placeholder": {
    "Name group": "命名组",
  },
  "@info:tooltip": {
    "Default (Windows grid)": "默认（Windows 网格）",
  },
  "@item:inlistbox": {
    "Automatic (slide + flip)": "自动（滑入 + 翻转）",
    "Automatic (white silhouette)": "自动（白色剪影）",
    "Default": "默认",
    "Early Windows (coloured tiles)": "早期 Windows（彩色磁贴）",
    "Flip only": "只用翻转",
    "Follow the session language": "跟随系统语言",
    "Keep the coloured icon": "保留彩色图标",
    "Letter placeholder": "字母占位",
    "Modern (translucent tiles)": "现代（半透明磁贴）",
    "Slide only": "只用滑入",
  },
  "@item:menu Live tile content": {
    "Battery": "电池",
    "Calendar": "月历",
    "Clock": "时钟",
    "Date": "日期",
    "None": "无",
    "Photo slideshow": "图片轮播",
    "Weather": "天气",
  },
  "@item:menu Tile colour": {
    "Black": "黑",
    "Blue": "蓝",
    "Cyan": "青",
    "Dark grey": "深灰",
    "Green": "绿",
    "Indigo": "靛蓝",
    "Light grey": "浅灰",
    "Medium grey": "中灰",
    "Orange": "橙",
    "Pink": "粉",
    "Purple": "紫",
    "Red": "红",
    "Semi-transparent": "半透明",
    "Transparent": "透明",
    "Yellow": "黄",
  },
  "@label": {
    "Icon": "图标",
    "Start menu layout": "开始菜单布局",
    "Tile style": "磁贴风格",
    "Weather source": "天气源",
  },
  "@label:check": {
    "Application colour": "应用主色",
    "Content update": "内容更新",
    "Live tile cycling": "动态磁贴轮播",
    "Live tiles": "动态磁贴",
  },
  "@label:color": {
    "Accent colour": "强调色",
  },
  "@label:listbox": {
    "Content swap animation": "切换动画",
    "Icon style": "图标",
    "Language": "语言",
    "Palette": "调色板",
  },
  "@label:slider": {
    "Icon fill ratio": "图标填充率",
  },
  "@option:check": {
    "Cycle between the icon and the live content (every 4–6 s, like Windows)": "在图标与动态内容之间循环（每 4–6 秒，Windows 动态磁贴行为）",
    "Enable the experimental options (tile colours, live tiles, icon style)": "启用实验性选项（磁贴颜色、动态磁贴、图标样式）",
    "Pulse slightly when the live content swaps (1 → 1.1 → 0.91, 600 ms)": "动态内容切换时轻微脉冲（1 → 1.1 → 0.91，600 ms）",
    "Show the live content a tile is marked with (clock, battery, date)": "显示磁贴上标记的动态内容（时钟 / 电池 / 日期）",
    "Use all 12 swap animations (otherwise only the 4 slides)": "使用全部 12 种切换动画（否则只有 4 种滑入）",
    "Use the application's own colour as the tile background when it is saturated and bright enough": "应用自身颜色满足饱和度/亮度时用作磁贴底色",
    "Windowed (non full screen) Start menu": "非全屏（窗口式）开始菜单",
  },
  "@title:dialog": {
    "Choose accent colour": "选择强调色",
  },
  "@title:group": {
    "Experimental options": "实验性内容",
  },
  "@title:list": {
    "Recently added": "最近添加",
  },
  "@title:sidebar": {
    "Start": "开始",
  },
}

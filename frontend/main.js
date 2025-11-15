const { app, BrowserWindow, Menu } = require('electron')
const path = require('path')
const fs = require('fs')

// 简单的 .env 加载器：优先加载 frontend/.env，其次仓库根目录的 .env
function loadEnv() {
  try {
    const scriptDir = __dirname
    const candidates = [
      path.join(scriptDir, '.env'),
      path.join(scriptDir, '..', '.env')
    ]
    for (const f of candidates) {
      if (fs.existsSync(f)) {
        try {
          const data = fs.readFileSync(f, { encoding: 'utf8' })
          data.split(/\r?\n/).forEach(line => {
            const s = line.trim()
            if (!s || s.startsWith('#')) return
            const idx = s.indexOf('=')
            if (idx === -1) return
            const key = s.substring(0, idx).trim()
            let val = s.substring(idx + 1).trim()
            if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
              val = val.substring(1, val.length - 1)
            }
            if (key) process.env[key] = val
          })
          console.log('Loaded env from', f)
          return
        } catch (e) {
          console.warn('Failed to read env file', f, e)
        }
      }
    }
  } catch (e) {
    console.warn('loadEnv error', e)
  }
}

loadEnv()

// 强校验：不在代码中硬编码任何凭据或 IP，缺少关键配置则退出
const required = ['TAILSCALE_IP', 'CUSTOM_USER', 'PASSWORD']
const missing = required.filter(k => !process.env[k])
if (missing.length > 0) {
  console.error('缺少必要的环境变量，拒绝启动：', missing.join(', '))
  console.error('请在 frontend/.env 或 根目录 .env 中设置这些变量（不要将敏感信息提交到公开仓库）。')
  // 退出并提示
  process.exit(1)
}

function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      webSecurity: false,
      allowRunningInsecureContent: true
    },
    titleBarStyle: 'hidden',
    frame: false,
    fullscreen: true,
    autoHideMenuBar: true
  })

  // 完全隐藏菜单
  Menu.setApplicationMenu(null)

  // 忽略证书错误
  mainWindow.webContents.session.setCertificateVerifyProc((request, callback) => {
    callback(0) // 信任所有证书
  })

  // 处理 HTTP 基本认证
  mainWindow.webContents.on('login', (event, authenticationResponseDetails, authInfo, callback) => {
    event.preventDefault()
    console.log('认证要求:', authenticationResponseDetails?.url ?? 'unknown url')
    // 从环境读取认证凭据（不在代码中保留回退值）
    const user = process.env.CUSTOM_USER
    const pass = process.env.PASSWORD
    callback(user, pass)
  })

  // 添加加载事件监听器用于调试
  mainWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription) => {
    console.error(`页面加载失败: ${errorCode} - ${errorDescription}`)
  })

  mainWindow.webContents.on('did-finish-load', () => {
    console.log('页面加载完成')
  })

  mainWindow.webContents.on('dom-ready', () => {
    console.log('DOM 已就绪')
  })

  // 加载你的网站
  const tailIp = process.env.TAILSCALE_IP
  const baseUrl = `https://${tailIp}:3001/`
  mainWindow.loadURL(baseUrl)
    .then(() => {
      console.log('页面加载成功')
    })
    .catch(error => {
      console.error('页面加载失败:', error)
      // 重试逻辑
      console.log('尝试重新加载...')
      setTimeout(() => {
        mainWindow.loadURL(baseUrl)
          .catch(err => console.error('重试加载失败:', err))
      }, 3000)
    })

  // 打开开发者工具以便调试
  mainWindow.webContents.openDevTools()
}

// 全局错误处理
process.on('unhandledRejection', (reason, promise) => {
  console.error('未处理的 Promise 拒绝:', reason)
})

process.on('uncaughtException', (error) => {
  console.error('未捕获的异常:', error)
})

// 应用启动
app.whenReady()
  .then(() => {
    try {
      createWindow()
    } catch (error) {
      console.error('创建窗口时出错:', error)
    }
  })
  .catch(error => {
    console.error('应用准备时出错:', error)
  })

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('activate', () => {
  try {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  } catch (error) {
    console.error('激活应用时出错:', error)
  }
})

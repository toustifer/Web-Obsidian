const { app, BrowserWindow, Menu } = require('electron')
const path = require('path')

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
    callback('stifer', 'docker88683139')
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
  mainWindow.loadURL('https://100.116.59.94:3001/')
    .then(() => {
      console.log('页面加载成功')
    })
    .catch(error => {
      console.error('页面加载失败:', error)
      // 重试逻辑
      console.log('尝试重新加载...')
      setTimeout(() => {
        mainWindow.loadURL('https://100.116.59.94:3001/')
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

# AutoSignIn

一个通过ADB控制Android设备进行自动签到的脚本工具，支持工作日检测和定时随机签到。

## 功能特点

- 📅 自动检测工作日（基于chinesecalendar库）
- ⏰ 可配置的签到时间段，随机选择签到时间点
- 📱 通过ADB控制Android设备执行签到操作
- 📝 详细的日志记录，便于问题排查
- 🛠️ 一键初始化依赖库和设置定时任务

## 项目结构

```
├── SignIn.sh          # 主脚本文件
├── CheckWorkDay.py    # 工作日检测脚本
├── device.conf        # 设备配置文件（自动生成）
├── crontab_self       # 定时任务配置文件（自动生成）
└── err.log            # 错误日志文件
```

## 环境要求

- Linux/macOS系统
- Python 3 及 pip
- ADB工具（已配置环境变量）
- Android设备（已开启USB调试）

## 安装步骤

1. 克隆或下载项目到本地

2. 确保已安装ADB工具并配置环境变量
   ```bash
   adb version  # 验证ADB是否已安装
   ```

3. 确保Android设备已开启USB调试模式，并通过USB连接到电脑
   ```bash
   adb devices  # 查看已连接的设备
   ```

4. 初始化Python依赖库
   ```bash
   cd /path/to/AutoSignIn
   chmod +x SignIn.sh
   ./SignIn.sh -i
   ```

5. 首次运行时会提示输入ADB设备序列号，完成设备配置

## 使用方法

### 命令行参数

```bash
usage:  ./SignIn.sh {-i|-u|-p|-s}
        -i  初始化Python依赖库
        -u  更新Python依赖库
        -p  设置自动签到定时任务
        -s  立即执行签到操作
```

### 设置自动签到

1. 配置设备签到时间段（默认已在device.conf中设置）
   ```
   MORNING_START=8:30   # 上午签到开始时间
   MORNING_END=9:00     # 上午签到结束时间  
   EVENING_START=18:30  # 下午签到开始时间
   EVENING_END=19:00    # 下午签到结束时间
   ```

2. 设置定时任务
   ```bash
   ./SignIn.sh -p
   ```
   系统会在工作日的上午和下午时间段内各随机生成3个签到时间点，并设置到crontab中

3. 查看当前的定时任务配置
   ```bash
   crontab -l
   ```

### 立即执行签到

如需手动立即执行签到操作：
```bash
./SignIn.sh -s
```

## 签到流程说明

脚本执行签到时会自动：
1. 唤醒设备
2. 解锁屏幕
3. 输入设备密码
4. 点击签到按钮
5. 清理最近任务
6. 关闭屏幕

> 注：签到按钮的位置是基于屏幕尺寸计算的，默认位于屏幕中间偏下位置（高度的66%处）

## 日志查看

签到操作的日志会记录在`err.log`文件中，可以通过以下命令查看：
```bash
cat err.log
```

## 注意事项

1. 请确保设备始终保持连接状态和足够电量
2. 如果签到应用更新或界面调整，可能需要重新调整签到按钮的位置
3. 定期检查日志文件，确保签到操作正常执行
4. 如需修改签到时间段，请编辑`device.conf`文件后重新设置定时任务
5. 如遇到chinesecalendar库相关错误，请使用`./SignIn.sh -u`更新依赖库

## 常见问题

**Q: 脚本无法找到设备怎么办？**
A: 请确认ADB已正确安装，设备已开启USB调试模式，并通过`adb devices`命令能看到设备列表

**Q: 签到失败如何排查？**
A: 查看`err.log`文件中的错误信息，确认设备连接状态和签到应用的界面是否有变化

**Q: 如何修改签到时间范围？**
A: 编辑`device.conf`文件中的`MORNING_START`、`MORNING_END`、`EVENING_START`和`EVENING_END`参数，然后执行`./SignIn.sh -p`重新设置定时任务
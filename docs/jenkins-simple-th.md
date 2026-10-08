# ตั้ง Jenkins ให้ใกล้ต้นฉบับ โดยแยก API / Frontend

ใช้สอง Pipeline jobs บน VPS เดียวกัน คำสั่งอยู่ใน Jenkinsfile โดยตรง ไม่ใช้ไฟล์ `.sh`

| Job | Script Path | Deploy อะไร |
| --- | --- | --- |
| `docker-jenkins-api` | `Jenkinsfile` | MySQL และ API |
| `docker-jenkins-frontend` | `Jenkinsfile.frontend` | Frontend |

## สิ่งที่เหมือนต้นฉบับ

- `agent any` และ `pollSCM('H/2 * * * *')`
- `environment` มีเพียง `BUILD_TAG` ตามไฟล์ต้นฉบับ ใช้แสดงหมายเลข build
- `Prepare Environment` อ่าน Jenkins credentials แล้ว `writeFile` สร้าง `.env` ภายใน workspace
- Stage หลัก: Checkout → Prepare Environment → Validate → Unit Test → Build → Deploy → Health Check → Verify Deployment
- ใช้ `echo`, `checkout`, `dir`, `withCredentials`, `writeFile` และ `sh` คำสั่งสั้น ๆ

`environment` ใน Jenkinsfile เป็นตัวแปรร่วมของ pipeline ส่วน `.env` เป็นค่าที่ Docker Compose อ่าน เป็นคนละส่วนกัน

## สิ่งที่ต้องตั้งใน Jenkins

### 1. Node 22

Manage Jenkins → Plugins → ติดตั้ง **NodeJS** จากนั้น Manage Jenkins → Tools → NodeJS installations → Add NodeJS:

- Name: **`Node22`**
- Install automatically: เปิด
- Version: **22.x**

ตรงกับ `tools { nodejs 'Node22' }` ในสองไฟล์

### 2. Credentials เหมือนต้นฉบับ

Manage Jenkins → Credentials → System → Global credentials → Add Credentials ชนิด **Secret text** สองรายการ:

| ID | Secret |
| --- | --- |
| `MYSQL_ROOT_PASSWORD` | รหัส root ของ MySQL เดิม |
| `MYSQL_PASSWORD` | รหัส `attractions_user` ของ MySQL เดิม |

ถ้ามีสอง ID นี้อยู่แล้ว ใช้ของเดิมได้ ไม่ต้องเพิ่มซ้ำ และไม่ต้องคัดลอก environment file กลางสำหรับ Jenkins อีกต่อไป รหัสต้องตรงกับฐานข้อมูลที่มีข้อมูลอยู่แล้ว การเขียน `.env` ไม่ได้เปลี่ยนรหัสใน MySQL เดิม

### 3. สร้างสอง Pipeline jobs

Disable job เก่า `docker-jenkins-pipeline` ก่อน แล้วสร้างสอง job ตามตารางบนสุด แต่ละ job ตั้ง:

1. Definition: **Pipeline script from SCM**
2. SCM: **Git**
3. Repository URL: `https://github.com/popototae/docker-jenkins.git`
4. เลือก Git credentials หาก repository ต้อง login
5. Branch: `*/main`
6. Script Path: ตามตาราง

หลังรันครั้งแรก trigger จาก Jenkinsfile จะให้ Jenkins ตรวจการเปลี่ยนแปลงประมาณทุก 2 นาที Polling นี้ตรวจทั้ง repository จึงอาจเริ่มทั้งสอง job เมื่อ push แม้แก้แอปเดียว หากต้องการกดเอง ให้เอา `triggers` ออกจากไฟล์ทั้งสอง

## ตรวจบน VPS ก่อนเริ่ม

```sh
sudo -u jenkins docker version
sudo -u jenkins docker compose version
sudo -u jenkins git --version
sudo -u jenkins curl --version
```

Agent ต้องใช้ Docker ได้จริง หากยัง permission denied และ user ยังไม่ได้อยู่ในกลุ่ม Docker:

```sh
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

ให้ restart ตอนที่ไม่มี build ทำงาน หากมีหลาย agent ต้องกำหนด label ใน `agent` ของทั้งสอง pipeline ให้ชี้ VPS เดียวกัน

### ใช้ Compose project และ volume เดิม

`docker-compose.yml` กำหนด `name: docker-jenkins-pipeline` เพื่อให้สอง workspace ใช้ stack เดียวกัน โดยไม่ต้องเพิ่ม `COMPOSE_PROJECT_NAME` ใน Jenkinsfile ตรวจของเดิม:

```sh
docker inspect attractions_mysql --format '{{ index .Config.Labels "com.docker.compose.project" }}'
docker inspect attractions_mysql --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Name}}{{end}}{{end}}'
```

Project ควรเป็น `docker-jenkins-pipeline` ถ้าใช้ชื่ออื่นอยู่ให้เปลี่ยน `name:` ใน Compose ให้ตรงก่อนรัน และอย่าตั้ง `COMPOSE_PROJECT_NAME` บน agent เป็นชื่ออื่น เพราะจะ override ค่าในไฟล์

## เริ่มรัน

1. กด Build Now ของ API ก่อน รอจนผ่าน
2. กด Build Now ของ frontend
3. เปิด `http://<VPS-IP>:3000`

API job เปิด MySQL และ deploy API ส่วน frontend job ใช้ `--no-deps` เพื่อไม่ deploy API/MySQL ตามไปด้วย แต่ frontend health check ยังต้องเรียก API ได้

## Flow แต่ละ stage

| Stage | ทำอะไร |
| --- | --- |
| Checkout | `deleteDir()` ล้างเฉพาะ workspace ของ job แล้ว `checkout scm` ดึงโค้ด |
| Prepare Environment | `withCredentials` อ่านรหัส แล้ว `writeFile` สร้าง `.env` พร้อมจำกัดสิทธิ์ไฟล์ |
| Validate | ตรวจ Compose หลังสร้าง `.env` แล้ว เพื่อให้มีค่าครบ |
| Unit Test | `dir` เข้าแอป → `npm ci --include=dev` → `npm test` |
| Build | สร้าง image เฉพาะแอปด้วย `--no-cache` เหมือนต้นฉบับ |
| Deploy | Compose up เฉพาะแอปและรอ healthy สูงสุด 180 วินาที |
| Health Check | curl API หรือ frontend ด้วย timeout |
| Verify Deployment | แสดงสถานะ containers และ logs |
| post | แสดงผลสำเร็จหรือ logs เมื่อผิดพลาด |

ยังใช้ `sh 'npm test'` เพราะเป็น Jenkins step สำหรับสั่งโปรแกรมบน Linux ไม่ใช่เรียก shell script ที่ต้องตามไปอ่าน ไม่มี loop, trap หรือ shell function ใน pipeline

พอร์ตมาตรฐานคือ API 3001 และ frontend 3000 ถ้าแก้พอร์ตใน `.env` ที่ pipeline สร้าง ให้แก้ Health Check ให้ตรงด้วย

ไม่คืนพารามิเตอร์ `CLEAN_VOLUMES` หรือคำสั่ง `down -v` เพราะการแยกแอปไม่ควรลบฐานข้อมูลหรือปิดทั้ง stack ไม่มี automatic rollback และไม่สั่ง global Docker prune

## GitHub Actions

GitHub ยังเป็น manual workflow และ build/deploy ทั้งสองบริการ พร้อมใช้ไฟล์กลาง `/var/lib/jenkins/docker-jenkins.env` ตาม workflow ปัจจุบัน การปรับรอบนี้เอาค่าไฟล์กลางออกเฉพาะ Jenkins หากยังใช้ GitHub ให้เก็บไฟล์กลางไว้ และตั้งค่าฐานข้อมูลให้ตรงกับ Jenkins credentials

อย่ารัน GitHub deploy พร้อม Jenkins หากจะทดสอบ GitHub ให้ Disable สอง Jenkins jobs ชั่วคราวแล้วค่อยรัน workflow

# โปรเจกต์นี้ย้ายเป็นสอง repository แล้ว

| แอป | Repository | โฟลเดอร์ในเครื่อง |
| --- | --- | --- |
| API + MySQL | https://github.com/popototae/docker-jenkins-api | `D:\Work\docker-jenkins-api` |
| Frontend | https://github.com/popototae/docker-jenkins-frontend | `D:\Work\docker-jenkins-frontend` |

ทั้งสอง repo เป็น Public มี Jenkinsfile และ Docker Compose ของตัวเอง ไม่มี shared shell scripts

แก้โค้ดและ push ใน repo ของแอปนั้นโดยตรง โปรเจกต์เดิมนี้เก็บเฉพาะข้อมูลย้ายระบบ ไม่ใช้ build หรือ deploy อีกแล้ว โค้ดเดิมยังดูได้จาก Git history

คู่มือย้ายระบบและการตั้ง Jenkins: [MIGRATION.md](https://github.com/popototae/docker-jenkins-api/blob/main/MIGRATION.md)

Jenkins jobs:

- [docker-jenkins-api](http://138.2.70.183:8080/job/docker-jenkins-api/)
- [docker-jenkins-frontend](http://138.2.70.183:8080/job/docker-jenkins-frontend/)

API ใช้ project `docker-jenkins-pipeline` และ volume MySQL เดิม ส่วน frontend ใช้ project `docker-jenkins-frontend` เชื่อม API ผ่าน Docker network

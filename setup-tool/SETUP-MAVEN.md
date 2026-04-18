# Cài Apache Maven (manual)

## 1) Yêu cầu

- Đã cài JDK (khuyến nghị Java 17+ hoặc 21)
- Có quyền `sudo`

## 2) Tải và giải nén Maven

```bash
cd /tmp
curl -LO https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz
tar -xvf apache-maven-3.9.9-bin.tar.gz
sudo mv apache-maven-3.9.9 /opt/maven
```

## 3) Khai báo biến môi trường

```bash
sudo tee /etc/profile.d/maven.sh > /dev/null <<'SH'
export M2_HOME=/opt/maven
export PATH=${M2_HOME}/bin:${PATH}
SH
sudo chmod +x /etc/profile.d/maven.sh
source /etc/profile.d/maven.sh
```

## 4) Kiểm tra

```bash
mvn -version
```

## 5) Lệnh Maven cơ bản

```bash
mvn clean
mvn test
mvn package
```

## Tài liệu chính thức

- https://maven.apache.org/guides/getting-started/

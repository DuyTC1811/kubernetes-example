# Cài Gradle (manual)

## 1) Cài Java

```bash
sudo dnf install -y java-21-openjdk java-21-openjdk-devel
```

## 2) Tải và cài Gradle

```bash
cd /tmp
curl -LO https://services.gradle.org/distributions/gradle-8.14.2-bin.zip
sudo mkdir -p /opt/gradle
sudo unzip gradle-8.14.2-bin.zip -d /opt/gradle
```

## 3) Khai báo biến môi trường

```bash
sudo tee /etc/profile.d/gradle.sh > /dev/null <<'SH'
export GRADLE_HOME=/opt/gradle/gradle-8.14.2
export PATH=${GRADLE_HOME}/bin:${PATH}
SH
sudo chmod +x /etc/profile.d/gradle.sh
source /etc/profile.d/gradle.sh
```

## 4) Kiểm tra

```bash
gradle --version
```

## 5) Lệnh Gradle thường dùng

```bash
gradle clean
gradle test
gradle build
```

## Tài liệu chính thức

- https://docs.gradle.org/

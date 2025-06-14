# Setting Up Gradle

This guide will help you set up Gradle for your project.

## 1. Install manually
Visit [gradle.org/releases](https://gradle.org/releases/) and follow the installation instructions.
```sh
sudo dnf install java-21-openjdk -y
wget https://services.gradle.org/distributions/gradle-8.14.2-bin.zip
sudo unzip -d /opt/gradle gradle-8.14.2-bin.zip

sudo nano /etc/profile.d/gradle.sh # create file
# add file
export GRADLE_HOME=/opt/gradle/gradle-8.14.2 
export PATH=${GRADLE_HOME}/bin:${PATH}

sudo chmod +x /etc/profile.d/gradle.sh
source /etc/profile.d/gradle.sh
```
## 2. Verify Installation

Check the Gradle version:
```sh
gradle --version
```

## 3. Basic Gradle Commands

- Build the project:  
  ```sh
  gradle build
  ```
- Run tests:  
  ```sh
  gradle test
  ```
- Clean build files:  
  ```sh
  gradle clean
  ```

## 4. Useful Resources

- [Gradle Documentation](https://docs.gradle.org/)
- [Gradle Build Script Basics](https://docs.gradle.org/current/userguide/tutorial_java_projects.html)

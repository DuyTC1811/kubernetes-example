# Setting Up Maven

This guide will help you set up Maven for your project.

## Prerequisites

- Java JDK (version 8 or higher)
- Internet connection

## Installation Steps

### 1. Download Maven

Download the latest version of Maven from the [official website](https://maven.apache.org/download.cgi).

### 2. Extract the Archive

```sh
tar -xvf apache-maven-*.tar.gz
```

### 3. Move Maven to `/opt` (optional)

```sh
sudo mv apache-maven-* /opt/maven
```

### 4. Set Environment Variables

Add the following lines to your `~/.bashrc` or `~/.zshrc`:

```sh
sudo nano /etc/profile.d/maven.sh # created file

# add value in file maven.sh
export M2_HOME=/opt/maven
export PATH=${M2_HOME}/bin:${PATH}

sudo chmod +x /etc/profile.d/maven.sh
source /etc/profile.d/maven.sh
```

### 5. Verify Installation

```sh
mvn -version
```

You should see Maven version information.

## Next Steps

- [Maven Getting Started Guide](https://maven.apache.org/guides/getting-started/)
- Create a `pom.xml` for your project

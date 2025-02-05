# Dockerized Nextcloud, Docuseal, Stirling-PDF with Nginx Proxy Manager & Let's Encrypt

This repository contains a **Docker Compose setup** for deploying **Nextcloud, Docuseal, and Stirling-PDF** with **NGINX Proxy Manager (NPM)** for secure reverse proxying and **Let's Encrypt SSL auto-renewal**.

---

## 🚀 Setup Instructions

### 1️⃣ Prerequisites
Ensure you have:
- **Docker & Docker Compose installed**
- A **public domain name** (e.g., `example.com`)
- A **static or dynamically managed public IP address**
- Access to your **router/firewall for port forwarding**

---

## 🏗️ Deployment Steps

### 2️⃣ Clone Repository
```bash
git clone https://github.com/your-repo/example-docker.git
cd example-docker
```

### 3️⃣ Configure Firewall & Port Forwarding
Set up port forwarding on your router to direct external traffic to your Docker host (192.168.1.xxx):

| External Port | Internal IP       | Internal Port | Purpose               |
|--------------|------------------|--------------|-----------------------|
| 80          | 192.168.1.xxx     | 80           | HTTP (for Let's Encrypt) |
| 443         | 192.168.1.xxx     | 443          | HTTPS (secure web traffic) |

### 4️⃣ DNS Configuration (GoDaddy, Namecheap, Cloudflare, etc.)
Log into your DNS provider (e.g., GoDaddy) and add the following A records pointing to your public IP:

| Subdomain | Record Type | Target (Public IP) |
|-----------|------------|--------------------|
| nextcloud.example.com | A | [Your Public IP] |
| docuseal.example.com | A | [Your Public IP] |
| pdf.example.com | A | [Your Public IP] |

💡 Tip: If your IP changes frequently, consider using Dynamic DNS (DDNS).

### 5️⃣ Deploy Docker Containers
Run the following command inside the project directory:

```bash
docker-compose up -d && docker-compose logs -f
```
This will download and start all necessary containers in the background.

### 6️⃣ Nginx Proxy Manager Setup
Open **NGINX Proxy Manager** in your browser:

```
http://192.168.1.xxx:81
```
Login using default credentials:
- **Email:** `admin@example.com`
- **Password:** `changeme`

Change your **admin email and password** immediately.

### 7️⃣ Configure Proxy Hosts in Nginx Proxy Manager
#### **Step 1: Add a New Proxy Host**
- Navigate to **Hosts → Proxy Hosts → Add Proxy Host**
- Fill in the details:
  - **Domain Name:** `nextcloud.example.com`
  - **Forward Hostname/IP:** `nextcloud`
  - **Forward Port:** `80`
  - Enable:
    - ✅ **Block Common Exploits**
    - ✅ **Websockets Support** (if required)

Repeat this process for:
- `docuseal.example.com → docuseal:3000`
- `pdf.example.com → stirling-pdf:8080`

#### **Step 2: Enable Let's Encrypt SSL**
- Open **Proxy Host Settings → SSL Tab**
- Select **Request a new SSL Certificate**
- Check:
  - ✅ **Force SSL**
  - ✅ **HTTP/2 Support**
  - ✅ **HSTS Enabled** (optional)
- Click **Save**

💡 **Let’s Encrypt will automatically renew SSL certificates every 90 days!**

---

### 🔐 Restricting Access to Local Network for Docuseal and Stirling-PDF
#### **Step 1: Find the Docker Network Subnet**
Run the following command to check the Docker network assigned to your containers:
```bash
docker network inspect bridge
```
or, if using a custom network:
```bash
docker network ls
```
Find the subnet listed under `"Subnet": "XXX.XXX.X.X/XX"`.

#### **Step 2: Set Up an Access List in Nginx Proxy Manager**
1. Go to **Nginx Proxy Manager UI** (`http://192.168.1.xxx:81`).
2. Navigate to **Access Lists** → Click **Add Access List**.
3. Set the following:
   - **Name:** `Local Network Only`
   - **Satisfy Any:** ✅ **Enable**
   - **Public Access:** ❌ **Disable**
   - **Add an IP Allowlist Rule**:
     - **Allow:** `192.168.1.0/24` *(LAN access)*
     - **Allow:** `[Docker Network Subnet]` *(from Step 1)*
   - Click **Save**.

4. **Apply the Access List to Proxy Hosts:**
   - Go to `Hosts → Proxy Hosts`.
   - Click `Edit` for **docuseal.callitweb.com** and **pdf.callitweb.com**.
   - Under **Access List**, select **Local Network Only**.
   - Click **Save & Restart**.

✅ **Now, only devices in your local network and Docker environment can access these services.**
---

## 📜 Docker Compose Configuration

./docker-compose.yml

---

## 🔄 Automatic Backups with MinIO & Duplicati

To ensure reliable backups, this setup includes **MinIO** (S3-compatible storage) and **Duplicati** for automated backups.  

### 📦 How Backups Work:
- **MinIO** acts as a private, self-hosted S3 storage backend.
- **Duplicati** is configured to automatically back up Nextcloud data.
- Backups are stored in the MinIO bucket: `duplicati-backups`.
- The backup configuration is **automatically imported** when the Duplicati container starts.

---

### **1️⃣ Viewing Backup Status**
You can access the **Duplicati Web UI** at:

http://192.168.1.xxx:8200

Login with the credentials:
- **Username:** `admin`
- **Password:** `mynewpassword`

From here, you can:
- View scheduled backups.
- Run manual backups.
- Restore files if needed.

---

### **2️⃣ How to Add Additional Backups**
By default, **only Nextcloud is backed up**. You can add more services (e.g., MariaDB, PostgreSQL, Stirling-PDF) in two ways:

#### **📌 Option 1: Modify the Import Script**
Edit the file **`duplicati-config/import-script.sh`**, adding new source volumes.  
For example, to back up **MariaDB**, modify the script like this:

```bash
sqlite3 "$DB_PATH" <<EOF
BEGIN TRANSACTION;
INSERT INTO Backup (Name, Description, Tags, TargetURL, DBPath) VALUES 
(
    "MariaDB Backup",
    "Backup of Nextcloud database",
    "Nextcloud, Database",
    "s3://admin-duplicati-backups/mariadb-backup?s3-server-name=minio%3A9000&auth-username=admin&auth-password=strongpassword&endpoint=http%3A%2F%2Fminio%3A9000",
    "/config/MariaDBBackup.sqlite"
);
COMMIT;
EOF
🚀 After modifying the script, restart Duplicati to apply changes:

```bash
docker-compose restart duplicati
```
📌 Option 2: Use Duplicati UI
Open Duplicati Web UI (http://192.168.1.xxx:8200).
Click "Add Backup" → "Configure a New Backup".
Select Source Data (e.g., /source/db_data for MariaDB).
Choose MinIO (S3 Compatible Storage) as the destination.
Enter MinIO details:
Server: http://minio:9000
Bucket: duplicati-backups
Folder Path: mariadb-backup
Access Key: admin
Secret Key: strongpassword
Save and schedule the backup.
### ** Restoring Data**
If you need to restore files:

Open Duplicati Web UI (http://192.168.1.xxx:8200).
Click "Restore" and select the backup source.
Choose files to restore and select a destination.
Click Restore to recover your data.
### **4️⃣ Where Backups Are Stored**
All backups are stored in MinIO, accessible via:

MinIO Web UI: http://192.168.1.xxx:9001
Bucket Name: duplicati-backups
To manually browse backups, run:

```bash
docker exec -it minio_mc sh
mc alias set local http://minio:9000 admin strongpassword
mc ls local/duplicati-backups
```
### **✅ Now, your system has fully automated backups with MinIO & Duplicati! 🚀**

---

### **📜 What This Update Does**
✔ **Documents the new backup solution in MinIO + Duplicati.**  
✔ **Explains how backups are configured and how users can modify them.**  
✔ **Includes clear instructions for adding new containers to the backup system.**  
✔ **Shows how to restore data if needed.**  

---

💡 Future Improvements
 Add fail2ban for additional security
 Set up Cloudflare proxying for better DDoS protection
👨‍💻 Author
Maintained by Adam Freed

---
This ensures that your **Docker Compose setup is included in the README** for easy deployment and configuration. 🚀
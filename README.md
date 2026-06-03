# configure_guacamole

## 📂 Purpose
Automates configuration for configure_guacamole.

## ⚙️ Tasks
- Stop all containers
- Remove all containers
- Remove all Docker images
- Remove all Docker volumes
- Remove all Docker networks (except default ones)
- Remove /var/lib/containers directory
- Ensure compose directory exists
- Ensure Guacamole config directory exists
- Ensure images directory exists
- Ensure nginx conf.d directory exists
- Ensure nginx certs directory exists
- Ensure DB dump directory exists
- copy guac_export_ptek.sql
- Copy docker-compose.yml
- Create run.sh
- Create stop.sh
- Create db-export-default.sh
- Create db-export-ptek.sh
- Create db-import-default.sh
- Create db-import-ptek.sh
- Ensure image destination directory exists
- Copy ALL container images
- Fail if no images were copied
- Find container images on target
- Fail if no images found on target
- Load ALL container images
- Ensure firewalld is installed
- Ensure firewalld is running
- Allow HTTP/HTTPS in public zone
- Add Guacamole ports to internal zone
- Generate DH params file
- Copy nginx.conf
- Copy mime.types
- Copy server certs
- Copy guacamole.conf vhost
- Stop existing stack
- Start only Postgres container
- Wait for Postgres to be ready
- Ensure Guacamole database exists
- Check for copied SQL dump file
- Abort if copied SQL dump file is missing
- Import Guacamole database dump
- Extract schema signature from SQL dump
- Display schema signature
- Deploy Docker CIS remediation script
- Run Docker CIS remediation
- Start full Guacamole stack

## 📌 Requirements
- Ansible control node
- Target host connectivity

## 📖 Notes
- Generated automatically from tasks.

## 🚀 Usage
```yaml
- hosts: configure_guacamole
  roles:
    - configure_guacamole
```

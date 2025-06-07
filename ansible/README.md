# Ansible Infrastructure as Code

This directory contains Ansible playbooks and roles for automating the deployment of the Flask application.

## Directory Structure

```
ansible/
├── inventory/
│   └── hosts           # Inventory file defining hosts
├── roles/
│   ├── common/         # Common system setup
│   ├── docker/         # Docker installation and configuration
│   └── app/           # Application deployment
└── site.yml           # Main playbook
```

## Prerequisites

- Ansible 2.9 or higher
- Python 3.x
- Target servers running Ubuntu/Debian

## Usage

1. Update the inventory file (`inventory/hosts`) with your server details
2. Run the playbook:

```bash
# For staging environment
ansible-playbook -i inventory/hosts site.yml --limit staging

# For production environment
ansible-playbook -i inventory/hosts site.yml --limit production
```

## Roles

### Common Role
- Updates system packages
- Installs basic requirements
- Creates application directory

### Docker Role
- Installs Docker and dependencies
- Configures Docker service
- Installs Docker Python module

### App Role
- Copies application files
- Builds Docker image
- Creates Docker network
- Runs application container

## Variables

The playbook uses the following variables:
- `ansible_python_interpreter`: Python interpreter path
- `ansible_distribution_release`: Ubuntu release name

## Security Notes

- The playbook uses `become: yes` for tasks requiring root privileges
- Make sure to secure your inventory file and any sensitive variables
- Consider using Ansible Vault for sensitive data 
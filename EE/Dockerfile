# Usa la imagen oficial de Ansible como base
FROM quay.io/ansible/ansible-runner:latest

# Instala Python y dependencias necesarias
RUN pip install --no-cache-dir \
    mysql-connector-python \
    ansible==2.9

# Instalar la colección `community.mysql` para que esté disponible en el entorno
RUN ansible-galaxy collection install community.mysql

# Establece el directorio de trabajo
WORKDIR /ansible

# Copia tu playbook y cualquier archivo de configuración necesario al contenedor
COPY . /ansible

# Configura el contenedor para ejecutar un playbook de ejemplo por defecto
ENTRYPOINT ["ansible-playbook"]
CMD ["playbook.yml"]


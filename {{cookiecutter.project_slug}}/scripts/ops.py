import subprocess
import argparse
import sys
import os
import random
import string

# --- Configuración de Colores para la Terminal ---
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'

def run_command(command, cwd=None, capture_output=False):
    """
    Ejecuta un comando de shell.
    Si capture_output=True, devuelve el texto de la salida.
    Si capture_output=False, imprime en pantalla en tiempo real.
    """
    if not capture_output:
        print(f"{Colors.OKBLUE}Ejecutando: {command}{Colors.ENDC}")
    
    try:
        result = subprocess.run(
            command, 
            shell=True, 
            check=True, 
            cwd=cwd, 
            stdout=subprocess.PIPE if capture_output else None,
            text=True if capture_output else None
        )
        if capture_output:
            return result.stdout.strip()
        print(f"{Colors.OKGREEN}✔ Éxito{Colors.ENDC}")
    except subprocess.CalledProcessError:
        if not capture_output:
            print(f"{Colors.FAIL}✘ Error ejecutando el comando anterior.{Colors.ENDC}")
        sys.exit(1)

def bootstrap_backend(location, project_slug):
    """
    1. Crea un Resource Group especial para Terraform (rg-tfstate-...).
    2. Crea un Storage Account único y un contenedor para guardar el estado.
    3. Devuelve las credenciales para configurar Terraform automáticamente.
    """
    print(f"{Colors.HEADER}--- 1. Bootstrapping (Preparando Backend de Terraform) ---{Colors.ENDC}")
    
    # Definimos nombres estándar
    rg_name = f"rg-tfstate-{project_slug}"
    # El nombre del storage debe ser único y sin guiones. Usamos el slug limpio + 4 chars random.
    clean_slug = project_slug.replace("-", "").replace("_", "")[:15]
    sa_name = f"tfstate{clean_slug}" 
    container_name = "tfstate"

    # 1. Crear Resource Group
    print(f"-> Verificando Resource Group: {rg_name}")
    run_command(f"az group create --name {rg_name} --location {location}", capture_output=True)

    # 2. Crear Storage Account (si falla porque existe, no pasa nada, es idempotente)
    print(f"-> Verificando Storage Account: {sa_name}")
    try:
        run_command(
            f"az storage account create --resource-group {rg_name} --name {sa_name} --sku Standard_LRS --encryption-services blob",
            capture_output=True
        )
    except SystemExit:
        print(f"{Colors.WARNING}Nota: El storage ya existe o hubo un error menor.{Colors.ENDC}")

    # 3. Obtener la Key de acceso (necesaria para Terraform)
    account_key = run_command(
        f"az storage account keys list --resource-group {rg_name} --account-name {sa_name} --query '[0].value' -o tsv",
        capture_output=True
    )

    # 4. Crear el contenedor (carpeta) dentro del storage
    run_command(
        f"az storage container create --name {container_name} --account-name {sa_name} --account-key {account_key}",
        capture_output=True
    )

    return {
        "resource_group_name": rg_name,
        "storage_account_name": sa_name,
        "container_name": container_name,
        "key": "terraform.tfstate",
        "access_key": account_key
    }

def infra_provision(location):
    """
    Orquesta la creación de infraestructura:
    1. Llama a bootstrap para asegurar el storage.
    2. Inicializa Terraform inyectando la config del backend.
    3. Aplica los cambios.
    """
    # Detectamos el nombre del proyecto basado en la carpeta actual
    project_slug = os.path.basename(os.getcwd())
    
    # Paso 1: Resolver el Huevo y la Gallina
    backend_config = bootstrap_backend(location, project_slug)
    
    print(f"\n{Colors.HEADER}--- 2. Ejecutando Terraform ---{Colors.ENDC}")
    infra_dir = os.path.join(os.getcwd(), 'infra')
    
    # Paso 2: Terraform Init con Inyección de Configuración (Backend Parcial)
    # Esto llena el bloque 'backend "azurerm" {}' que dejamos vacío en versions.tf
    init_cmd = (
        f"terraform init "
        f"-backend-config=\"resource_group_name={backend_config['resource_group_name']}\" "
        f"-backend-config=\"storage_account_name={backend_config['storage_account_name']}\" "
        f"-backend-config=\"container_name={backend_config['container_name']}\" "
        f"-backend-config=\"key={backend_config['key']}\""
    )
    
    # Nota: Para la access key, usamos la variable de entorno para mayor seguridad en logs
    os.environ["ARM_ACCESS_KEY"] = backend_config['access_key']

    run_command(init_cmd, cwd=infra_dir)
    run_command("terraform validate", cwd=infra_dir)
    run_command("terraform plan -out=tfplan", cwd=infra_dir)
    
    confirm = input(f"{Colors.WARNING}\n¿Deseas aplicar estos cambios en Azure? (s/n): {Colors.ENDC}")
    if confirm.lower() == 's':
        run_command("terraform apply tfplan", cwd=infra_dir)
    else:
        print("Operación cancelada.")

def docker_build_push(acr_name, tag):
    """Build, Scan y Push de la imagen Docker."""
    print(f"{Colors.HEADER}--- Pipeline de Docker ---{Colors.ENDC}")
    
    # Asumimos nombre de imagen igual al directorio
    image_name = os.path.basename(os.getcwd())
    full_image = f"{acr_name}.azurecr.io/{image_name}:{tag}"
    
    # 1. Login
    run_command(f"az acr login --name {acr_name}")
    
    # 2. Build
    run_command(f"docker build -t {full_image} ./src")
    
    # 3. Scan (Trivy) - Opcional, solo si está instalado
    print(f"{Colors.OKBLUE}Intentando escanear con Trivy...{Colors.ENDC}")
    try:
        run_command(f"trivy image --severity HIGH,CRITICAL {full_image}")
    except:
        print(f"{Colors.WARNING}Trivy no encontrado o falló. Continuando...{Colors.ENDC}")

    # 4. Push
    run_command(f"docker push {full_image}")

def main():
    parser = argparse.ArgumentParser(description="Herramienta de Automatización DevOps")
    subparsers = parser.add_subparsers(dest="action", required=True, help="Acción a realizar")

    # --- Subcomando: infra ---
    infra_parser = subparsers.add_parser("infra", help="Provisiona infraestructura (Terraform)")
    infra_parser.add_argument("--location", default="eastus2", help="Región de Azure (default: eastus2)")

    # --- Subcomando: deploy ---
    deploy_parser = subparsers.add_parser("deploy", help="Construye y sube Docker Image")
    deploy_parser.add_argument("--acr", required=True, help="Nombre del Azure Container Registry")
    deploy_parser.add_argument("--tag", default="latest", help="Tag de la imagen")

    args = parser.parse_args()

    if args.action == "infra":
        infra_provision(args.location)
    elif args.action == "deploy":
        docker_build_push(args.acr, args.tag)

if __name__ == "__main__":
    main()
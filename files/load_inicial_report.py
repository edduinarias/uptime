#!/usr/bin/env python3
import os
import base64
import json
from datetime import datetime
import glob
import argparse

def generate_html_report(cambio, titulo_cambio, tower_user_name, output_file, dest_infoprepos):
    files = glob.glob(f'{dest_infoprepos}/{cambio}/reporte_inicial/filesystems_*')
    play_hosts = sorted(list({os.path.basename(f).split('_', 1)[1] for f in files}))

    hostvars = {}
    for host in play_hosts:
        hostvars[host] = get_host_header_data(host, cambio, dest_infoprepos)

    sidebar_items = "\n".join(
        f"<div class='server-item' onclick=\"showServer('{host}')\">{host}<span style='float: right; color: #0366d6;'>✓</span></div>"
        for host in play_hosts
    )

    content_sections = "\n".join(
        generate_host_section(host, cambio, hostvars[host], dest_infoprepos)
        for host in play_hosts
    )

    html = f"""<!DOCTYPE html>
<html>
<head>
    <title>Reporte Inicial de Configuraciones</title>
    <meta charset="UTF-8">
    <style>
        :root {{
            --primary-color: #0366d6;
            --sidebar-width: 250px;
            --border-color: #e1e4e8;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            margin: 0;
            padding: 0;
            display: flex;
            color: #24292e;
        }}
        #sidebar {{
            width: var(--sidebar-width);
            border-right: 1px solid var(--border-color);
            height: 100vh;
            overflow-y: auto;
        }}
        .server-item {{
            padding: 10px;
            border-bottom: 1px solid var(--border-color);
            cursor: pointer;
        }}
        .server-item.active {{
            background-color: #f0f0f0;
            font-weight: bold;
        }}
        #content {{
            flex-grow: 1;
            padding: 20px;
            overflow-y: auto;
        }}
        .config-container {{
            display: none;
        }}
        .config-container.active {{
            display: block;
        }}
        .file-tabs {{
            margin-top: 10px;
        }}
        .file-tab {{
            display: inline-block;
            padding: 5px 10px;
            border: 1px solid var(--border-color);
            margin-right: 5px;
            cursor: pointer;
            border-radius: 4px 4px 0 0;
            background-color: #eaeaea;
        }}
        .file-tab.active {{
            background-color: #fff;
            font-weight: bold;
        }}
        .file-content {{
            display: none;
            border: 1px solid var(--border-color);
            border-top: none;
            padding: 10px;
            background-color: #fff;
        }}
        .file-content.active {{
            display: block;
        }}
        .config-line {{
            font-family: monospace;
            white-space: pre;
        }}
        .line-number {{
            color: #888;
            margin-right: 10px;
        }}
        .config-header {{
            font-weight: bold;
            font-size: 16px;
            margin-bottom: 10px;
        }}
        .error-message {{
            color: red;
        }}
        .timestamp {{
            margin-bottom: 10px;
            font-size: 14px;
        }}
    </style>
</head>
<body>
    <div id="sidebar">
        <h3 style="padding: 15px; margin: 0; border-bottom: 1px solid var(--border-color);">Servidores</h3>
        {sidebar_items}
    </div>

    <div id="content">
        <h1>Reporte Inicial de Configuraciones</h1>
        <div class="timestamp">Generado el: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</div>
        <div class="timestamp">Generado por: {tower_user_name}</div>
        <div class="timestamp">Título del Cambio: {titulo_cambio}</div>
        {content_sections}
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function() {{
            const firstServer = document.querySelector('.server-item');
            if (firstServer) {{
                const hostId = firstServer.textContent.trim().replace(/[✓]/g, '').trim();
                showServer(hostId);
            }}
        }});

        function showServer(host) {{
            document.querySelectorAll('.server-item').forEach(item => {{
                item.classList.remove('active');
                if (item.textContent.includes(host)) {{
                    item.classList.add('active');
                }}
            }});

            document.querySelectorAll('.config-container').forEach(container => {{
                container.classList.remove('active');
            }});
            document.getElementById(host).classList.add('active');
        }}

        function showFile(host, file) {{
            const tabs = document.querySelectorAll(`#${{host}} .file-tab`);
            tabs.forEach(tab => tab.classList.remove('active'));

            const contents = document.querySelectorAll(`#${{host}} .file-content`);
            contents.forEach(content => content.classList.remove('active'));

            document.querySelector(`#${{host}} .file-tab[onclick*="${{file}}"]`).classList.add('active');
            document.getElementById(`${{host}}_${{file}}`).classList.add('active');
        }}
    </script>
</body>
</html>"""

    with open(output_file, 'w') as f:
        f.write(html)

    print(f"Reporte generado exitosamente en {output_file}")

def get_host_header_data(host, cambio, dest_infoprepos):
    header_file = f'{dest_infoprepos}/{cambio}/reporte_inicial/header_{host}'
    data = {}  # Diccionario vacío (sin valores por defecto)

    if not os.path.exists(header_file):
        return data

    try:
        with open(header_file, 'r') as f:
            for line in f:
                line = line.strip()
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()  # Opcional: .upper() si quieres claves en mayúsculas
                    value = value.strip()
                    data[key] = value  # Guarda el valor tal cual

    except Exception as e:
        print(f"Error al procesar {header_file}: {str(e)}")

    return data

def generate_host_section(host, cambio, host_data, dest_infoprepos):
    file_types = [
        'filesystems', 'osversion', 'discos_fisicos', 'volumenes_logicos',
        'networks', 'rutas', 'recursos', 'puertos', 'nameservers', 'hba', 'multipath','asm'
    ]

     # Solo agregar ldoms si el host es físico y el archivo existe
    ldoms_path = f'{dest_infoprepos}/{cambio}/reporte_inicial/ldoms_{host}'
    if host_data.get('TIPO', '').lower() == 'fisico' and os.path.exists(ldoms_path):
        file_types.append('ldoms')

    file_contents = {}
    for file_type in file_types:
        file_path = f'{dest_infoprepos}/{cambio}/reporte_inicial/{file_type}_{host}'
        if os.path.exists(file_path):
            with open(file_path, 'r') as f:
                content = f.read()
                file_contents[file_type] = {
                    'content': base64.b64encode(content.encode()).decode()
                }

    tabs_html = "\n".join(
        f"<div class='file-tab' onclick=\"showFile('{host}', '{file_type}')\">{file_type.replace('_', ' ').title()}</div>"
        for file_type in file_types
    )

    content_html = "\n".join(
        generate_file_content(host, file_type, file_contents.get(file_type, {}))
        for file_type in file_types
    )

    return f"""
    <div id="{host}" class="config-container">
        <h2>{host}</h2>
        <div style="border: 1px solid var(--border-color); border-radius: 6px; padding: 10px; background-color: #f6f8fa; font-size: 14px; text-align: left;">
            <table style="border-collapse: collapse; width: 100%;">
                <tr>
                    <td style="font-weight: bold; padding: 4px;">OS:</td>
                    <td style="padding: 4px;">{host_data.get('SO', 'N/A')}</td>
                    <td style="font-weight: bold; padding: 4px;">CPU:</td>
                    <td style="padding: 4px;">{host_data.get('CPU', 'N/A')} vCPUs</td>
                    <td style="font-weight: bold; padding: 4px;">Tipo de Servidor:</td>
                    <td style="padding: 4px;">{'Virtual' if host_data.get('TIPO', '').lower() == 'virtual' else 'Físico'}</td>
                </tr>
                <tr>
                    <td style="font-weight: bold; padding: 4px;">Kernel:</td>
                    <td style="padding: 4px;">{host_data.get('KERNEL', 'N/A')}</td>
                    <td style="font-weight: bold; padding: 4px;">Memoria:</td>
                    <td style="padding: 4px;">{int(host_data.get('MEM', 0)) // 1024} GB</td>
                    <td style="font-weight: bold; padding: 4px;">Modelo Servidor:</td>
                    <td style="padding: 4px;">{host_data.get('MODEL', 'N/A')}</td>
                </tr>
                <tr>
                    <td style="font-weight: bold; padding: 4px;">IP:</td>
                    <td style="padding: 4px;">{host_data.get('IP', 'N/A')}</td>
                    <td style="font-weight: bold; padding: 4px;">Arquitectura:</td>
                    <td style="padding: 4px;">{host_data.get('ARCH', 'N/A')}</td>
                    <td style="font-weight: bold; padding: 4px;">Serial:</td>
                    <td style="padding: 4px;">{host_data.get('UUID', 'N/A')}</td>
                </tr>
                <tr>
                    <td style="font-weight: bold; padding: 4px;">Uptime:</td>
                    <td style="padding: 4px;" colspan="5">{host_data.get('UPTIME', 'N/A')}</td>
                </tr>
            </table>
        </div>
        <div class="file-tabs">{tabs_html}</div>
        {content_html}
    </div>
    """

def generate_file_content(host, file_type, file_data):
    if file_data and 'content' in file_data:
        content = base64.b64decode(file_data['content']).decode()
        lines = content.split('\n')
        lines_html = "".join(
            f'<div class="config-line"><span class="line-number">{i + 1}</span>{line}</div>'
            for i, line in enumerate(lines) if line.strip()
        )
        return f"""
        <div id="{host}_{file_type}" class="file-content">
            <div class="config-header">{file_type.replace("_", " ").title()}</div>
            {lines_html}
        </div>
        """
    else:
        return f"""
        <div id="{host}_{file_type}" class="file-content">
            <div class="error-message">No se encontraron datos</div>
        </div>
        """

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generar reporte HTML de configuraciones')
    parser.add_argument('--cambio', required=True, help='Nombre del cambio (ej: CXXXXX)')
    parser.add_argument('--titulo', required=True, help='Título del cambio')
    parser.add_argument('--usuario', required=True, help='Usuario que genera el reporte')
    parser.add_argument('--output', default='reporte_inicial.html', help='Archivo de salida HTML')
    parser.add_argument('--dest_infoprepos', default='/transfer', help='Ruta de Origen de los reportes')
    args = parser.parse_args()

    generate_html_report(
        cambio=args.cambio,
        titulo_cambio=args.titulo,
        tower_user_name=args.usuario,
        output_file=args.output,
        dest_infoprepos=args.dest_infoprepos
    )
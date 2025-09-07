#!/usr/bin/env python3
import os
import base64
import json
from datetime import datetime
import glob
import argparse

def generate_diff_html_report(cambio, titulo_cambio, tower_user_name, output_file, dest_infoprepos):
    # Obtener lista de hosts desde los archivos diff de filesystems
    diff_files = glob.glob(f'{dest_infoprepos}/{cambio}/diff/filesystems_*.diff')
    play_hosts = sorted(list({os.path.basename(f).split('_', 1)[1].replace('.diff', '') for f in diff_files}))

    # Tipos de archivos diff a incluir
    diff_types = [
        'filesystems', 'osversion', 'discos_fisicos', 'volumenes_logicos',
        'networks', 'rutas', 'recursos', 'puertos', 'nameservers', 'hba', 'multipath', 'asm','ldoms'
    ]

    
    

    # Obtener datos de los headers para cada host
    hostvars = {}
    for host in play_hosts:
        hostvars[host] = get_host_header_data(host, cambio, dest_infoprepos)

    # Obtener datos diff para cada host
    hostvars_diff = {}
    
    for host in play_hosts:
        hostvars_diff[host] = {}
        for diff_type in diff_types:
            diff_file = f'{dest_infoprepos}/{cambio}/diff/{diff_type}_{host}.diff'
            if os.path.exists(diff_file):
                with open(diff_file, 'r') as f:
                    content = f.read()
                    hostvars_diff[host][f'{diff_type}_diff'] = {
                        'content': base64.b64encode(content.encode()).decode()
                    }

    # Generar HTML
    html = generate_diff_html(play_hosts, hostvars, hostvars_diff, diff_types, titulo_cambio, tower_user_name)
    
    with open(output_file, 'w') as f:
        f.write(html)

    print(f"Reporte de diferencias generado exitosamente en {output_file}")

def generate_diff_html(play_hosts, hostvars, hostvars_diff, diff_types, titulo_cambio, tower_user_name):
    sidebar_items = []
    for host in play_hosts:
        has_changes = any(
            diff_type in hostvars_diff.get(host, {}) 
            and 'content' in hostvars_diff[host][diff_type]
            and base64.b64decode(hostvars_diff[host][diff_type]['content']).decode().strip()
            for diff_type in [f'{dt}_diff' for dt in diff_types]
        )
        
        dot_color = "#0366d6" if has_changes else "#6a737d"
        dot_char = "●" if has_changes else "○"
        
        sidebar_items.append(
            f"<div class='server-item' onclick=\"showServer('{host}')\">"
            f"{host}<span style='float: right; color: {dot_color};'>{dot_char}</span>"
            f"</div>"
        )

    content_sections = []
    for host in play_hosts:
        host_data = hostvars.get(host, {})
        host_diff_data = hostvars_diff.get(host, {})
        
        # Generar pestañas
        tabs_html = []
        for diff_type in diff_types:
            diff_key = f'{diff_type}_diff'
            has_content = diff_key in host_diff_data and 'content' in host_diff_data[diff_key]
            if has_content:
                diff_content = base64.b64decode(host_diff_data[diff_key]['content']).decode().strip()
                has_changes = bool(diff_content)
            else:
                has_changes = False
            
            # Determinar clase CSS y color según si hay cambios
            tab_class = "no-changes-tab" if not has_changes else "has-changes-tab"
            icon = "✓" if not has_changes else "✗"
            
            tabs_html.append(
                f"<div class='file-tab {tab_class}' onclick=\"showFile('{host}', '{diff_type}')\">"
                f"{icon} {diff_type.replace('_', ' ').title()}"
                f"</div>"
            )
        
        # Generar contenidos diff
        contents_html = []
        for diff_type in diff_types:
            diff_key = f'{diff_type}_diff'
            if diff_key in host_diff_data and 'content' in host_diff_data[diff_key]:
                diff_content = base64.b64decode(host_diff_data[diff_key]['content']).decode()
                lines_html = []
                
                for line in diff_content.split('\n'):
                    if line.startswith('+') and not line.startswith('+++'):
                        lines_html.append(f'<div class="diff-line diff-line-added">{line}</div>')
                    elif line.startswith('-') and not line.startswith('---'):
                        lines_html.append(f'<div class="diff-line diff-line-removed">{line}</div>')
                    elif line.startswith('@@'):
                        lines_html.append(f'<div class="diff-line diff-line-info">{line}</div>')
                    elif line.startswith('---') or line.startswith('+++'):
                        lines_html.append(f'<div class="diff-header">{line}</div>')
                    else:
                        lines_html.append(f'<div class="diff-line">{line}</div>')
                
                content_html = (
                    f'<div id="{host}_{diff_type}" class="file-content">\n'
                    f'{"".join(lines_html)}\n'
                    f'</div>'
                )
            else:
                content_html = (
                    f'<div id="{host}_{diff_type}" class="file-content">\n'
                    '<div class="no-changes">No se encontraron diferencias</div>\n'
                    '</div>'
                )
            
            contents_html.append(content_html)
        
        # Sección completa para el host
        host_section = f"""
        <div id="{host}" class="diff-container">
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
            
            <div class="file-tabs">
                {"".join(tabs_html)}
            </div>
            
            {"".join(contents_html)}
        </div>
        """
        content_sections.append(host_section)

    return f"""<!DOCTYPE html>
<html>
<head>
    <title>Reporte Consolidado de Diferencias</title>
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
            background-color: #f6f8fa;
            border-right: 1px solid var(--border-color);
            height: 100vh;
            overflow-y: auto;
            position: fixed;
        }}
        #content {{
            margin-left: var(--sidebar-width);
            padding: 20px;
            flex-grow: 1;
        }}
        .server-item {{
            padding: 10px 15px;
            border-bottom: 1px solid var(--border-color);
            cursor: pointer;
        }}
        .server-item:hover {{
            background-color: #e1e4e8;
        }}
        .server-item.active {{
            background-color: var(--primary-color);
            color: white;
        }}
        .diff-container {{
            display: none;
            margin-bottom: 30px;
            border: 1px solid var(--border-color);
            border-radius: 6px;
            overflow: hidden;
        }}
        .diff-container.active {{
            display: block;
        }}
        .diff-header {{
            background-color: #f6f8fa;
            padding: 8px 16px;
            border-bottom: 1px solid var(--border-color);
            font-family: SFMono-Regular, Consolas, "Liberation Mono", Menlo, monospace;
        }}
        .diff-line {{
            padding: 2px 16px;
            font-family: SFMono-Regular, Consolas, "Liberation Mono", Menlo, monospace;
            white-space: pre;
        }}
        .diff-line-added {{
            background-color: #e6ffed;
        }}
        .diff-line-removed {{
            background-color: #ffebe9;
        }}
        .diff-line-info {{
            background-color: #f1f8ff;
            color: #586069;
        }}
        .file-tabs {{
            display: flex;
            border-bottom: 1px solid var(--border-color);
            margin-bottom: 10px;
            flex-wrap: wrap;
        }}
        .file-tab {{
            padding: 5px 10px;
            margin-right: 5px;
            cursor: pointer;
            border: 1px solid transparent;
            border-radius: 4px 4px 0 0;
            margin-bottom: 5px;
            font-size: 14px;
        }}
        .file-tab:hover {{
            border-color: var(--border-color);
        }}
        .file-tab.active {{
            border-color: var(--border-color);
            border-bottom-color: white;
            margin-bottom: -1px;
            font-weight: bold;
        }}
        .file-tab.no-changes-tab {{
            background-color: #e6ffed;
            color: #22863a;
            border-left: 4px solid #28a745;
        }}
        .file-tab.has-changes-tab {{
            background-color: #ffebe9;
            color: #cb2431;
            border-left: 4px solid #d73a49;
        }}
        .file-tab.no-changes-tab:hover {{
            background-color: #dcffe4;
        }}
        .file-tab.has-changes-tab:hover {{
            background-color: #ffd7d5;
        }}
        .file-content {{
            display: none;
        }}
        .file-content.active {{
            display: block;
        }}
        h1 {{
            margin-top: 0;
        }}
        .timestamp {{
            color: #586069;
            margin-bottom: 20px;
        }}
        .no-changes {{
            background-color: #f0f0f0;
            padding: 15px;
            border-radius: 4px;
            text-align: center;
            margin: 20px 0;
            color: #586069;
        }}
        .error-message {{
            background-color: #ffebee;
            padding: 15px;
            border-radius: 4px;
            text-align: center;
            margin: 20px 0;
            color: #c62828;
        }}
    </style>
</head>
<body>
    <div id="sidebar">
        <h3 style="padding: 15px; margin: 0; border-bottom: 1px solid var(--border-color);">Servidores</h3>
        {"".join(sidebar_items)}
    </div>

    <div id="content">
        <h1>Reporte Consolidado de Diferencias</h1>
        <div class="timestamp">Generado el: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</div>
        <div class="timestamp">Generado por: {tower_user_name}</div>
        <div class="timestamp">Título del Cambio: {titulo_cambio}</div>
        
        {"".join(content_sections)}
    </div>

    <script>
        // Mostrar el primer servidor por defecto
        document.addEventListener('DOMContentLoaded', function() {{
            const firstServer = document.querySelector('.server-item');
            if (firstServer) {{
                const hostId = firstServer.textContent.trim().replace(/[●○]/g, '').trim();
                showServer(hostId);
                // Mostrar la primera pestaña del primer servidor
                showFile(hostId, '{diff_types[0]}');
            }}
        }});

        function showServer(host) {{
            // Actualizar menú lateral
            document.querySelectorAll('.server-item').forEach(item => {{
                item.classList.remove('active');
                if (item.textContent.includes(host)) {{
                    item.classList.add('active');
                }}
            }});
            
            // Mostrar contenido del servidor seleccionado
            document.querySelectorAll('.diff-container').forEach(container => {{
                container.classList.remove('active');
            }});
            document.getElementById(host).classList.add('active');
        }}

        function showFile(host, file) {{
            // Actualizar pestañas
            const tabs = document.querySelectorAll(`#${{host}} .file-tab`);
            tabs.forEach(tab => tab.classList.remove('active'));
            
            // Mostrar contenido del archivo seleccionado
            const contents = document.querySelectorAll(`#${{host}} .file-content`);
            contents.forEach(content => content.classList.remove('active'));
            
            document.querySelector(`#${{host}} .file-tab[onclick*="${{file}}"]`).classList.add('active');
            document.getElementById(`${{host}}_${{file}}`).classList.add('active');
        }}
    </script>
</body>
</html>"""

def get_host_header_data(host, cambio, dest_infoprepos):
    header_file = f'{dest_infoprepos}/{cambio}/diff/header_{host}'
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

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generar reporte HTML de diferencias')
    parser.add_argument('--cambio', required=True, help='Nombre del cambio (ej: CAMBIOTEST)')
    parser.add_argument('--titulo', required=True, help='Título del cambio')
    parser.add_argument('--usuario', required=True, help='Usuario que genera el reporte')
    parser.add_argument('--output', default='reporte_diferencias.html', help='Archivo de salida HTML')
    parser.add_argument('--dest_infoprepos', default='/opt/ansible/infoprepos', help='Ruta de destino de infoprepos')
    args = parser.parse_args()

    generate_diff_html_report(
        cambio=args.cambio,
        titulo_cambio=args.titulo,
        tower_user_name=args.usuario,
        output_file=args.output,
        dest_infoprepos=args.dest_infoprepos
    )
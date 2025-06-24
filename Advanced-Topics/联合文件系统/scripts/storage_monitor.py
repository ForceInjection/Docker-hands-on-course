#!/usr/bin/env python3
# 容器存储监控系统

import docker
import psutil
import time
import json
import subprocess
import os
from datetime import datetime
from flask import Flask, render_template, jsonify

app = Flask(__name__)
client = docker.from_env()

class StorageMonitor:
    def __init__(self):
        self.client = docker.from_env()
        
    def get_docker_info(self):
        """获取 Docker 存储信息"""
        info = self.client.info()
        return {
            'storage_driver': info.get('Driver'),
            'docker_root_dir': info.get('DockerRootDir'),
            'containers': info.get('Containers'),
            'images': info.get('Images')
        }
    
    def get_storage_usage(self):
        """获取存储使用情况"""
        try:
            # 使用 docker system df 获取存储使用
            result = subprocess.run(
                ['docker', 'system', 'df', '--format', 'json'],
                capture_output=True, text=True
            )
            if result.returncode == 0:
                return json.loads(result.stdout)
        except Exception as e:
            print(f"获取存储使用失败: {e}")
        return {}
    
    def get_overlay_stats(self):
        """获取 OverlayFS 统计信息"""
        stats = {
            'total_layers': 0,
            'total_size': 0,
            'layer_details': []
        }
        
        try:
            overlay_path = '/var/lib/docker/overlay2'
            if os.path.exists(overlay_path):
                for item in os.listdir(overlay_path):
                    layer_path = os.path.join(overlay_path, item)
                    if os.path.isdir(layer_path):
                        stats['total_layers'] += 1
                        size = self._get_dir_size(layer_path)
                        stats['total_size'] += size
                        stats['layer_details'].append({
                            'id': item[:12],
                            'size': size,
                            'path': layer_path
                        })
        except Exception as e:
            print(f"获取 OverlayFS 统计失败: {e}")
        
        return stats
    
    def _get_dir_size(self, path):
        """获取目录大小"""
        total = 0
        try:
            for dirpath, dirnames, filenames in os.walk(path):
                for filename in filenames:
                    filepath = os.path.join(dirpath, filename)
                    if os.path.exists(filepath):
                        total += os.path.getsize(filepath)
        except Exception:
            pass
        return total
    
    def get_container_storage(self):
        """获取容器存储信息"""
        containers = []
        for container in self.client.containers.list(all=True):
            try:
                inspect = container.attrs
                graph_driver = inspect.get('GraphDriver', {})
                
                container_info = {
                    'id': container.id[:12],
                    'name': container.name,
                    'status': container.status,
                    'image': container.image.tags[0] if container.image.tags else 'unknown',
                    'storage_driver': graph_driver.get('Name'),
                    'upper_dir': graph_driver.get('Data', {}).get('UpperDir'),
                    'merged_dir': graph_driver.get('Data', {}).get('MergedDir')
                }
                
                # 计算容器层大小
                if container_info['upper_dir']:
                    container_info['layer_size'] = self._get_dir_size(
                        container_info['upper_dir']
                    )
                
                containers.append(container_info)
            except Exception as e:
                print(f"获取容器 {container.name} 信息失败: {e}")
        
        return containers

monitor = StorageMonitor()

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/api/storage')
def api_storage():
    return jsonify({
        'timestamp': datetime.now().isoformat(),
        'docker_info': monitor.get_docker_info(),
        'storage_usage': monitor.get_storage_usage(),
        'overlay_stats': monitor.get_overlay_stats(),
        'containers': monitor.get_container_storage()
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
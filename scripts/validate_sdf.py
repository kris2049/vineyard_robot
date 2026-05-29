#!/usr/bin/env python3
"""Validate the vineyard_mower SDF model file."""
import xml.etree.ElementTree as ET

tree = ET.parse('/home/kris/vineyard_robot/simulation/models/vineyard_mower/model.sdf')
root = tree.getroot()
print('Root:', root.tag, 'version:', root.attrib.get('version'))
model = root[0]
print('Model:', model.tag, 'name:', model.attrib.get('name'))

links = model.findall('link')
joints = model.findall('joint')
plugins = model.findall('plugin')

print(f'\nLinks ({len(links)}):')
for l in links:
    inertial = l.find('inertial')
    mass = inertial.find('mass').text if inertial is not None else 'N/A'
    print(f'  {l.get("name"):20s} mass={mass}')

print(f'\nJoints ({len(joints)}):')
for j in joints:
    parent = j.find('parent').text
    child = j.find('child').text
    axis = j.find('axis/xyz').text
    print(f'  {j.get("name"):20s} {parent} -> {child:20s} axis={axis}')

print(f'\nPlugins ({len(plugins)}):')
for p in plugins:
    name = p.get('name', '')
    fn = p.get('filename', '')
    print(f'  {name}')
    print(f'    filename: {fn}')
    if 'DiffDrive' in name:
        left = [lj.text for lj in p.findall('left_joint')]
        right = [rj.text for rj in p.findall('right_joint')]
        sep = p.find('wheel_separation').text
        rad = p.find('wheel_radius').text
        print(f'    left_joints:  {left}')
        print(f'    right_joints: {right}')
        print(f'    wheel_separation: {sep}')
        print(f'    wheel_radius: {rad}')
    if 'JointState' in name:
        jn = [j.text for j in p.findall('joint_name')]
        print(f'    joints: {jn}')

print('\nXML valid: YES')

#!/usr/bin/env python3
import sys
import os
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

def update_appcast(appcast_path, version, short_version, dmg_url, release_notes):
    ET.register_namespace('sparkle', "http://www.andymatuschak.org/xml-namespaces/sparkle")
    
    try:
        tree = ET.parse(appcast_path)
        root = tree.getroot()
    except Exception as e:
        print(f"Error parsing appcast: {e}")
        sys.exit(1)

    channel = root.find('channel')
    if channel is None:
        print("Invalid appcast format: no channel element")
        sys.exit(1)

    # Create new item
    item = ET.Element('item')
    
    title = ET.SubElement(item, 'title')
    title.text = short_version
    
    pub_date = ET.SubElement(item, 'pubDate')
    pub_date.text = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
    
    # Sparkle namespaces
    version_elem = ET.SubElement(item, '{http://www.andymatuschak.org/xml-namespaces/sparkle}version')
    version_elem.text = version
    
    short_version_elem = ET.SubElement(item, '{http://www.andymatuschak.org/xml-namespaces/sparkle}shortVersionString')
    short_version_elem.text = short_version

    min_os = ET.SubElement(item, '{http://www.andymatuschak.org/xml-namespaces/sparkle}minimumSystemVersion')
    min_os.text = "14.0"

    desc = ET.SubElement(item, 'description')
    desc.text = f"<![CDATA[\n{release_notes}\n]]>"

    # Enclosure
    enclosure = ET.SubElement(item, 'enclosure')
    enclosure.set('url', dmg_url)
    enclosure.set('length', "0") # Sparkle will check header length, 0 is safer than guessing if not known
    enclosure.set('type', "application/octet-stream")
    
    # Check for existing version to avoid duplicates
    existing_item = None
    for child in channel:
        if child.tag == 'item':
            ver_elem = child.find('{http://www.andymatuschak.org/xml-namespaces/sparkle}version')
            if ver_elem is not None and ver_elem.text == version:
                existing_item = child
                break
    
    if existing_item is not None:
        print(f"Version {version} already exists. Removing old entry to update.")
        channel.remove(existing_item)

    # Insert at top (after existing items check, but usually first in channel)
    # channel has title, link, description, language... then items.
    # We want to insert before the first 'item'.
    
    first_item_index = -1
    for i, child in enumerate(channel):
        if child.tag == 'item':
            first_item_index = i
            break
            
    if first_item_index != -1:
        channel.insert(first_item_index, item)
    else:
        channel.append(item)

    # Indentation fix is tricky with ElementTree, usually we just save
    ET.indent(tree, space="    ", level=0)
    tree.write(appcast_path, encoding="utf-8", xml_declaration=True)
    print(f"Successfully added/updated version {short_version} in {appcast_path}")

if __name__ == "__main__":
    if len(sys.argv) < 6:
        print("Usage: update_remote_appcast.py <path_to_appcast> <internal_version> <short_version> <dmg_url> <release_notes_file>")
        sys.exit(1)

    appcast_path = sys.argv[1]
    version = sys.argv[2]
    short_version = sys.argv[3]
    dmg_url = sys.argv[4]
    
    release_notes_file = sys.argv[5]
    if os.path.exists(release_notes_file):
        with open(release_notes_file, 'r') as f:
            release_notes = f.read()
    else:
        release_notes = "<h3>Maintenance Update</h3><ul><li>Bug fixes and improvements.</li></ul>"

    update_appcast(appcast_path, version, short_version, dmg_url, release_notes)

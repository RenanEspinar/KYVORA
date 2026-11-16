#!/usr/bin/env python3
"""Generate only public mobile OAuth configuration, from CI variables.

FACEBOOK_APP_SECRET / SMTP secrets MUST NEVER be placed in mobile artifacts.
"""
from pathlib import Path
import os, json, xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
google=os.getenv('GOOGLE_WEB_CLIENT_ID','').strip()
facebook=os.getenv('FACEBOOK_APP_ID','').strip()
client_token=os.getenv('FACEBOOK_CLIENT_TOKEN','').strip()
if facebook and (not facebook.isdecimal() or not client_token):
    raise SystemExit('FACEBOOK_APP_ID must be numeric and paired with FACEBOOK_CLIENT_TOKEN')
resources=ET.Element('resources')
for key,value in (
    ('facebook_app_id', facebook or '0'),
    ('facebook_client_token',client_token or 'not_configured'),
    ('fb_login_protocol_scheme', 'fb'+(facebook or '0')),
):
    ET.SubElement(resources,'string',{'name':key}).text=value
file=ROOT/'mobile/android/app/src/main/res/values/strings.xml'
ET.indent(resources,space='    ')
ET.ElementTree(resources).write(file,encoding='utf-8',xml_declaration=True)
defines=ROOT/'mobile/client-auth-defines.json'
defines.write_text(json.dumps({'GOOGLE_WEB_CLIENT_ID':google,'FACEBOOK_APP_ID':facebook}),encoding='utf-8')
print('Public Android OAuth settings written (Google:',bool(google),'Facebook:',bool(facebook),')')
